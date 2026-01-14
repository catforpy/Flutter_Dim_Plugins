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

import 'package:object_key/object_key.dart'; // 通用数据结构（Pair/Triplet）
import 'package:dimsdk/dimsdk.dart'; // DIM核心协议库

import '../group.dart'; // 群组相关基础类

/// 退出群组命令处理器
/// 核心规则：
/// 1. 功能目标：将发送者从群成员列表中移除；
/// 2. 禁止规则：群主/管理员禁止退出群组（保证群组管理架构稳定）；
/// 3. 重复处理：若发送者已不是群成员，不执行任何操作；
/// 设计流程：校验命令有效性 → 校验群组信息 → 校验退出权限 → 执行退出逻辑/更新成员列表；
class QuitCommandProcessor extends GroupCommandProcessor {
  /// 构造方法（继承父类，传入核心依赖）
  QuitCommandProcessor(super.facebook, super.messenger);

  /// 处理退出群组命令的核心方法（覆盖父类抽象方法）
  @override
  Future<List<Content>> processContent(
    Content content,
    ReliableMessage rMsg,
  ) async {
    // 断言：确保传入的内容是QuitCommand类型
    assert(content is QuitCommand, 'quit command error: $content');
    GroupCommand command = content as GroupCommand;

    // ========== 步骤0：校验命令有效性 ==========
    // 检查命令是否过期（过期则返回预设回复）
    Pair<ID?, List<Content>?> pair = await checkCommandExpired(command, rMsg);
    ID? group = pair.first;
    if (group == null) {
      return pair.second ?? [];
    }

    // ========== 步骤1：校验群组信息 ==========
    // 检查群组是否存在，并获取群主ID和当前成员列表
    Triplet<ID?, List<ID>, List<Content>?> trip = await checkGroupMembers(
      command,
      rMsg,
    );
    ID? owner = trip.first;
    List<ID> members = trip.second;
    if (owner == null || members.isEmpty) {
      return trip.third ?? [];
    }
    String text; // 回复文本缓存

    // ========== 步骤2：权限校验 ==========
    ID sender = rMsg.sender; // 命令发送者（申请退出的用户）
    List<ID> admins = await getAdministrators(group); // 群管理员列表
    bool isOwner = owner == sender; // 发送者是否是群主
    bool isAdmin = admins.contains(sender); // 发送者是否是管理员
    bool isMember = members.contains(sender); // 发送者是否是群成员

    // 核心校验1：群主禁止退出（群主是群组的核心所有者）
    if (isOwner) {
      text = 'Permission denied.';
      return respondReceipt(
        text,
        content: command,
        envelope: rMsg.envelope,
        extra: {
          'template': 'Owner cannot quit from group: \${gid}',
          'replacements': {'gid': group.toString()},
        },
      );
    }
    // 核心校验2：管理员禁止退出（保证群组管理能力）
    if (isAdmin) {
      text = 'Permission denied.';
      return respondReceipt(
        text,
        content: command,
        envelope: rMsg.envelope,
        extra: {
          'template': 'Administrator cannot quit from group: \${gid}',
          'replacements': {'gid': group.toString()},
        },
      );
    }

    // ========== 步骤3：执行退出逻辑 ==========
    if (!isMember) {
      // 情况1：发送者已不是群成员 → 无需处理
    } else if (!await saveGroupHistory(group, command, rMsg)) {
      // 情况2：保存群历史失败 → 记录错误日志
      logError('failed to save "quit" command for group: $group');
    } else if (await saveMembers(group, [...members]..remove(sender))) {
      // 情况3：保存群历史成功 → 从成员列表中移除发送者
      command['removed'] = [sender.toString()]; // 标记移除的成员
    } else {
      // 情况4：更新成员列表失败 → 断言异常
      assert(false, 'failed to save members for group: $group');
    }

    // 无需回复该命令（退出结果通过群历史同步给其他成员）
    return [];
  }
}
