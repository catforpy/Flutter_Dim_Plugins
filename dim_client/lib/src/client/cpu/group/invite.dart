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

import 'package:object_key/object_key.dart'; // 通用数据结构（Pair/Triplet，用于返回多值结果）
import 'package:dimsdk/dimsdk.dart'; // DIM核心协议库（定义群组命令/消息模型）

import '../group.dart'; // 群组相关基础类（父类/工具方法）

/// 邀请入群命令处理器
/// 核心规则：
/// 1. 功能目标：向指定群组添加新成员；
/// 2. 发起权限：任何群成员均可发起邀请命令；
/// 3. 执行权限：群主/管理员可直接执行邀请，普通成员发起的邀请需审核；
/// 设计流程：校验命令有效性 → 校验群组信息 → 校验发起者权限 → 计算新增成员 → 执行邀请逻辑 → 同步群历史/成员列表；
class InviteCommandProcessor extends GroupCommandProcessor {
  /// 构造方法（继承父类，传入核心依赖）
  InviteCommandProcessor(super.facebook, super.messenger);

  /// 处理邀请入群命令的核心方法（覆盖父类抽象方法）
  @override
  Future<List<Content>> processContent(
    Content content,
    ReliableMessage rMsg,
  ) async {
    // 断言：开发阶段校验，确保传入的内容是InviteCommand类型
    assert(content is InviteCommand, 'invite command error: $content');
    // 类型转换：将通用Content转为具体的GroupCommand，获取群组命令专属字段
    GroupCommand command = content as GroupCommand;

    // ========== 步骤0：校验命令有效性 ==========
    // 检查命令是否过期（过期命令直接忽略，返回预设回复）
    Pair<ID?, List<Content>?> pair = await checkCommandExpired(command, rMsg);
    ID? group = pair.first;
    if (group == null) {
      // 命令已过期，返回预设的回复内容（无则返回空列表）
      return pair.second ?? [];
    }
    // 检查命令中的待邀请成员列表是否有效（空列表则命令无意义）
    Pair<List<ID>, List<Content>?> pair1 = await checkCommandMembers(
      command,
      rMsg,
    );
    List<ID> inviteList = pair1.first;
    if (inviteList.isEmpty) {
      // 成员列表为空，返回预设的回复内容
      return pair1.second ?? [];
    }

    // 获取当前登录用户（用于后续权限校验/群历史发送）
    User? user = await facebook?.currentUser;
    ID? me = user?.identifier;
    if (me == null) {
      assert(false, 'failed to get current user'); // 断言：当前用户必须存在
      return [];
    }

    // ========== 步骤1：校验群组信息 ==========
    // 检查群组是否存在，并获取群主ID和当前成员列表
    Triplet<ID?, List<ID>, List<Content>?> trip = await checkGroupMembers(
      command,
      rMsg,
    );
    ID? owner = trip.first; // 群主ID（群组创建者）
    List<ID> members = trip.second; // 当前群成员列表
    if (owner == null || members.isEmpty) {
      // 群组信息异常（不存在/无成员），返回预设回复
      return trip.third ?? [];
    }
    String text; // 回复文本缓存（用于权限拒绝等场景）

    // ========== 步骤2：权限校验 ==========
    ID sender = rMsg.sender; // 命令发送者ID（发起邀请的用户）
    List<ID> admins = await getAdministrators(group); // 获取群管理员列表
    bool isOwner = owner == sender; // 发送者是否是群主
    bool isAdmin = admins.contains(sender); // 发送者是否是管理员
    bool isMember = members.contains(sender); // 发送者是否是群成员
    bool canReset = isOwner || isAdmin; // 发送者是否有权限直接更新群成员

    // 核心校验：非群成员禁止发起邀请（基础权限控制）
    if (!isMember) {
      text = 'Permission denied.';
      // 返回权限拒绝的回执消息（包含模板化提示，便于前端展示）
      return respondReceipt(
        text,
        content: command,
        envelope: rMsg.envelope,
        extra: {
          'template': 'Not allowed to invite member into group: \${gid}',
          'replacements': {'gid': group.toString()},
        },
      );
    }

    // ========== 步骤3：执行邀请逻辑 ==========
    // 计算待添加的新成员（过滤掉已在群中的成员，避免重复添加）
    Pair<List<ID>, List<ID>> memPair = calculateInvited(
      members: members,
      inviteList: inviteList,
    );
    List<ID> newMembers = memPair.first; // 更新后的完整成员列表
    List<ID> addedList = memPair.second; // 本次实际新增的成员列表

    if (addedList.isEmpty) {
      // 情况1：无新增成员（待邀请的成员已全部在群中）
      if (!canReset && owner == me) {
        // 发送者无更新权限，且当前用户是群主 → 向发送者同步最新群历史
        bool ok = await sendGroupHistories(group: group, receiver: sender);
        assert(ok, 'failed to send history for group: $group => $sender');
      }
    } else if (!await saveGroupHistory(group, command, rMsg)) {
      // 情况2：保存群历史失败（命令过期/存储异常）→ 记录错误日志
      logError('failed to save "invite" command for group: $group');
    } else if (!canReset) {
      // 情况3：发送者无直接更新权限 → 仅保存命令到群历史，等待群主/管理员审核
    } else if (await saveMembers(group, newMembers)) {
      // 情况4：发送者有权限（群主/管理员）→ 直接更新群成员列表
      logWarning('invited by administrator: $sender, group: $group');
      command['added'] = ID.revert(addedList); // 标记本次新增的成员列表
    } else {
      // 情况5：更新成员列表失败（数据库异常）→ 断言提醒
      assert(false, 'failed to save members for group: $group');
    }

    // 无需回复该命令（审核/更新结果通过群历史同步或单独通知）
    return [];
  }

  /// 计算待邀请的新成员（核心工具方法，静态方法便于复用）
  /// [members] - 当前群成员列表（基准列表）
  /// [inviteList] - 待邀请的成员列表（待筛选列表）
  /// 返回值：Pair(更新后的完整成员列表, 本次实际新增的成员列表)
  // protected（Dart通过命名规范模拟protected访问修饰符）
  static Pair<List<ID>, List<ID>> calculateInvited({
    required List<ID> members,
    required List<ID> inviteList,
  }) {
    // 复制当前成员列表（避免修改原列表，保证数据不可变）
    List<ID> newMembers = [...members];
    List<ID> addedList = [];
    // 遍历待邀请列表，筛选出未在群中的成员
    for (ID item in inviteList) {
      if (newMembers.contains(item)) {
        continue;
      }
      newMembers.add(item); // 添加到新成员列表
      addedList.add(item); // 记录本次新增的成员
    }
    return Pair(newMembers, addedList);
  }
}
