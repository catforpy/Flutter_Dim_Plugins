/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2023 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2023 Albert Moky
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 * =============================================================================
 */

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';

import 'entity.dart';


/// 从结果集中提取联系人ID
/// [resultSet] 数据库查询结果集
/// [index] 行索引
/// 返回联系人ID
ID _extractContact(ResultSet resultSet, int index) {
  String? user = resultSet.getString('contact');
  return ID.parse(user)!;
}

/// 联系人数据表处理器：封装联系人表的增删改查操作
class _ContactTable extends DataTableHandler<ID> {
  /// 构造方法：初始化数据库连接器和结果集提取器
  _ContactTable() : super(EntityDatabase(), _extractContact);

  /// 联系人表名
  static const String _table = EntityDatabase.tContact;
  /// 查询列名列表
  static const List<String> _selectColumns = ["contact"];
  /// 插入列名列表
  static const List<String> _insertColumns = ["uid", "contact"];

  // 移除指定联系人
  // [contact] 联系人ID
  // [user] 所属用户ID
  // 返回操作是否成功
  Future<bool> removeContact(ID contact, {required ID user}) async {
    /// 构建删除条件：用户ID + 联系人ID
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'contact', comparison: '=', right: contact.toString());
    // 执行删除操作
    if(await delete(_table, conditions: cond) < 0){
      logError('failed to remove contact: $contact, user: $user');
      return false;
    }
    return true;
  }

  // 添加新联系人
  // [contact] 联系人ID
  // [user] 所属用户ID
  // 返回操作是否成功
  Future<bool> addContact(ID contact, {required ID user}) async {
    // 构建插入值列表
    List values = [
      user.toString(),
      contact.toString(),
    ];
    // 执行插入操作
    if(await insert(_table, columns: _insertColumns, values: values) <= 0){
      logError('failed to add contact: $contact, user: $user');
      return false;
    }
    return true;
  }

  // 加载指定用户的联系人列表
  // [user] 所属用户ID
  // 返回联系人列表
  Future<List<ID>> loadContacts({required ID user}) async {
    // 构建查询条件：用户ID
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    // 执行查询操作（去重）
    return await select(_table, distinct: true, columns: _selectColumns, conditions: cond);
  }
}

/// 联系人数据访问任务：封装带缓存的联系人读写操作
class _ContactTask extends DbTask<ID, List<ID>>{
  /// 构造方法
  /// [mutexLock] 互斥锁
  /// [cachePool] 缓存池
  /// [_table] 联系人表处理器
  /// [_user] 所属用户ID
  /// [append] 要添加的联系人（可选）
  /// [remove] 要移除的联系人（可选）
  _ContactTask(super.mutexLock, super.cachePool, this._table, this._user, {
    required ID? append,
    required ID? remove,
  }) : _append = append, _remove = remove;

  /// 所属用户ID
  final ID _user;

  /// 要添加的联系人
  final ID? _append;
  /// 要移除的联系人
  final ID? _remove;

  /// 联系人表处理器
  final _ContactTable _table;

  /// 缓存键（用户ID）
  @override
  ID get cacheKey => _user;

  /// 从数据库读取联系人列表
  @override
  Future<List<ID>?> readData() async {
    return await _table.loadContacts(user: _user);
  }

  /// 写入联系人信息到数据库
  @override
  Future<bool> writeData(List<ID> contacts) async {
    // 1. 添加联系人
    bool ok1 = false;
    ID? append = _append;
    if (append != null) {
      ok1 = await _table.addContact(append, user: _user);
      if (ok1) {
        contacts.add(append);
      }
    }
    // 2. 移除联系人
    bool ok2 = false;
    ID? remove = _remove;
    if (remove != null) {
      ok2 = await _table.removeContact(remove, user: _user);
      if (ok2) {
        contacts.remove(remove);
      }
    }
    // 只要有一个操作成功就返回true
    return ok1 || ok2;
  }
}

/// 联系人缓存管理器：实现ContactDBI接口，提供联系人的缓存操作
class ContactCache extends DataCache<ID, List<ID>> implements ContactDBI {
  /// 构造方法：初始化缓存池（名称为'user_contacts'）
  ContactCache() : super('user_contacts');

  /// 联系人表处理器实例
  final _ContactTable _table = _ContactTable();

  /// 创建新的联系人数据访问任务
  /// [user] 所属用户ID
  /// [append] 要添加的联系人（可选）
  /// [remove] 要移除的联系人（可选）
  /// 返回联系人任务实例
  _ContactTask _newTask(ID user, {ID? append, ID? remove}) =>
      _ContactTask(mutexLock, cachePool, _table, user, append: append, remove: remove);

  /// 获取指定用户的联系人列表
  /// [user] 所属用户ID
  /// 返回联系人列表（空列表表示无联系人）
  @override
  Future<List<ID>> getContacts({required ID user}) async {
    var task = _newTask(user);
    var contacts = await task.load();
    return contacts ?? [];
  }

  /// 保存联系人列表（批量更新）
  /// [newContacts] 新的联系人列表
  /// [user] 所属用户ID
  /// 返回操作是否成功
  @override
  Future<bool> saveContacts(List<ID> newContacts, {required ID user}) async {
    var task = _newTask(user);
    var allContacts = await task.load();
    allContacts ??= [];

    var oldContacts = [...allContacts];
    int count = 0;
    // 1. 移除不在新列表中的联系人
    for (ID item in oldContacts) {
      if (newContacts.contains(item)) {
        continue;
      }
      task = _newTask(user, remove: item);
      if (await task.save(allContacts)) {
        ++count;
      } else {
        logError('failed to remove contact: $item, user: $user');
        return false;
      }
    }
    // 2. 添加新列表中的新联系人
    for (ID item in newContacts) {
      if (oldContacts.contains(item)) {
        continue;
      }
      task = _newTask(user, append: item);
      if (await task.save(allContacts)) {
        ++count;
      } else {
        logError('failed to add contact: $item, user: $user');
        return false;
      }
    }

    if (count == 0) {
      logWarning('contacts not changed: $user');
    } else {
      logInfo('updated $count contact(s) for user: $user');
    }

    // 发送联系人更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kContactsUpdated, this, {
      'action': 'update',
      'user': user,
      'contacts': newContacts,
    });
    return true;
  }

  /// 添加新联系人
  /// [contact] 联系人ID
  /// [user] 所属用户ID
  /// 返回操作是否成功
  Future<bool> addContact(ID contact, {required ID user}) async {
    var task = _newTask(user);
    var allContacts = await task.load();
    if (allContacts == null) {
      allContacts = [];
    } else if (allContacts.contains(contact)) {
      logWarning('contact exists: $contact');
      return true;
    }
    task = _newTask(user, append: contact);
    var ok = await task.save(allContacts);
    if (ok) {
      // 发送添加联系人通知
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kContactsUpdated, this, {
        'action': 'add',
        'user': user,
        'contact': contact,
        'contacts': allContacts,
      });
    }
    return ok;
  }

  /// 移除联系人
  /// [contact] 联系人ID
  /// [user] 所属用户ID
  /// 返回操作是否成功
  Future<bool> removeContact(ID contact, {required ID user}) async {
    var task = _newTask(user);
    var allContacts = await task.load();
    if (allContacts == null) {
      logError('failed to get contacts');
      return false;
    } else if (allContacts.contains(contact)) {
      // 找到联系人
    } else {
      logWarning('contact not exists: $user');
      return true;
    }
    task = _newTask(user, remove: contact);
    var ok = await task.save(allContacts);
    if (ok) {
      // 发送移除联系人通知
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kContactsUpdated, this, {
        'action': 'remove',
        'user': user,
        'contact': contact,
        'contacts': allContacts,
      });
    }
    return ok;
  }
}