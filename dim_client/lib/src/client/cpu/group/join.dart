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

/// 加入群组命令处理器
/// 核心规则：
/// 1. 功能目标：处理陌生人发起的加入群组请求；
/// 2. 审核权限：仅群主/管理员可审核并批准加入请求；
/// 3. 重复处理：若发送者已是群成员，仅同步群历史，不执行其他操作；
/// 设计流程：校验命令有效性 → 校验群组信息 → 校验发送者身份 → 保存群历史/等待审核；
class JoinCommandProcessor extends GroupCommandProcessor {
  /// 构造方法（继承父类，传入核心依赖）
  JoinCommandProcessor(super.facebook, super.messenger);

  /// 处理加入群组命令的核心方法（覆盖父类抽象方法）
  @override
  Future<List<Content>> processContent(
    Content content,
    ReliableMessage rMsg,
  ) async {
    // 断言：确保传入的内容是JoinCommand类型，避免类型错误
    assert(content is JoinCommand, 'join command error: $content');
    GroupCommand command = content as GroupCommand;

    // ========== 步骤0：校验命令有效性 ==========
    // 检查命令是否过期（过期则直接返回预设回复）
    Pair<ID?, List<Content>?> pair = await checkCommandExpired(command, rMsg);
    ID? group = pair.first;
    if (group == null) {
      return pair.second ?? [];
    }

    // 获取当前登录用户（用于后续群历史发送）
    User? user = await facebook?.currentUser;
    ID? me = user?.identifier;
    if (me == null) {
      assert(false, 'failed to get current user');
      return [];
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

    // ========== 步骤2：校验成员身份 ==========
    ID sender = rMsg.sender; // 命令发送者（申请入群的用户）
    List<ID> admins = await getAdministrators(group); // 群管理员列表
    bool isOwner = owner == sender; // 发送者是否是群主
    bool isAdmin = admins.contains(sender); // 发送者是否是管理员
    bool isMember = members.contains(sender); // 发送者是否已是群成员
    bool canReset = isOwner || isAdmin; // 发送者是否有权限更新群成员

    if (isMember) {
      // 情况1：发送者已是群成员 → 同步群历史（仅当当前用户是群主且发送者无更新权限时）
      if (!canReset && owner == me) {
        bool ok = await sendGroupHistories(group: group, receiver: sender);
        assert(ok, 'failed to send history for group: $group => $sender');
      }
    } else if (!await saveGroupHistory(group, command, rMsg)) {
      // 情况2：保存群历史失败 → 记录错误日志（后续无法审核该请求）
      logError('failed to save "join" command for group: $group');
    } else {
      // 情况3：保存群历史成功 → 等待群主/管理员审核（无其他即时操作）
    }

    // 无需回复该命令（审核结果通过reset命令/单独通知反馈）
    return [];
  }
}
