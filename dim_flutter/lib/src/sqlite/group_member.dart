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


/// 从数据库结果集中提取群组成员ID
/// [resultSet] 数据库查询结果集
/// [index] 行索引
/// 返回成员ID
ID _extractMember(ResultSet resultSet, int index) {
  String? member = resultSet.getString('member');
  return ID.parse(member)!;
}

/// 群组成员数据表处理器：封装成员表的增删改查操作
class _MemberTable extends DataTableHandler<ID> {
  /// 构造方法：初始化数据库连接器和结果集提取器
  _MemberTable() : super(GroupDatabase(), _extractMember);

  /// 成员表名
  static const String _table = GroupDatabase.tMember;
  /// 查询列名列表
  static const List<String> _selectColumns = ["member"];
  /// 插入列名列表
  static const List<String> _insertColumns = ["gid", "member"];

  // 移除群组成员
  // [member] 成员ID
  // [group] 群组ID
  // 返回操作是否成功
  Future<bool> removeMember(ID member, {required ID group}) async {
    // 构建删除条件：群组ID + 成员ID
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    cond.addCondition(SQLConditions.kAnd,
        left: 'member', comparison: '=', right: member.toString());
    // 执行删除操作
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove member: $member, group: $group');
      return false;
    }
    return true;
  }

  // 添加群组成员
  // [member] 成员ID
  // [group] 群组ID
  // 返回操作是否成功
  Future<bool> addMember(ID member, {required ID group}) async {
    // 构建插入值列表
    List values = [
      group.toString(),
      member.toString(),
    ];
    // 执行插入操作
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      logError('failed to add member: $member, group: $group');
      return false;
    }
    return true;
  }

  // 加载指定群组的成员列表
  // [group] 群组ID
  // 返回成员列表
  Future<List<ID>> loadMembers(ID group) async {
    // 构建查询条件：群组ID匹配
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    // 执行查询操作（去重）
    return await select(_table, distinct: true, columns: _selectColumns, conditions: cond);
  }

}

/// 成员数据访问任务：封装带缓存的成员读写操作
class _MemTask extends DbTask<ID, List<ID>> {
  /// 构造方法
  /// [mutexLock] 互斥锁
  /// [cachePool] 缓存池
  /// [_table] 成员表处理器
  /// [_group] 群组ID
  /// [append] 要添加的成员（可选）
  /// [remove] 要移除的成员（可选）
  _MemTask(super.mutexLock, super.cachePool, this._table, this._group, {
    required ID? append,
    required ID? remove,
  }) : _append = append, _remove = remove;

  /// 群组ID（缓存键）
  final ID _group;

  /// 要添加的成员
  final ID? _append;
  /// 要移除的成员
  final ID? _remove;

  /// 成员表处理器
  final _MemberTable _table;

  /// 缓存键（群组ID）
  @override
  ID get cacheKey => _group;

  /// 从数据库读取成员列表
  @override
  Future<List<ID>?> readData() async {
    return await _table.loadMembers(_group);
  }

  /// 写入成员信息到数据库
  @override
  Future<bool> writeData(List<ID> members) async {
    // 1. 添加成员
    bool ok1 = false;
    ID? append = _append;
    if (append != null) {
      ok1 = await _table.addMember(append, group: _group);
      if (ok1) {
        members.add(append);
      }
    }
    // 2. 移除成员
    bool ok2 = false;
    ID? remove = _remove;
    if (remove != null) {
      ok2 = await _table.removeMember(remove, group: _group);
      if (ok2) {
        members.remove(remove);
      }
    }
    // 只要有一个操作成功就返回true
    return ok1 || ok2;
  }

}

/// 成员缓存管理器：提供成员的缓存操作和通知分发
class MemberCache extends DataCache<ID, List<ID>> {
  /// 构造方法：初始化缓存池（名称为'group_members'）
  MemberCache() : super('group_members');

  /// 成员表处理器实例
  final _MemberTable _table = _MemberTable();

  /// 创建新的成员数据访问任务
  /// [group] 群组ID
  /// [append] 要添加的成员（可选）
  /// [remove] 要移除的成员（可选）
  /// 返回成员任务实例
  _MemTask _newTask(ID group, {ID? append, ID? remove}) =>
      _MemTask(mutexLock, cachePool, _table, group, append: append, remove: remove);

  /// 获取指定群组的成员列表
  /// [group] 群组ID
  /// 返回成员列表（空列表表示无成员）
  Future<List<ID>> getMembers(ID group) async {
    var task = _newTask(group);
    var contacts = await task.load();
    return contacts ?? [];
  }

  /// 保存成员列表（批量更新）
  /// [newMembers] 新的成员列表
  /// [group] 群组ID
  /// 返回操作是否成功
  Future<bool> saveMembers(List<ID> newMembers, ID group) async {
    var task = _newTask(group);
    var allMembers = await task.load();
    allMembers ??= [];

    var oldMembers = [...allMembers];
    int count = 0;
    // 1. 移除不在新列表中的成员
    for (ID item in oldMembers) {
      if (newMembers.contains(item)) {
        continue;
      }
      task = _newTask(group, remove: item);
      if (await task.save(allMembers)) {
        ++count;
      } else {
        logError('failed to remove member: $item, group: $group');
        return false;
      }
    }
    // 2. 添加新列表中的新成员
    for (ID item in newMembers) {
      if (oldMembers.contains(item)) {
        continue;
      }
      task = _newTask(group, append: item);
      if (await task.save(allMembers)) {
        ++count;
      } else {
        logError('failed to add member: $item, group: $group');
        return false;
      }
    }

    if (count == 0) {
      logWarning('members not changed: $group');
    } else {
      logInfo('updated $count member(s) for group: $group');
    }

    // 发送成员更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kMembersUpdated, this, {
      'action': 'update',
      'ID': group,
      'group': group,
      'members': newMembers,
    });
    return true;
  }

  /// 添加群组成员
  /// [member] 成员ID
  /// [group] 群组ID
  /// 返回操作是否成功
  Future<bool> addMember(ID member, {required ID group}) async {
    var task = _newTask(group);
    var allMembers = await task.load();
    if (allMembers == null) {
      allMembers = [];
    } else if (allMembers.contains(member)) {
      logWarning('member exists: $member, group: $group');
      return true;
    }
    task = _newTask(group, append: member);
    var ok = await task.save(allMembers);
    if (ok) {
      // 发送添加成员通知
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kContactsUpdated, this, {
        'action': 'add',
        'ID': group,
        'group': group,
        'member': member,
        'members': allMembers,
      });
    }
    return ok;
  }

  /// 移除群组成员
  /// [member] 成员ID
  /// [group] 群组ID
  /// 返回操作是否成功
  Future<bool> removeMember(ID member, {required ID group}) async {
    var task = _newTask(group);
    var allMembers = await task.load();
    if (allMembers == null) {
      logError('failed to get members');
      return false;
    } else if (allMembers.contains(member)) {
      // 找到成员
    } else {
      logWarning('member not exists: $member, group: $group');
      return true;
    }
    task = _newTask(group, remove: member);
    var ok = await task.save(allMembers);
    if (ok) {
      // 发送移除成员通知
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kContactsUpdated, this, {
        'action': 'remove',
        'ID': group,
        'group': group,
        'member': member,
        'members': allMembers,
      });
    }
    return ok;
  }

}