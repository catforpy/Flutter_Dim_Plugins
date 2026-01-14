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

/// 从查询结果集中提取静音用户ID
/// [resultSet]: SQL查询结果集
/// [index]: 结果集索引（此处未使用，保留参数兼容父类）
/// 返回解析后的用户ID
ID _extractMuted(ResultSet resultSet, int index) {
  String? user = resultSet.getString('muted'); // 获取muted字段值
  return ID.parse(user)!; // 解析为ID对象（强制非空）
}

/// 静音列表数据表处理器
/// 负责静音列表的数据库CRUD操作，泛型为ID（静音用户的标识）
class _MutedTable extends DataTableHandler<ID> {
  /// 构造函数：初始化数据库连接器和数据提取方法
  _MutedTable() : super(EntityDatabase(), _extractMuted);

  /// 数据表名称
  static const String _table = EntityDatabase.tMuted;
  /// 查询字段：仅查询muted字段
  static const List<String> _selectColumns = ["muted"];
  /// 插入字段：用户ID(uid)和静音用户ID(muted)
  static const List<String> _insertColumns = ["uid", "muted"];

  /// 移除静音用户
  /// [contact]: 要取消静音的用户ID
  /// [user]: 操作所属的用户ID（必填）
  /// 返回操作是否成功
  Future<bool> removeMuted(ID contact, {required ID user}) async {
    // 构建删除条件：uid等于当前用户 且 muted等于目标用户
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    cond.addCondition(SQLConditions.kAnd,
        left: 'muted', comparison: '=', right: contact.toString());
    // 执行删除操作，返回值<0表示失败
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove muted: $contact, user: $user'); // 记录错误日志
      return false;
    }
    return true;
  }

  /// 添加静音用户
  /// [contact]: 要静音的用户ID
  /// [user]: 操作所属的用户ID（必填）
  /// 返回操作是否成功
  Future<bool> addMuted(ID contact, {required ID user}) async {
    // 准备插入数据：用户ID和静音用户ID
    List values = [
      user.toString(),
      contact.toString(),
    ];
    // 执行插入操作，返回值<=0表示失败
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      logError('failed to add muted: $contact, user: $user'); // 记录错误日志
      return false;
    }
    return true;
  }

  /// 加载指定用户的静音列表
  /// [user]: 要查询的用户ID
  /// 返回该用户的所有静音用户ID列表
  Future<List<ID>> loadMutedList(ID user) async {
    // 构建查询条件：uid等于当前用户
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    // 执行查询：去重，仅返回muted字段，按条件过滤
    return await select(_table, distinct: true, columns: _selectColumns, conditions: cond);
  }

}

/// 静音列表数据库操作任务
/// 封装静音列表的读写操作，支持缓存和并发控制
/// 泛型参数：缓存键类型ID，数据类型List<ID>
class _MutedTask extends DbTask<ID, List<ID>> {
  /// 构造函数
  /// [mutexLock]: 互斥锁（父类参数）
  /// [cachePool]: 缓存池（父类参数）
  /// [_table]: 静音列表数据表处理器
  /// [_user]: 操作所属用户ID
  /// [muted]: 要添加的静音用户（可选）
  /// [allowed]: 要取消静音的用户（可选）
  _MutedTask(super.mutexLock, super.cachePool, this._table, this._user, {
    required ID? muted,
    required ID? allowed,
  }) : _muted = muted, _allowed = allowed;

  /// 操作所属的用户ID
  final ID _user;

  /// 要添加的静音用户ID
  final ID? _muted;
  /// 要取消静音的用户ID
  final ID? _allowed;

  /// 静音列表数据表处理器实例
  final _MutedTable _table;

  /// 获取缓存键（当前用户ID）
  @override
  ID get cacheKey => _user;

  /// 从数据库读取静音列表数据
  @override
  Future<List<ID>?> readData() async {
    return await _table.loadMutedList(_user);
  }

  /// 向数据库写入静音列表数据
  /// [contacts]: 当前的静音列表数据
  /// 返回是否成功执行写入操作
  @override
  Future<bool> writeData(List<ID> contacts) async {
    // 1. 添加静音用户
    bool ok1 = false;
    ID? muted = _muted;
    if (muted != null) {
      ok1 = await _table.addMuted(muted, user: _user);
      if (ok1) {
        contacts.add(muted); // 同步更新内存中的列表
      }
    }
    // 2. 取消静音用户
    bool ok2 = false;
    ID? allowed = _allowed;
    if (allowed != null) {
      ok2 = await _table.removeMuted(allowed, user: _user);
      if (ok2) {
        contacts.remove(allowed); // 同步更新内存中的列表
      }
    }
    // 只要有一个操作成功就返回true
    return ok1 || ok2;
  }

}

/// 静音列表缓存管理器
/// 实现MutedDBI接口，提供静音列表的缓存和数据库操作封装
class MutedCache extends DataCache<ID, List<ID>> implements MutedDBI {
  /// 构造函数：初始化缓存名称
  MutedCache() : super('muted_list');

  /// 静音列表数据表处理器实例
  final _MutedTable _table = _MutedTable();

  /// 创建新的静音列表操作任务
  /// [user]: 操作所属用户ID
  /// [muted]: 要添加的静音用户（可选）
  /// [allowed]: 要取消静音的用户（可选）
  /// 返回新的任务实例
  _MutedTask _newTask(ID user, {ID? muted, ID? allowed}) =>
      _MutedTask(mutexLock, cachePool, _table, user, muted: muted, allowed: allowed);

  /// 获取指定用户的静音列表
  /// [user]: 要查询的用户ID（必填）
  /// 返回静音用户ID列表（空列表表示无静音用户）
  @override
  Future<List<ID>> getMuteList({required ID user}) async {
    var task = _newTask(user);
    var contacts = await task.load(); // 从缓存/数据库加载数据
    return contacts ?? []; // 空值处理为空列表
  }

  /// 保存静音列表（全量更新）
  /// [newContacts]: 新的静音列表
  /// [user]: 操作所属用户ID（必填）
  /// 返回是否保存成功
  @override
  Future<bool> saveMuteList(List<ID> newContacts, {required ID user}) async {
    var task = _newTask(user);
    var allContacts = await task.load(); // 加载当前静音列表
    allContacts ??= []; // 空值处理为空列表

    var oldContacts = [...allContacts]; // 复制旧列表用于对比
    int count = 0; // 记录更新的数量
    // 1. 移除不在新列表中的用户（取消静音）
    for (ID item in oldContacts) {
      if (newContacts.contains(item)) {
        continue; // 新列表包含则跳过
      }
      task = _newTask(user, allowed: item);
      if (await task.save(allContacts)) {
        ++count; // 更新成功则计数+1
      } else {
        logError('failed to remove muted: $item, user: $user');
        return false; // 有一个失败则整体失败
      }
    }
    // 2. 添加新列表中新增的用户（添加静音）
    for (ID item in newContacts) {
      if (oldContacts.contains(item)) {
        continue; // 旧列表已包含则跳过
      }
      task = _newTask(user, muted: item);
      if (await task.save(allContacts)) {
        ++count; // 更新成功则计数+1
      } else {
        logError('failed to add muted: $item, user: $user');
        return false; // 有一个失败则整体失败
      }
    }

    // 日志记录更新结果
    if (count == 0) {
      logWarning('muted-list not changed: $user');
    } else {
      logInfo('updated $count muted contact(s) for user: $user');
    }

    // 发送静音列表更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kMuteListUpdated, this, {
      'action': 'update',
      'user': user,
      'muted_list': newContacts,
    });
    return true;
  }

  /// 添加单个静音用户
  /// [contact]: 要静音的用户ID
  /// [user]: 操作所属用户ID（必填）
  /// 返回是否添加成功
  @override
  Future<bool> addMuted(ID contact, {required ID user}) async {
    var task = _newTask(user);
    var allContacts = await task.load(); // 加载当前静音列表
    if (allContacts == null) {
      logError('failed to get muted-list');
      return false; // 加载失败返回false
    } else if (allContacts.contains(contact)) {
      logWarning('muted contact exists: $contact');
      return true; // 已存在则直接返回成功
    }
    task = _newTask(user, muted: contact);
    var ok = await task.save(allContacts); // 执行添加操作
    if (ok) {
      // 发送添加静音用户通知
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kMuteListUpdated, this, {
        'action': 'add',
        'user': user,
        'muted': contact,
        'muted_list': allContacts,
      });
    }
    return ok;
  }

  /// 移除单个静音用户（取消静音）
  /// [contact]: 要取消静音的用户ID
  /// [user]: 操作所属用户ID（必填）
  /// 返回是否移除成功
  @override
  Future<bool> removeMuted(ID contact, {required ID user}) async {
    var task = _newTask(user);
    var allContacts = await task.load(); // 加载当前静音列表
    if (allContacts == null) {
      allContacts = []; // 加载失败则初始化为空列表
    } else if (allContacts.contains(contact)) {
      // 找到目标用户，继续执行
    } else {
      logWarning('muted contact not exists: $user');
      return true; // 不存在则直接返回成功
    }
    task = _newTask(user, allowed: contact);
    var ok = await task.save(allContacts); // 执行移除操作
    if (ok) {
      // 发送取消静音用户通知
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kMuteListUpdated, this, {
        'action': 'remove',
        'user': user,
        'unmuted': contact,
        'muted_list': allContacts,
      });
    }
    return ok;
  }

}