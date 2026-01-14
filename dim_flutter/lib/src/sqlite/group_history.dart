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

import 'entity.dart';


/// 从数据库结果集中提取群组命令和消息对
/// [resultSet] 数据库查询结果集
/// [index] 行索引
/// 返回命令-消息对
Pair<GroupCommand, ReliableMessage> _extractCommandMessage(ResultSet resultSet, int index) {
  // 解析命令内容
  Map? content = JSONMap.decode(resultSet.getString('content')!);
  // 解析消息内容
  Map? message = JSONMap.decode(resultSet.getString('message')!);
  // 返回命令-消息对
  return Pair(Command.parse(content) as GroupCommand, ReliableMessage.parse(message)!);
}


/// 群组历史命令数据表处理器：实现GroupHistoryDBI接口，封装历史命令表的增删改查
class _GroupHistoryTable extends DataTableHandler<Pair<GroupCommand, ReliableMessage>> implements GroupHistoryDBI {
  /// 构造方法：初始化数据库连接器和结果集提取器
  _GroupHistoryTable() : super(GroupDatabase(), _extractCommandMessage);

  /// 历史命令表名
  static const String _table = GroupDatabase.tHistory;
  /// 查询列名列表
  static const List<String> _selectColumns = ["content", "message"];
  /// 插入列名列表
  static const List<String> _insertColumns = ["gid", "cmd", "time", "content", "message"];

  /// 保存群组历史命令
  /// [content] 群组命令
  /// [rMsg] 可靠消息
  /// [group] 群组ID
  /// 返回操作是否成功
  @override
  Future<bool> saveGroupHistory(GroupCommand content, ReliableMessage rMsg, {required ID group}) async {
    String cmd = content.cmd;                          // 命令名称
    DateTime? time = content.time;                     // 命令时间
    // 转换为秒级时间戳
    int seconds = time == null ? 0 : time.millisecondsSinceEpoch ~/ 1000;
    // 序列化为JSON字符串
    String command = JSON.encode(content.toMap());
    String message = JSON.encode(rMsg.toMap());
    // 构建插入值列表
    List values = [group.toString(), cmd, seconds, command, message];
    // 执行插入操作
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

  /// 获取指定群组的所有历史命令
  /// [group] 群组ID
  /// 返回命令-消息对列表
  @override
  Future<List<Pair<GroupCommand, ReliableMessage>>> getGroupHistories({required ID group}) async {
    // 构建查询条件：群组ID匹配
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    // 执行查询操作（去重）
    return await select(_table, distinct: true, columns: _selectColumns, conditions: cond);
  }

  /// 获取指定群组的重置命令
  /// [group] 群组ID
  /// 返回重置命令-消息对（null表示无）
  @override
  Future<Pair<ResetCommand?, ReliableMessage?>> getResetCommandMessage({required ID group}) async {
    // 构建查询条件：群组ID + 命令类型=reset
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'cmd', comparison: '=', right: 'reset');
    // 查询最新的一条重置命令
    List<Pair<GroupCommand, ReliableMessage>> array = await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'id DESC', limit: 1);
    // 处理查询结果
    if (array.isNotEmpty) {
      var pair = array.first;
      GroupCommand content = pair.first;
      ReliableMessage message = pair.second;
      if (content is ResetCommand) {
        return Pair(content, message);
      }
      assert(false, 'group command error: $group, $content');
    }
    // 返回空结果
    return const Pair(null, null);
  }

  /// 清理群组管理员相关历史命令（resign命令）
  /// [group] 群组ID
  /// 返回操作是否成功
  @override
  Future<bool> clearGroupAdminHistories({required ID group}) async {
    // 构建删除条件：群组ID + 命令类型=resign
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'cmd', comparison: '=', right: 'resign');
    // 执行删除操作
    return await delete(_table, conditions: cond) >= 0;
  }

  /// 清理群组成员相关历史命令（非resign命令）
  /// [group] 群组ID
  /// 返回操作是否成功
  @override
  Future<bool> clearGroupMemberHistories({required ID group}) async {
    // 构建删除条件：群组ID + 命令类型<>resign
    SQLConditions cond;
    cond = SQLConditions(left: 'gid', comparison: '=', right: group.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'cmd', comparison: '<>', right: 'resign');
    // 执行删除操作
    return await delete(_table, conditions: cond) >= 0;
  }

}

/// 群组历史命令缓存管理器：继承数据表处理器，增加内存缓存和通知机制
class GroupHistoryCache extends _GroupHistoryTable {
  /// 构造方法：初始化缓存池
  GroupHistoryCache() {
    _historyCache = CacheManager().getPool('group_history');  // 历史命令缓存
    _resetCache = CacheManager().getPool('group_reset');      // 重置命令缓存
  }

  /// 历史命令缓存池
  late final CachePool<ID, List<Pair<GroupCommand, ReliableMessage>>> _historyCache;
  /// 重置命令缓存池
  late final CachePool<ID, Pair<ResetCommand?, ReliableMessage?>> _resetCache;

  /// 保存群组历史命令（带缓存清理和通知）
  @override
  Future<bool> saveGroupHistory(GroupCommand content, ReliableMessage rMsg, {required ID group}) async {
    // 1. 保存到数据库
    if (await super.saveGroupHistory(content, rMsg, group: group)) {
      // 2. 清理缓存（强制重新加载）
      _historyCache.erase(group);
      _resetCache.erase(group);
    } else {
      Log.error('failed to save group command: $group');
      return false;
    }
    // 3. 发送历史命令更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kGroupHistoryUpdated, this, {
      'ID': group,
      'content': content,
      'message': rMsg,
    });
    return true;
  }

  /// 获取指定群组的所有历史命令（优先从缓存读取）
  @override
  Future<List<Pair<GroupCommand, ReliableMessage>>> getGroupHistories({required ID group}) async {
    CachePair<List<Pair<GroupCommand, ReliableMessage>>>? pair;
    CacheHolder<List<Pair<GroupCommand, ReliableMessage>>>? holder;
    List<Pair<GroupCommand, ReliableMessage>>? value;
    double now = TimeUtils.currentTimeSeconds;
    
    await lock();  // 加锁保证线程安全
    try {
      // 1. 检查内存缓存
      pair = _historyCache.fetch(group, now: now);
      holder = pair?.holder;
      value = pair?.value;
      
      if (value == null) {
        if (holder == null) {
          // 未加载过，等待加载
        } else if (holder.isAlive(now: now)) {
          // 缓存存在但无值，返回空列表
          return [];
        } else {
          // 缓存过期，更新有效期
          holder.renewal(128, now: now);
        }
        // 2. 从数据库加载
        value = await super.getGroupHistories(group: group);
        // 更新缓存（有效期1小时）
        _historyCache.updateValue(group, value, 3600, now: now);
      }
    } finally {
      unlock();  // 解锁
    }
    // 返回缓存值
    return value;
  }

  /// 获取指定群组的重置命令（优先从缓存读取）
  @override
  Future<Pair<ResetCommand?, ReliableMessage?>> getResetCommandMessage({required ID group}) async {
    CachePair<Pair<ResetCommand?, ReliableMessage?>>? pair;
    CacheHolder<Pair<ResetCommand?, ReliableMessage?>>? holder;
    Pair<ResetCommand?, ReliableMessage?>? value;
    double now = TimeUtils.currentTimeSeconds;
    
    await lock();  // 加锁保证线程安全
    try {
      // 1. 检查内存缓存
      pair = _resetCache.fetch(group, now: now);
      holder = pair?.holder;
      value = pair?.value;
      
      if (value == null) {
        if (holder == null) {
          // 未加载过，等待加载
        } else if (holder.isAlive(now: now)) {
          // 缓存存在但无值，返回空
          return const Pair(null, null);
        } else {
          // 缓存过期，更新有效期
          holder.renewal(128, now: now);
        }
        // 2. 从数据库加载
        value = await super.getResetCommandMessage(group: group);
        // 更新缓存（有效期1小时）
        _resetCache.updateValue(group, value, 3600, now: now);
      }
    } finally {
      unlock();  // 解锁
    }
    // 返回缓存值
    return value;
  }

  /// 清理群组管理员相关历史命令（带缓存清理和通知）
  @override
  Future<bool> clearGroupAdminHistories({required ID group}) async {
    if (await super.clearGroupAdminHistories(group: group)) {
      // 清理缓存
      _historyCache.erase(group);
    } else {
      Log.error('failed to remove history for group: $group');
      return false;
    }
    // 发送历史命令更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kGroupHistoryUpdated, this, {
      'ID': group,
    });
    return true;
  }

  /// 清理群组成员相关历史命令（带缓存清理和通知）
  @override
  Future<bool> clearGroupMemberHistories({required ID group}) async {
    if (await super.clearGroupMemberHistories(group: group)) {
      // 清理缓存
      _historyCache.erase(group);
      _resetCache.erase(group);
    } else {
      Log.error('failed to remove history for group: $group');
      return false;
    }
    // 发送历史命令更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kGroupHistoryUpdated, this, {
      'ID': group,
    });
    return true;
  }

}