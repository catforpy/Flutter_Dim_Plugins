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

import '../common/dbi/contact.dart';
import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';

import 'entity.dart';


/// 从结果集中提取黑名单用户ID
/// [resultSet] 数据库查询结果集
/// [index] 行索引
/// 返回黑名单用户ID
ID _extractBlocked(ResultSet resultSet, int index) {
  String? user = resultSet.getString('blocked');
  return ID.parse(user)!;
}

/// 黑名单数据表处理器：封装黑名单表的增删改查操作
class _BlockedTable extends DataTableHandler<ID> {
  /// 构造方法：初始化数据库连接器和结果集提取器
  _BlockedTable() : super(EntityDatabase(), _extractBlocked);

  /// 黑名单表名
  static const String _table = EntityDatabase.tBlocked;
  /// 查询列名列表
  static const List<String> _selectColumns = ["blocked"];
  /// 插入列名列表
  static const List<String> _insertColumns = ["uid", "blocked"];

  // 从黑名单中移除指定联系人
  // [contact] 联系人ID
  // [user] 所属用户ID
  // 返回操作是否成功
  Future<bool> removeBlocked(ID contact, {required ID user}) async{
    // 构建删除条件：用户ID + 被拉黑联系人ID
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    cond.addCondition(SQLConditions.kAnd, 
      left: 'blocked', comparison: '=', right: contact.toString());
    // 执行删除操作
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove blocked: $contact, user: $user');
      return false;
    }
    return true;
  }

  // 添加联系人到黑名单
  // [contact] 联系人ID
  // [user] 所属用户ID
  // 返回操作是否成功
  Future<bool> addBlocked(ID contact, {required ID user}) async {
    // 构建插入值列表
    List values = [
      user.toString(),
      contact.toString(),
    ];
    // 执行插入操作
    if(await insert(_table, columns: _insertColumns, values: values) <= 0){
      logError('failed to add blocked: $contact, user: $user');
      return false;
    }
    return true;
  }

  // 加载指定用户的黑名单列表
  // [user] 所属用户ID
  // 返回黑名单列表
  Future<List<ID>> loadBlockedList(ID user) async {
    // 构建查询条件：用户ID
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    // 执行查询操作（去重）
    return await select(_table, distinct: true, columns: _selectColumns, conditions: cond);
  }
}

/// 黑名单数据访问任务：封装带缓存的黑名单读写操作
class _BlockedTask extends DbTask<ID, List<ID>> {
  /// 构造方法
  /// [mutexLock] 互斥锁
  /// [cachePool] 缓存池
  /// [_table] 黑名单表处理器
  /// [_user] 所属用户ID
  /// [blocked] 要拉黑的联系人（可选）
  /// [allowed] 要解除拉黑的联系人（可选）
  _BlockedTask(super.mutexLock, super.cachePool, this._table, this._user, {
    required ID? blocked,
    required ID? allowed,
  }) : _blocked = blocked, _allowed = allowed;

  /// 所属用户ID
  final ID _user;

  /// 要拉黑的联系人
  final ID? _blocked;
  /// 要解除拉黑的联系人
  final ID? _allowed;

  /// 黑名单表处理器
  final _BlockedTable _table;

  /// 缓存键（用户ID）
  @override
  ID get cacheKey => _user;

  /// 从数据库读取黑名单列表
  @override
  Future<List<ID>?> readData() async {
    return await _table.loadBlockedList(_user);
  }

  /// 写入黑名单信息到数据库
  @override
  Future<bool> writeData(List<ID> contacts) async {
    // 1. 添加拉黑联系人
    bool ok1 = false;
    ID? blocked = _blocked;
    if (blocked != null) {
      ok1 = await _table.addBlocked(blocked, user: _user);
      if (ok1) {
        contacts.add(blocked);
      }
    }
    // 2. 移除解除拉黑的联系人
    bool ok2 = false;
    ID? allowed = _allowed;
    if (allowed != null) {
      ok2 = await _table.removeBlocked(allowed, user: _user);
      if (ok2) {
        contacts.remove(allowed);
      }
    }
    // 只要有一个操作成功就返回true
    return ok1 || ok2;
  }
}

/// 黑名单缓存管理器：实现BlockedDBI接口，提供黑名单的缓存操作
class BlockedCache extends DataCache<ID, List<ID>> implements BlockedDBI{
  /// 构造方法：初始化缓存池（名称为'blocked_list'）
  BlockedCache() : super('blocked_list');

  /// 黑名单表处理器实例
  final _BlockedTable _table = _BlockedTable();

  /// 创建新的黑名单数据访问任务
  /// [user] 所属用户ID
  /// [blocked] 要拉黑的联系人（可选）
  /// [allowed] 要解除拉黑的联系人（可选）
  /// 返回黑名单任务实例
  _BlockedTask _newTask(ID user, {ID? blocked, ID? allowed}) =>
      _BlockedTask(mutexLock, cachePool, _table, user, blocked: blocked, allowed: allowed);

  /// 获取指定用户的黑名单列表
  /// [user] 所属用户ID
  /// 返回黑名单列表（空列表表示无黑名单）
  @override
  Future<List<ID>> getBlockList({required ID user}) async{
    var task = _newTask(user);
    var contacts = await task.load();
    return contacts ?? [];
  }

  /// 保存黑名单列表（批量更新）
  /// [newContacts] 新的黑名单列表
  /// [user] 所属用户ID
  /// 返回操作是否成功
  @override
  Future<bool> saveBlockList(List<ID> newContacts, {required ID user}) async {
    var task = _newTask(user);
    var allContacts = await task.load();
    allContacts ??= [];

    var oldContacts = [...allContacts];
    int count = 0;
    // 1.移除不再新列表中的联系人（解除拉黑）
    for(ID item in oldContacts){
      if(newContacts.contains(item)){
        continue;
      }
      task = _newTask(user,allowed: item);
      if(await task.save(allContacts)){
        ++ count;
      }else {
        logError('failed to remove blocked: $item, user: $user');
        return false;
      }
    }
    // 2. 添加新列表中的新联系人（拉黑）
    for (ID item in newContacts) {
      if (oldContacts.contains(item)) {
        continue;
      }
      task = _newTask(user, blocked: item);
      if (await task.save(allContacts)) {
        ++count;
      } else {
        logError('failed to add blocked: $item, user: $user');
        return false;
      }
    }

    if (count == 0) {
      logWarning('blocked-list not changed: $user');
    } else {
      logInfo('updated $count blocked contact(s) for user: $user');
    }

    // 发送黑名单更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kBlockListUpdated, this, {
      'action': 'update',
      'user': user,
      'blocked_list': newContacts,
    });
    return true;
  }

  /// 添加联系人到黑名单
  /// [contact] 联系人ID
  /// [user] 所属用户ID
  /// 返回操作是否成功
  @override
  Future<bool> addBlocked(ID contact, {required ID user}) async {
    var task = _newTask(user);
    var allContacts = await task.load();
    if (allContacts == null) {
      allContacts = [];
    } else if (allContacts.contains(contact)) {
      logWarning('blocked contact exists: $contact');
      return true;
    }
    task = _newTask(user,blocked: contact);
    var ok = await task.save(allContacts);
    if (ok) {
      // 发送拉黑通知
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kBlockListUpdated, this, {
        'action': 'add',
        'user': user,
        'blocked': contact,
        'blocked_list': allContacts,
      });
    }
    return ok;
  }

  /// 从黑名单中移除联系人
  /// [contact] 联系人ID
  /// [user] 所属用户ID
  /// 返回操作是否成功
  @override
  Future<bool> removeBlocked(ID contact, {required ID user}) async {
    var task = _newTask(user);
    var allContacts = await task.load();
    if (allContacts == null) {
      logError('failed to get blocked-list');
      return false;
    } else if (allContacts.contains(contact)) {
      // 找到联系人
    } else {
      logWarning('blocked contact not exists: $user');
      return true;
    }
    task = _newTask(user,allowed: contact);
    var ok = await task.save(allContacts);
    if (ok) {
      // 发送解除拉黑通知
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kBlockListUpdated, this, {
        'action': 'remove',
        'user': user,
        'unblocked': contact,
        'blocked_list': allContacts,
      });
    }
    return ok;
  }
}