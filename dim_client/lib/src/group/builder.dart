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

import 'package:dimsdk/dimsdk.dart';
import 'package:object_key/object_key.dart';

import 'delegate.dart';
import 'helper.dart';

/// 群组历史记录构建器
/// 用于构建群组操作历史命令列表，包括文档命令、重置命令和其他群组命令
class GroupHistoryBuilder extends TripletsHelper {
  /// 构造方法
  /// [super.delegate] - 父类初始化，传入群组代理对象
  GroupHistoryBuilder(super.delegate);

  // 群组命令助手（懒加载）
  late final GroupCommandHelper helper = createHelper();

  /// 创建群组命令助手（可重写以自定义实现）
  GroupCommandHelper createHelper() => GroupCommandHelper(delegate);

  /// 构建群组历史命令列表：
  ///     0. 文档命令（document command）
  ///     1. 重置群组命令（reset group command）
  ///     2. 其他群组命令（invite/join/quit等）
  /// [group] - 群组ID
  /// @return 按顺序排列的可靠消息列表
  Future<List<ReliableMessage>> buildGroupHistories(ID group) async {
    List<ReliableMessage> messages = [];
    Document? doc;
    ResetCommand? reset;
    ReliableMessage? rMsg;
    //
    //  0. 构建"document"命令
    //
    Pair<Document?, ReliableMessage?> docPair = await buildDocumentCommand(
      group,
    );
    doc = docPair.first;
    rMsg = docPair.second;
    if (doc == null || rMsg == null) {
      logWarning('failed to build "document" command for group: $group');
      return messages;
    } else {
      messages.add(rMsg);
    }
    //
    //  1. 添加"reset"命令
    //
    Pair<ResetCommand?, ReliableMessage?> resPair = await helper
        .getResetCommandMessage(group);
    reset = resPair.first;
    rMsg = resPair.second;
    if (reset == null || rMsg == null) {
      logWarning('failed to get "reset" command for group: $group');
      return messages;
    } else {
      messages.add(rMsg);
    }
    //
    //  2. 添加其他群组命令
    //
    List<Pair<GroupCommand, ReliableMessage>> history = await helper
        .getGroupHistories(group);
    for (var item in history) {
      if (item.first is ResetCommand) {
        // 'reset'命令已添加到列表前端，跳过
        logInfo('skip "reset" command for group: $group');
        continue;
      } else if (item.first is ResignCommand) {
        // 'resign'命令：对比命令时间和文档时间，过期则跳过
        if (DocumentUtils.isBefore(doc.time, item.first.time)) {
          logWarning(
            'expired "${item.first.cmd}" command in group: $group, sender: ${item.second.sender}',
          );
          continue;
        }
      } else {
        // 其他命令（invite/join/quit）：对比命令时间和reset时间，过期则跳过
        if (DocumentUtils.isBefore(reset.time, item.first.time)) {
          logWarning(
            'expired "${item.first.cmd}" command in group: $group, sender: ${item.second.sender}',
          );
          continue;
        }
      }
      messages.add(item.second);
    }
    // 返回构建好的历史消息列表
    return messages;
  }

  /// 创建广播用的"document"命令
  /// [group] - 群组ID
  /// @return 包含文档和可靠消息的配对对象
  Future<Pair<Document?, ReliableMessage?>> buildDocumentCommand(
    ID group,
  ) async {
    // 获取当前用户和群组报告
    User? user = await facebook?.currentUser;
    Bulletin? doc = await delegate.getBulletin(group);
    if (user == null || doc == null) {
      assert(user != null, 'failed to get current user');
      logError('document not found for group: $group');
      return Pair(null, null);
    }
    ID me = user.identifier;
    // 获取群组元数据
    Meta? meta = await delegate.getMeta(group);
    // 创建文档相应命令
    Command command = DocumentCommand.response(group, meta, [doc]);
    // 打包为广播消息
    ReliableMessage? rMsg = await _packBroadcastMessage(me, command);
    return Pair(doc, rMsg);
  }

  /// 创建包含最新成员列表的广播用"reset"群组命令
  /// [group] - 群组ID
  /// [members] - 可选参数，指定成员列表（为空则从代理获取）
  /// @return 包含重置命令和可靠消息的配对对象
  Future<Pair<ResetCommand?, ReliableMessage?>> buildResetCommand(
    ID group, [
    List<ID>? members,
  ]) async {
    // 获取当前用户和群组所有者
    User? user = await facebook?.currentUser;
    ID? owner = await delegate.getOwner(group);
    if (user == null || owner == null) {
      assert(user != null, 'failed to get current user');
      logError('owner not found for group: $group');
      return Pair(null, null);
    }
    ID me = user.identifier;
    // 权限校验：群主或管理员才能创建reset命令
    if (owner != me) {
      List<ID> admins = await delegate.getAdministrators(group);
      if (!admins.contains(me)) {
        logWarning(
          'not permit to build "reset" command for group: $group, $me',
        );
        return Pair(null, null);
      }
    }
    // 检查成员列表
    members ??= await delegate.getMembers(group);
    if (members.isEmpty) {
      logError('failed to get members for group: $group');
      assert(false, 'group members not found: $group');
      return Pair(null, null);
    }

    // 创建reset命令并打包为广播消息
    ResetCommand command = GroupCommand.reset(group, members: members);
    ReliableMessage? rMsg = await _packBroadcastMessage(me, command);
    return Pair(command, rMsg);
  }

  /// 打包广播消息（内部方法）
  /// [sender] - 发送者ID
  /// [content] - 消息内容
  /// @return 打包后的可靠消息
  Future<ReliableMessage?> _packBroadcastMessage(
    ID sender,
    Content content,
  ) async {
    // 创建信封（接受者为所有人）
    Envelope envelope = Envelope.create(sender: sender, receiver: ID.ANYONE);
    // 创建即时消息
    InstantMessage iMsg = InstantMessage.create(envelope, content);
    // 加密消息
    SecureMessage? sMsg = await messenger?.encryptMessage(iMsg);
    if (sMsg == null) {
      assert(false, 'failed to encrypt message: $envelope');
      return null;
    }
    // 签名消息
    ReliableMessage? rMsg = await messenger?.signMessage(sMsg);
    assert(rMsg != null, 'failed to sign message: $envelope');
    return rMsg;
  }
}
