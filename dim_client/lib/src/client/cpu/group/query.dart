/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2025 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2025 Albert Moky
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

import 'package:object_key/object_key.dart';  // 通用数据结构（Pair/Triplet）
import 'package:dimsdk/dimsdk.dart';          // DIM核心协议库

import '../../../common/protocol/groups.dart';  // 群组协议扩展（QueryCommand专属字段）
import '../group.dart';  // 群组相关基础类

/// 查询群成员命令处理器
/// 核心规则：
/// 1. 功能目标：查询指定群组的成员列表；
/// 2. 查询权限：仅群成员/群助理（机器人）可发起查询；
/// 3. 增量同步：若发送者本地群历史未过期，仅返回提示，不重复发送；
/// 设计流程：校验命令有效性 → 校验群组信息 → 校验查询权限 → 检查历史更新时间 → 发送最新群历史；
class QueryCommandProcessor extends GroupCommandProcessor {
  /// 构造方法（继承父类，传入核心依赖）
  QueryCommandProcessor(super.facebook, super.messenger);

  /// 处理查询群成员命令的核心方法（覆盖父类抽象方法）
  @override
  Future<List<Content>> processContent(
    Content content,
    ReliableMessage rMsg,
  ) async { 
    // 断言：确保传入的内容是QueryCommand类型
    assert(content is QueryCommand, 'query command error: $content');
    QueryCommand command = content as QueryCommand;

    // ========== 步骤0：校验命令有效性 ==========
    // 检查命令是否过期（过期则返回预设回复）
    Pair<ID?, List<Content>?> pair = await checkCommandExpired(command, rMsg);
    ID? group = pair.first;
    if (group == null) {
      return pair.second ?? [];
    }

    // ========== 步骤1：校验群组信息 ==========
    // 检查群组是否存在，并获取群主ID和当前成员列表
    Triplet<ID?, List<ID>, List<Content>?> trip = await checkGroupMembers(command, rMsg);
    ID? owner = trip.first;
    List<ID> members = trip.second;
    if (owner == null || members.isEmpty) {
      return trip.third ?? [];
    }
    String text;  // 回复文本缓存

    // ========== 步骤2：权限校验 ==========
    ID sender = rMsg.sender;          // 命令发送者
    List<ID> bots = await getAssistants(group);  // 群助理列表（机器人账号）
    bool isMember = members.contains(sender);    // 发送者是否是群成员
    bool isBot = bots.contains(sender);          // 发送者是否是群助理
    bool canQuery = isMember || isBot;           // 发送者是否有查询权限

    // 核心校验：非群成员/群助理禁止查询群成员列表
    if (!canQuery) {
      text = 'Permission denied.';
      return respondReceipt(text, content: command, envelope: rMsg.envelope, extra: {
        'template': 'Not allowed to query members of group: \${gid}',
        'replacements': {
          'gid': group.toString(),
        }
      });
    }

    // ========== 步骤3：检查群历史更新时间 ==========
    DateTime? queryTime = command.lastTime;  // 发送者本地的群历史最后更新时间
    if (queryTime != null) {
      // 获取服务端/本地存储的群历史最后更新时间
      var checker = facebook?.entityChecker;
      DateTime? lastTime = await checker?.getLastGroupHistoryTime(group);
      if (lastTime == null) {
        assert(false, 'group history error: $group');  // 群历史必须存在
      } else if (!lastTime.isAfter(queryTime)) {
        // 群历史未更新（发送者本地已是最新）→ 返回提示
        text = 'Group history not updated.';
        return respondReceipt(text, content: command, envelope: rMsg.envelope, extra: {
          'template': 'Group history not updated: \${gid}, last time: \${time}',
          'replacements': {
            'gid': group.toString(),
            'time': lastTime.millisecondsSinceEpoch / 1000.0,
          }
        });
      }
    }

    // ========== 步骤4：发送最新群历史 ==========
    // 向发送者发送最新的群历史命令（包含完整成员列表）
    bool ok = await sendGroupHistories(group: group, receiver: sender);
    assert(ok, 'failed to send history for group: $group => $sender');

    // 无需回复该命令（群历史已单独发送，包含所需的成员列表）
    return [];
  }
}