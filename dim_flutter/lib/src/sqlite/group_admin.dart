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

import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';

import 'entity.dart';


/// 从数据库结果集中提取管理员ID
/// [resultSet] 数据库查询结果集
/// [index] 行索引
/// 返回管理员ID
ID _extractAdmin(ResultSet resultSet, int index) {
  String? admin = resultSet.getString('admin');
  return ID.parse(admin)!;
}

/// 管理员数据表处理器：封装管理员表的增删改查操作
class _AdminTable extends DataTableHandler<ID> {
  /// 构造方法：初始化数据库连接器和结果集提取器
  _AdminTable() : super(GroupDatabase(), _extractAdmin);

  /// 管理员表名
  static const String _table = GroupDatabase.tAdmin;
  /// 查询列名列表
  static const List<String> _selectColumns = ["admin"];
  /// 插入列名列表
  static const List<String> _insertColumns = ["gid", "admin"];

  // 移除群组管理员
  // [admin] 管理员ID
  // [group] 群组ID
  // 返回操作是否成功
  Future<bool> removeAdmin(ID admin, {required ID group}) async {
    // 构建删除条件：群组ID + 管理员ID
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    cond.addCondition(SQLConditions.kAnd,
        left: 'admin', comparison: '=', right: admin.toString());
    // 执行删除操作
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove administrator: $admin, group: $group');
      return false;
    }
    return true;
  }

  // 添加群组管理员
  // [admin] 管理员ID
  // [group] 群组ID
  // 返回操作是否成功
  Future<bool> addAdmin(ID admin, {required ID group}) async {
    // 构建插入值列表
    List values = [
      group.toString(),
      admin.toString(),
    ];
    // 执行插入操作
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      logError('failed to add administrator: $admin, group: $group');
      return false;
    }
    return true;
  }

  // 加载指定群组的管理员列表
  // [group] 群组ID
  // 返回管理员列表
  Future<List<ID>> loadAdministrators(ID group) async {
    // 构建查询条件：群组ID匹配
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    // 执行查询操作（去重）
    return await select(_table, distinct: true, columns: _selectColumns, conditions: cond);
  }

}

/// 管理员数据访问任务：封装带缓存的管理员读写操作
class _AdminTask extends DbTask<ID, List<ID>> {
  /// 构造方法
  /// [mutexLock] 互斥锁
  /// [cachePool] 缓存池
  /// [_table] 管理员表处理器
  /// [_group] 群组ID
  /// [append] 要添加的管理员（可选）
  /// [remove] 要移除的管理员（可选）
  _AdminTask(super.mutexLock, super.cachePool, this._table, this._group, {
    required ID? append,
    required ID? remove,
  }) : _append = append, _remove = remove;

  /// 群组ID（缓存键）
  final ID _group;

  /// 要添加的管理员
  final ID? _append;
  /// 要移除的管理员
  final ID? _remove;

  /// 管理员表处理器
  final _AdminTable _table;

  /// 缓存键（群组ID）
  @override
  ID get cacheKey => _group;

  /// 从数据库读取管理员列表
  @override
  Future<List<ID>?> readData() async {
    return await _table.loadAdministrators(_group);
  }

  /// 写入管理员信息到数据库
  @override
  Future<bool> writeData(List<ID> admins) async {
    // 1. 添加管理员
    bool ok1 = false;
    ID? append = _append;
    if (append != null) {
      ok1 = await _table.addAdmin(append, group: _group);
      if (ok1) {
        admins.add(append);
      }
    }
    // 2. 移除管理员
    bool ok2 = false;
    ID? remove = _remove;
    if (remove != null) {
      ok2 = await _table.removeAdmin(remove, group: _group);
      if (ok2) {
        admins.remove(remove);
      }
    }
    // 只要有一个操作成功就返回true
    return ok1 || ok2;
  }

}

/// 管理员缓存管理器：提供管理员的缓存操作和通知分发
class AdminCache extends DataCache<ID, List<ID>> {
  /// 构造方法：初始化缓存池（名称为'group_admins'）
  AdminCache() : super('group_admins');

  /// 管理员表处理器实例
  final _AdminTable _table = _AdminTable();

  /// 创建新的管理员数据访问任务
  /// [group] 群组ID
  /// [append] 要添加的管理员（可选）
  /// [remove] 要移除的管理员（可选）
  /// 返回管理员任务实例
  _AdminTask _newTask(ID group, {ID? append, ID? remove}) =>
      _AdminTask(mutexLock, cachePool, _table, group, append: append, remove: remove);

  /// 获取指定群组的管理员列表
  /// [group] 群组ID
  /// 返回管理员列表（空列表表示无管理员）
  Future<List<ID>> getAdministrators(ID group) async {
    var task = _newTask(group);
    var contacts = await task.load();
    return contacts ?? [];
  }

  /// 保存管理员列表（批量更新）
  /// [newAdmins] 新的管理员列表
  /// [group] 群组ID
  /// 返回操作是否成功
  Future<bool> saveAdministrators(List<ID> newAdmins, ID group) async {
    var task = _newTask(group);
    var allAdmins = await task.load();
    allAdmins ??= [];

    var oldAdmins = [...allAdmins];
    int count = 0;
    // 1. 移除不在新列表中的管理员
    for (ID item in oldAdmins) {
      if (newAdmins.contains(item)) {
        continue;
      }
      task = _newTask(group, remove: item);
      if (await task.save(allAdmins)) {
        ++count;
      } else {
        logError('failed to remove admin: $item, group: $group');
        return false;
      }
    }
    // 2. 添加新列表中的新管理员
    for (ID item in newAdmins) {
      if (oldAdmins.contains(item)) {
        continue;
      }
      task = _newTask(group, append: item);
      if (await task.save(allAdmins)) {
        ++count;
      } else {
        logError('failed to add admin: $item, group: $group');
        return false;
      }
    }

    if (count == 0) {
      logWarning('admins not changed: $group');
    } else {
      logInfo('updated $count admin(s) for group: $group');
    }

    // 发送管理员更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kAdministratorsUpdated, this, {
      'action': 'update',
      'ID': group,
      'group': group,
      'administrators': newAdmins,
    });
    return true;
  }

  /// 添加群组管理员
  /// [admin] 管理员ID
  /// [group] 群组ID
  /// 返回操作是否成功
  Future<bool> addAdministrator(ID admin, {required ID group}) async {
    var task = _newTask(group);
    var allAdmins = await task.load();
    if (allAdmins == null) {
      allAdmins = [];
    } else if (allAdmins.contains(admin)) {
      logWarning('admin exists: $admin, group: $group');
      return true;
    }
    task = _newTask(group, append: admin);
    var ok = await task.save(allAdmins);
    if (ok) {
      // 发送添加管理员通知
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kAdministratorsUpdated, this, {
        'action': 'add',
        'ID': group,
        'group': group,
        'administrator': admin,
        'administrators': allAdmins,
      });
    }
    return ok;
  }

  /// 移除群组管理员
  /// [admin] 管理员ID
  /// [group] 群组ID
  /// 返回操作是否成功
  Future<bool> removeAdministrator(ID admin, {required ID group}) async {
    var task = _newTask(group);
    var allAdmins = await task.load();
    if (allAdmins == null) {
      logError('failed to get admins');
      return false;
    } else if (allAdmins.contains(admin)) {
      // 找到管理员
    } else {
      logWarning('admin not exists: $admin, group: $group');
      return true;
    }
    task = _newTask(group, remove: admin);
    var ok = await task.save(allAdmins);
    if (ok) {
      // 发送移除管理员通知
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kAdministratorsUpdated, this, {
        'action': 'remove',
        'ID': group,
        'group': group,
        'administrator': admin,
        'administrators': allAdmins,
      });
    }
    return ok;
  }

}