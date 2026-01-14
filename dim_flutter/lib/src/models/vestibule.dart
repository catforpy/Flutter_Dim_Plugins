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

import 'package:dim_client/client.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

import '../common/constants.dart';
import '../client/messenger.dart';
import '../client/shared.dart';

/// 消息等待厅：暂存因接收方未就绪而无法处理的消息，就绪后恢复处理
/// 实现Observer接口，监听接收方就绪通知（公钥/群信息更新等）
class Vestibule implements Observer {
  factory Vestibule() => _instance;
  static final Vestibule _instance = Vestibule._internal();
  Vestibule._internal() {
    // 注册通知监听：元数据保存、文档更新、群成员更新
    var nc = NotificationCenter();
    nc.addObserver(this, NotificationNames.kMetaSaved);
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kMembersUpdated);
  }

  /// 待处理的入站消息（接收的消息）：会话ID -> 可靠消息列表
  final Map<ID,List<ReliableMessage>> _incomingMessages = {};
  /// 待发送的出站消息（要发送的消息）：会话ID -> 即时消息列表
  final Map<ID,List<InstantMessage>> _outgoingMessages = {};

  /// 清理过期消息（TODO：实现过期清理逻辑）
  void purge() {
    // TODO: remove expired messages in the maps
  }

  /// 接收通知的处理方法（Observer接口实现）
  /// 当接收方就绪时，恢复处理暂存的消息
  @override
  Future<void> onReceiveNotification(Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    assert(name == NotificationNames.kMembersUpdated
        || name == NotificationNames.kDocumentUpdated
        || name == NotificationNames.kMetaSaved, 'name error: $notification');
    assert(userInfo != null, 'user info error: $notification');
    GlobalVariable shared = GlobalVariable();
    ClientFacebook facebook = shared.facebook;

    // 解析会话ID
    ID? entity = ID.parse(userInfo?['ID']);
    if (entity == null) {
      assert(false, 'conversation ID not found');
      return;
    }else if (entity.isUser){
      // 检查用户是否就绪（是否有加密公钥）
      if(await facebook.getPublicKeyForEncryption(entity) == null){
        Log.error('user not ready yet: $entity');
        return;
      }
    }else{
      assert(entity.isGroup, 'conversation ID error: $entity');
      // 检查群是否就绪（公告、群主、成员是否齐全）
      Bulletin? bulletin = await facebook.getBulletin(entity);
      if(bulletin == null){
        Log.error('group not ready yet: $entity');
        return;
      }
      ID? owner = await facebook.getOwner(entity);
      if (owner == null) {
        Log.error('group not ready yet: $entity');
        return;
      }
      List<ID> members = await facebook.getMembers(entity);
      if (members.isEmpty) {
        Log.error('group not ready yet: $entity');
        return;
      }
      // TODO: 检查群成员的签证公钥
    }
    // 恢复处理该回话的暂存消息
    await resumeMessages(entity);
  }

  /// 恢复处理指定会话的暂存消息
  /// [entity] 会话ID
  /// 返回是否处理成功
  Future<bool> resumeMessages(ID entity) async {
    GlobalVariable shared = GlobalVariable();
    SharedMessenger? messenger = shared.messenger;
    if (messenger == null) {
      assert(false, 'messenger not create yet');
      return false;
    }
    // 1.处理出站消息（待发送的消息）
    List<InstantMessage>? outgoing = _outgoingMessages.remove(entity);
    if (outgoing != null) {
      for(InstantMessage item in outgoing){
        await shared.emitter.sendInstantMessage(item, priority: 1);
        // 以下为注释的群/单聊区分发送逻辑
        // receiver = item.receiver;
        // if (receiver.isGroup) {
        //   // send by group manager
        //   await manager.sendInstantMessage(item, priority: 1);
        // } else {
        //   // send by shared messenger
        //   await messenger.sendInstantMessage(item, priority: 1);
        // }
      }
    }
    // 2. 处理入站消息（待处理的接受消息）
    List<ReliableMessage>? incoming = _incomingMessages.remove(entity);
    if(incoming != null){
      List<ReliableMessage>? responses;
      for(ReliableMessage item in incoming){
        // 处理可靠消息，获取相应
        responses = await messenger.processReliableMessage(item);
        if(responses.isEmpty){
          continue;
        }
        // 发送响应消息
        for(ReliableMessage res in responses){
          await messenger.sendReliableMessage(res,priority: 1);
        }
      }
    }
    return true;
  }

  /// 暂存无法处理的入站可靠消息
  /// [rMsg] 可靠消息
  void suspendReliableMessage(ReliableMessage rMsg) {
    // 解析等待的目标ID
    ID? waiting = ID.parse(rMsg['waiting']);
    if(waiting == null){
      waiting = ID.parse(rMsg['error']?['user']);
      waiting ??= rMsg.group;
      waiting ??= rMsg.sender;
    }else{
      rMsg.remove('waiting');
    }
    // 存入暂存列表
    List<ReliableMessage>? array = _incomingMessages[waiting];
    if(array == null){
      _incomingMessages[waiting] = [rMsg];
    }else{
      array.add(rMsg);
    }
  }

  /// 暂存无法发送的出站即时消息
  /// [iMsg] 即时消息
  void suspendInstantMessage(InstantMessage iMsg) {
    // 解析等待的目标ID
    ID? waiting = ID.parse(iMsg['waiting']);
    if (waiting == null) {
      waiting = ID.parse(iMsg['error']?['user']);
      waiting ??= iMsg.group;
      waiting ??= iMsg.receiver;
    } else {
      iMsg.remove('waiting');
    }
    // 存入暂存列表
    List<InstantMessage>? array = _outgoingMessages[waiting];
    if (array == null) {
      _outgoingMessages[waiting] = [iMsg];
    } else {
      array.add(iMsg);
    }
  }
}