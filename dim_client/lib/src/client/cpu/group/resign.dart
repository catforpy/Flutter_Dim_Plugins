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

/// 管理员辞职命令处理器
/// 核心规则：
/// 1. 功能目标：将发送者从群管理员列表中移除（管理员主动放弃权限）；
/// 2. 禁止规则：群主禁止辞职（群主是固定角色，不可放弃）；
/// 3. 重复处理：若发送者已不是管理员，不执行任何操作；
/// 设计流程：校验命令有效性 → 校验群组信息 → 校验辞职权限 → 执行辞职逻辑/更新管理员列表；
class ResignCommandProcessor extends GroupCommandProcessor {
  /// 构造方法（继承父类，传入核心依赖）
  ResignCommandProcessor(super.facebook, super.messenger);

  /// 处理管理员辞职命令的核心方法（覆盖父类抽象方法）
  @override
  Future<List<Content>> processContent(
    Content content,
    ReliableMessage rMsg,
  ) async {
    // 断言：确保传入的内容是ResignCommand类型
    assert(content is ResignCommand, 'resign command error: $content');
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
    ID sender = rMsg.sender; // 命令发送者（申请辞职的管理员）
    List<ID> admins = await getAdministrators(group); // 群管理员列表
    bool isOwner = owner == sender; // 发送者是否是群主
    bool isAdmin = admins.contains(sender); // 发送者是否是管理员

    // 核心校验：群主禁止辞职（群主角色不可放弃）
    if (isOwner) {
      text = 'Permission denied.';
      return respondReceipt(
        text,
        content: command,
        envelope: rMsg.envelope,
        extra: {
          'template': 'Owner cannot resign from group: \${gid}',
          'replacements': {'gid': group.toString()},
        },
      );
    }

    // ========== 步骤3：执行辞职逻辑 ==========
    if (!isAdmin) {
      // 情况1：发送者已不是管理员 → 无需处理
    } else if (!await saveGroupHistory(group, command, rMsg)) {
      // 情况2：保存群历史失败 → 记录错误日志
      logError('failed to save "resign" command for group: $group');
    } else if (await saveAdministrators(group, [...admins]..remove(sender))) {
      // 情况3：保存群历史成功 → 从管理员列表中移除发送者
      command['removed'] = [sender.toString()]; // 标记移除的管理员
    } else {
      // 情况4：更新管理员列表失败 → 断言异常
      assert(false, 'failed to save administrators for group: $group');
    }

    // 无需回复该命令（辞职结果通过群历史同步）
    return [];
  }
}
