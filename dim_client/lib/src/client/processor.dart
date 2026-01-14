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

import '../common/messenger.dart';
import '../common/processor.dart';
import '../common/protocol/handshake.dart';

import 'cpu/creator.dart';

/// 客户端消息处理器
/// 核心功能：处理群组消息的时间同步，管理消息响应的发送逻辑
class ClientMessageProcessor extends CommonProcessor {
  /// 构造方法
  ClientMessageProcessor(super.facebook, super.messenger);

  /// 获取Messenger实例（强制类型转换）
  @override
  CommonMessenger? get messenger => super.messenger as CommonMessenger?;

  /// 创建内容处理器创建器（重载以使用客户端实现）
  @override
  ContentProcessorCreator createCreator(Facebook facebook, Messenger messenger) {
    return ClientContentProcessorCreator(facebook, messenger);
  }

  // 私有方法：检查群组时间戳（同步群组信息）
  Future<bool> checkGroupTimes(Content content,ReliableMessage rMsg) async {
    ID? group = content.group;
    if (group == null) {
      return false;
    }
    var checker = entityChecker;
    if (checker == null) {
      assert(false, 'should not happen');
      return false;
    }
    DateTime now = DateTime.now();
    bool docUpdated = false;
    bool memUpdated = false;
    // 检查群组文档时间
    DateTime? lastDocumentTime = rMsg.getDateTime('GDT');
    if (lastDocumentTime != null) {
      // 校准时间（避免未来时间）
      if (lastDocumentTime.isAfter(now)) {
        lastDocumentTime = now;
      }
      // 更新最后文档时间
      docUpdated = checker.setLastDocumentTime(lastDocumentTime, group);
    }
    // 检查群组历史时间
    DateTime? lastHistoryTime = rMsg.getDateTime('GHT');
    if (lastHistoryTime != null) {
      // 校准时间
      if (lastHistoryTime.isAfter(now)) {
        lastHistoryTime = now;
      }
      // 更新最后历史时间
      memUpdated = checker.setLastGroupHistoryTime(lastHistoryTime, group);
    }
    // 触发群组信息更新
    if (docUpdated) {
      logInfo('checking for new bulletin: $group');
      await facebook?.getDocuments(group);
    }
    if (memUpdated) {
      // 更新最后活跃成员
      checker.setLastActiveMember(rMsg.sender, group: group);
      logInfo('checking for group members: $group');
      await facebook?.getMembers(group);
    }
    return docUpdated || memUpdated;
  }

  /// 处理消息内容（重载以添加群组时间检查）
  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    // 调用父类处理
    List<Content> responses = await super.processContent(content, rMsg);

    // 检查群组时间戳，同步群组信息
    await checkGroupTimes(content, rMsg);

    if (responses.isEmpty) {
      // 无响应直接返回
      return responses;
    } else if (responses.first is HandshakeCommand) {
      // 握手命令优先返回
      return responses;
    }
    //
    //  处理普通响应
    //
    var facebook = this.facebook;
    var messenger = this.messenger;
    if (facebook == null || messenger == null) {
      assert(false, 'twins not ready: $facebook, $messenger');
      return [];
    }
    ID sender = rMsg.sender;
    ID receiver = rMsg.receiver;
    // 选择本地用户作为响应发送者
    ID? user = await facebook.selectLocalUser(receiver);
    if (user == null) {
      assert(false, "receiver error: $receiver");
      return responses;
    }
    // 过滤响应（不向机器人/节点发送回执/文本）
    bool fromBots = sender.type == EntityType.STATION || sender.type == EntityType.BOT;
    for (Content res in responses) {
      if (res is ReceiptCommand) {
        if (fromBots) {
          continue;
        }
      } else if (res is TextContent) {
        if (fromBots) {
          continue;
        }
      }
      // 发送普通响应
      await messenger.sendContent(res, sender: user, receiver: sender, priority: 1);
    }
    // 不直接向节点返回响应
    return [];
  }
}