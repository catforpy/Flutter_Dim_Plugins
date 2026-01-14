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

import 'dart:typed_data';

import 'package:dimsdk/dimsdk.dart';

import '../common/messenger.dart';
import '../common/packer.dart';
import '../common/protocol/handshake.dart';
import '../common/protocol/login.dart';
import '../common/protocol/report.dart';

import 'network/session.dart';
import 'checkpoint.dart';

/// 客户端消息器
/// 核心功能：处理握手、登录、消息去重、回执发送等客户端特有逻辑
class ClientMessenger extends CommonMessenger {
  /// 构造方法
  ClientMessenger(super.session, super.facebook, super.mdb);

  /// 获取客户端会话（强制类型转换）
  @override
  ClientSession get session => super.session as ClientSession;

  /// 反序列化消息（重载以添加去重检查）
  @override
  Future<ReliableMessage?> deserializeMessage(Uint8List data) async {
    var msg = await super.deserializeMessage(data);
    // 检查消息是否重复
    if (msg != null && checkMessageDuplicated(msg)) {
      msg = null;
    }
    return msg;
  }

  // 受保护方法：检查消息是否重复
  bool checkMessageDuplicated(ReliableMessage msg) {
    var cp = Checkpoint();
    bool duplicated = cp.duplicated(msg);
    if (duplicated) {
      String? sig = cp.getSig(msg);
      logWarning(
        'drop duplicated message ($sig): ${msg.sender} -> ${msg.receiver}',
      );
    }
    return duplicated;
  }

  /// 处理可靠消息（重载以添加回执发送）
  @override
  Future<List<ReliableMessage>> processReliableMessage(
    ReliableMessage rMsg,
  ) async {
    List<ReliableMessage> responses = await super.processReliableMessage(rMsg);
    // 如果没有响应且需要回执，构建并添加回执消息
    if (responses.isEmpty && await needsReceipt(rMsg)) {
      var res = await buildReceipt(rMsg.envelope);
      if (res != null) {
        responses.add(res);
      }
    }
    return responses;
  }

  // 受保护方法：构建回执消息
  Future<ReliableMessage?> buildReceipt(Envelope originalEnvelope) async {
    // 获取当前用户
    User? currentUser = await facebook.currentUser;
    if (currentUser == null) {
      assert(false, 'failed to get current user');
      return null;
    }
    ID me = currentUser.identifier;
    // 回执接受者为原消息发送者
    ID to = originalEnvelope.sender;
    String text = 'Message received.';
    // 创建回执命令
    var res = ReceiptCommand.create(text, originalEnvelope, null);
    // 创建消息信封
    var env = Envelope.create(sender: me, receiver: to);
    // 创建即时消息
    var iMsg = InstantMessage.create(env, res);
    // 加密消息
    var sMsg = await encryptMessage(iMsg);
    if (sMsg == null) {
      assert(
        false,
        'failed to encrypt message: $currentUser -> ${originalEnvelope.sender}',
      );
      return null;
    }
    // 签名消息
    var rMsg = await signMessage(sMsg);
    if (rMsg == null) {
      assert(
        false,
        'failed to sign message: $currentUser -> ${originalEnvelope.sender}',
      );
    }
    return rMsg;
  }

  // 受保护方法：判断是否需要发送回执
  Future<bool> needsReceipt(ReliableMessage rMsg) async {
    // 命令消息不发送回执（避免循环）
    if (rMsg.type == ContentType.COMMAND) {
      return false;
    }
    ID sender = rMsg.sender;
    // 非用户消息不发送回执（机器人/节点之间）
    if (sender.type != EntityType.USER) {
      return false;
    }
    // TODO:其他回执判断条件
    return true;
  }

  /// 发送即时消息（重载以添加登录状态检查）
  @override
  Future<ReliableMessage?> sendInstantMessage(
    InstantMessage iMsg, {
    int priority = 0,
  }) async {
    if (session.isReady) {
      // 会话就绪，可发送任何消息
    } else {
      // 未登录状态
      Content content = iMsg.content;
      if (content is! Command) {
        logWarning(
          'not handshake yet, suspend message: $content => ${iMsg.receiver}',
        );
        // 挂起非命令消息
        var clerk = packer;
        if (clerk is CommonPacker) {
          Map<String, Object> error = {
            'message': 'waiting to login',
            'user': iMsg.sender.toString(),
          };
          // 将出栈消息加入队列
          clerk.suspendInstantMessage(iMsg, error);
        }
        return null;
      } else if (content.cmd == HandshakeCommand.HANDSHAKE) {
        // 仅允许握手命令发送
        iMsg['pass'] = 'handshaking';
      } else {
        logWarning(
          'not handshake yet, drop command: $content => ${iMsg.receiver}',
        );
        return null;
      }
    }
    return await super.sendInstantMessage(iMsg, priority: priority);
  }

  /// 发送可靠消息（重载以添加登录状态检查）
  @override
  Future<bool> sendReliableMessage(
    ReliableMessage rMsg, {
    int priority = 0,
  }) async {
    var passport = rMsg.remove('pass');
    if (session.isReady) {
      // 会话就绪，可发送任意消息
      assert(passport == null, 'should not happen: $rMsg');
    } else {
      logError(
        'not handshake yet, suspend message: ${rMsg.sender} => ${rMsg.receiver}',
      );
      return false;
    }
    return await super.sendReliableMessage(rMsg, priority: priority);
  }

  /// 向当前节点发送握手命令
  /// [sessionKey]：响应的会话密钥（首次握手为null）
  Future<void> handshake(String? sessionKey) async {
    Station station = session.station;
    ID sid = station.identifier;
    if (sessionKey == null || sessionKey.isEmpty) {
      // 首次握手
      User? user = await facebook.currentUser;
      assert(user != null, 'current user not found');
      ID me = user!.identifier;
      // 创建西能
      Envelope env = Envelope.create(sender: me, receiver: sid);
      // 创建握手开始命令
      Content content = HandshakeCommand.start();
      // 广播模式
      content.group = Station.EVERY;
      // 首次接受前更新visa
      await updateVisa();
      // 获取当前用户的Meta和Visa
      Meta meta = await user.meta;
      Visa? visa = await user.visa;
      // 创建即时消息并附加Meta/Visa
      InstantMessage iMsg = InstantMessage.create(env, content);
      MessageUtils.setMeta(meta, iMsg);
      MessageUtils.setVisa(visa, iMsg);
      // 发送握手消息
      await sendInstantMessage(iMsg, priority: -1);
    } else {
      // 重新握手（携带会话秘钥）
      Content content = HandshakeCommand.restart(sessionKey);
      await sendContent(content, sender: null, receiver: sid, priority: -1);
    }
  }

  /// 更新Visa文档（TODO：实现具体逻辑）
  Future<bool> updateVisa() async {
    logInfo('TODO: update visa for first handshake');
    return true;
  }

  /// 握手成功回调
  Future<void> handshakeSuccess() async {
    // 标记会话已接受
    logInfo(
      'handshake success, change session accepted: ${session.isAccepted} => true',
    );
    session.accepted = true;
    // 广播当前文档
    await broadcastDocuments();
    // TODO: 后续可交由服务机器人处理
  }

  /// 向所有节点广播Meta和Visa文档
  /// [updated]：是否为更新后的文档（强制发送）
  Future<void> broadcastDocuments({bool updated = false}) async {
    User? user = await facebook.currentUser;
    assert(user != null, 'current user not found');
    Visa? visa = await user?.visa;
    if (visa == null) {
      assert(false, 'visa not found: $user');
      return;
    }
    ID me = visa.identifier;
    var checker = facebook.entityChecker;
    // 发送给所有联系人
    List<ID> contacts = await facebook.getContacts(me);
    for (ID item in contacts) {
      await checker?.sendVisa(visa, item, updated: updated);
    }
    // 广播到everyone@everywhere
    await checker?.sendVisa(visa, ID.EVERYONE, updated: updated);
  }

  /// 发送登录命令以保持漫游状态
  /// [sender]：发送者ID
  /// [userAgent]：用户代理信息
  Future<void> broadcastLogin(ID sender, String userAgent) async {
    Station station = session.station;
    // 创建登录命令
    LoginCommand content = LoginCommand.fromID(sender);
    content.agent = userAgent;
    content.station = station;
    // 广播到everyone@everywhere
    await sendContent(
      content,
      sender: sender,
      receiver: ID.EVERYONE,
      priority: 1,
    );
  }

  /// 发送在线状态报告
  /// [sender]：发送者ID
  Future<void> reportOnline(ID sender) async {
    Content content = ReportCommand.fromTitle(ReportCommand.ONLINE);
    await sendContent(
      content,
      sender: sender,
      receiver: Station.ANY,
      priority: 1,
    );
  }

  /// 发送离线状态报告
  /// [sender]：发送者ID
  Future<void> reportOffline(ID sender) async {
    Content content = ReportCommand.fromTitle(ReportCommand.OFFLINE);
    await sendContent(
      content,
      sender: sender,
      receiver: Station.ANY,
      priority: 1,
    );
  }
}
