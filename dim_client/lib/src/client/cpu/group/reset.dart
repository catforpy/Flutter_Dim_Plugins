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

/// 重置群成员命令处理器
/// 核心规则：
/// 1. 功能目标：重置群组的成员列表（替代废弃的'expel'命令，支持添加/移除成员）；
/// 2. 执行权限：仅群主/管理员可执行重置操作；
/// 3. 强制规则：群主必须是新成员列表的第一个元素（保证群主身份不可变）；
/// 4. 保护规则：禁止移除管理员（避免群组管理架构崩溃）；
/// 设计流程：校验命令有效性 → 校验群组信息 → 校验执行权限 → 计算成员变更 → 更新成员列表；
class ResetCommandProcessor extends GroupCommandProcessor {
  /// 构造方法（继承父类，传入核心依赖）
  ResetCommandProcessor(super.facebook, super.messenger);

  /// 处理重置群成员命令的核心方法（覆盖父类抽象方法）
  @override
  Future<List<Content>> processContent(
    Content content,
    ReliableMessage rMsg,
  ) async {
    // 断言：确保传入的内容是ResetCommand类型
    assert(content is ResetCommand, 'reset command error: $content');
    ResetCommand command = content as ResetCommand;

    // ========== 步骤0：校验命令有效性 ==========
    // 检查命令是否过期（过期则返回预设回复）
    Pair<ID?, List<Content>?> pair = await checkCommandExpired(command, rMsg);
    ID? group = pair.first;
    if (group == null) {
      return pair.second ?? [];
    }
    // 检查命令中的新成员列表是否有效（空列表则命令无意义）
    Pair<List<ID>, List<Content>?> pair1 = await checkCommandMembers(
      command,
      rMsg,
    );
    List<ID> newMembers = pair1.first;
    if (newMembers.isEmpty) {
      return pair1.second ?? [];
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
    ID sender = rMsg.sender; // 命令发送者
    List<ID> admins = await getAdministrators(group); // 群管理员列表
    bool isOwner = owner == sender; // 发送者是否是群主
    bool isAdmin = admins.contains(sender); // 发送者是否是管理员
    bool canReset = isOwner || isAdmin; // 发送者是否有权限重置

    // 核心校验1：非群主/管理员禁止重置成员列表
    if (!canReset) {
      text = 'Permission denied.';
      return respondReceipt(
        text,
        content: command,
        envelope: rMsg.envelope,
        extra: {
          'template': 'Not allowed to reset members of group: \${gid}',
          'replacements': {'gid': group.toString()},
        },
      );
    }

    // 核心校验2：群主必须是新成员列表的第一个元素（强制规则）
    if (newMembers.first != owner) {
      text = 'Permission denied.';
      return respondReceipt(
        text,
        content: command,
        envelope: rMsg.envelope,
        extra: {
          'template': 'Owner must be the first member of group: \${gid}',
          'replacements': {'gid': group.toString()},
        },
      );
    }

    // 核心校验3：禁止移除管理员（保护规则）
    bool expelAdmin = false;
    for (ID item in admins) {
      if (!newMembers.contains(item)) {
        expelAdmin = true;
        break;
      }
    }
    if (expelAdmin) {
      text = 'Permission denied.';
      return respondReceipt(
        text,
        content: command,
        envelope: rMsg.envelope,
        extra: {
          'template': 'Not allowed to expel administrator of group: \${gid}',
          'replacements': {'gid': group.toString()},
        },
      );
    }

    // ========== 步骤3：执行重置逻辑 ==========
    // 计算成员变更（新增/移除的成员列表）
    Pair<List<ID>, List<ID>> memPair = calculateReset(
      oldMembers: members,
      newMembers: newMembers,
    );
    List<ID> addList = memPair.first; // 新增成员列表
    List<ID> removeList = memPair.second; // 移除成员列表

    if (!await saveGroupHistory(group, command, rMsg)) {
      // 情况1：保存群历史失败 → 记录错误日志
      logError('failed to save "reset" command for group: $group');
    } else if (addList.isEmpty && removeList.isEmpty) {
      // 情况2：无成员变更 → 无需处理
    } else if (await saveMembers(group, newMembers)) {
      // 情况3：有成员变更且保存成功 → 标记新增/移除记录
      logInfo('new members saved in group: $group');
      if (addList.isNotEmpty) {
        command['added'] = ID.revert(addList);
      }
      if (removeList.isNotEmpty) {
        command['removed'] = ID.revert(removeList);
      }
    } else {
      // 情况4：更新成员列表失败 → 断言异常
      assert(false, 'failed to save members in group: $group');
    }

    // 无需回复该命令（重置结果通过群历史同步）
    return [];
  }

  /// 计算重置后的成员变更（核心工具方法，静态方法便于复用）
  /// [oldMembers] - 当前群成员列表（基准列表）
  /// [newMembers] - 新的群成员列表（目标列表）
  /// 返回值：Pair(新增成员列表, 移除成员列表)
  static Pair<List<ID>, List<ID>> calculateReset({
    required List<ID> oldMembers,
    required List<ID> newMembers,
  }) {
    List<ID> addList = [];
    List<ID> removeList = [];

    // 计算新增成员（新列表有，旧列表无）
    for (ID item in newMembers) {
      if (oldMembers.contains(item)) {
        continue;
      }
      addList.add(item);
    }

    // 计算移除成员（旧列表有，新列表无）
    for (ID item in oldMembers) {
      if (newMembers.contains(item)) {
        continue;
      }
      removeList.add(item);
    }

    return Pair(addList, removeList);
  }
}
