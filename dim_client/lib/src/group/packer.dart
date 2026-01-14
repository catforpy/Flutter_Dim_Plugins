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

import 'delegate.dart';

/// 群组消息打包器
/// 负责群组消息的打包、加密签名、拆分等操作
class GroupPacker extends TripletsHelper {
  /// 构造方法
  /// [super.delegate] - 父类初始化，传入群组代理对象
  GroupPacker(super.delegate);

  /// 打包为广播消息
  /// [content] - 消息内容
  /// [sender] - 发送者ID
  /// @return 打包后的可靠消息
  Future<ReliableMessage?> packMessage(
    Content content, {
    required ID sender,
  }) async {
    // 创建信封（接受者为所有人）
    Envelope? envelope = Envelope.create(sender: sender, receiver: ID.ANYONE);
    // 创建即时消息
    InstantMessage iMsg = InstantMessage.create(envelope, content);
    // 暴露群组ID
    iMsg.setString('group', content.group);
    // 加密签名
    return await encryptAndSignMessage(iMsg);
  }

  /// 加密并签名即时消息
  /// [iMsg] - 即时消息
  /// @return 签名后的可靠消息
  Future<ReliableMessage?> encryptAndSignMessage(InstantMessage iMsg) async {
    Messenger? transceiver = messenger;
    // 为接受者加密消息,将明文消息先加密，再签名
    SecureMessage? sMsg = await transceiver?.encryptMessage(iMsg);
    if (sMsg == null) {
      assert(
        false,
        'failed to encrypt message: ${iMsg.sender} => ${iMsg.receiver}, ${iMsg.group}',
      );
      return null;
    }
    // 为发送者签名消息
    ReliableMessage? rMsg = await transceiver?.signMessage(sMsg);
    if (rMsg == null) {
      assert(
        false,
        'failed to sign message: ${iMsg.sender} => ${iMsg.receiver}, ${iMsg.group}',
      );
      return null;
    }
    // 返回可靠消息
    return rMsg;
  }

  /// 拆分即时消息（为每个成员创建单独的消息）
  /// [iMsg] - 原始即时消息
  /// [allMembers] - 所有成员列表
  /// @return 拆分后的即时消息列表
  Future<List<InstantMessage>> splitInstantMessage(
    InstantMessage iMsg,
    List<ID> allMembers,
  ) async {
    List<InstantMessage> messages = [];
    ID sender = iMsg.sender;

    Map info;
    InstantMessage? item;
    for (ID receiver in allMembers) {
      if (sender == receiver) {
        logInfo('skip cycled message: $receiver, ${iMsg.group}');
        continue;
      }
      logInfo('split group message for member: $receiver');
      // 复制消息数据（浅拷贝）
      info = iMsg.copyMap(false);
      // 复制内容（避免多进程修改冲突，无需深拷贝）
      info['content'] = iMsg.content.copyMap(false);
      // 替换接受者为当前成员ID
      info['receiver'] = receiver.toString();
      // 解析为即时消息
      item = InstantMessage.parse(info);
      if (item == null) {
        assert(false, 'failed to repack message: $receiver');
        continue;
      }
      messages.add(item);
    }
    return messages;
  }

  /// 拆分可靠消息（为每个成员创建单独的消息）
  /// [rMsg] - 原始可靠消息
  /// [allMembers] - 所有成员列表
  /// @return 拆分后的可靠消息列表
  Future<List<ReliableMessage>> splitReliableMessage(
    ReliableMessage rMsg,
    List<ID> allMembers,
  ) async {
    List<ReliableMessage> messages = [];
    ID sender = rMsg.sender;

    // 断言：可靠消息不应包含key字段
    assert(!rMsg.containsKey('key'), 'should not happen');
    // 获取加密秘钥映射表
    Map? keys = rMsg.encryptedKeys;
    keys ??= {};

    Object? keyData;    // Base-64编码的秘钥数据
    Map info;
    ReliableMessage? item;
    for(ID receiver in allMembers){
      if (sender == receiver) {
        logInfo('skip cycled message: $receiver, ${rMsg.group}');
        continue;
      }
      logInfo('split group message for member: $receiver');
      // 复制消息数据
      info = rMsg.copyMap(false);
      // 替换接受者为当前成员ID
      info['receiver'] = receiver.toString();
      // 移除keys字段，添加当前成员的加密秘钥
      info.remove('keys');
      keyData = keys[receiver.toString()];
      if(keyData != null){
        info['key'] = keyData;
      }
      // 解析为可靠消息
      item = ReliableMessage.parse(info);
      if (item == null) {
        assert(false, 'failed to repack message: $receiver');
        continue;
      }
      messages.add(item);
    }
    return messages;
  }
}
