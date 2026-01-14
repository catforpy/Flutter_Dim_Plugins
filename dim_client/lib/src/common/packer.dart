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

import 'package:lnc/log.dart';
import 'package:dimsdk/dimsdk.dart';

/// 通用消息打包器抽象类
/// 继承MessagePacker，负责消息的加密、验证、签名等打包流程，
/// 处理发送方/接收方密钥检查、消息挂起等逻辑
abstract class CommonPacker extends MessagePacker with Logging {
  /// 构造方法
  /// [facebook] Facebook实例
  /// [messenger] 信使实例
  CommonPacker(super.facebook, super.messenger);

  /// 将入站消息加入队列，等待发送方的Visa文档
  /// [rMsg] 入站可靠消息
  /// [info] 错误信息
  // 受保护方法（需子类实现）
  void suspendReliableMessage(ReliableMessage rMsg, Map info);

  /// 将出站消息加入队列，等待接收方的Visa文档
  /// [iMsg] 出站即时消息
  /// [info] 错误信息
  // 受保护方法（需子类实现）
  void suspendInstantMessage(InstantMessage iMsg, Map info);

  //
  //  检查逻辑
  //

  /// 获取用户的Visa公钥（用于加密/验证）
  // 受保护方法
  Future<EncryptKey?> getVisaKey(ID user) async =>
      await facebook?.getPublicKeyForEncryption(user);

  /// 验证收到的消息前检查发送方
  /// [rMsg] 网络可靠消息
  /// 返回：false=验证密钥未找到，true=发送方验证通过
  // 受保护方法
  Future<bool> checkSender(ReliableMessage rMsg) async {
    ID sender = rMsg.sender;
    assert(sender.isUser, 'sender error: $sender'); // 断言：发送方必须是用户类型
    // 检查发送方的Meta和文档
    Visa? visa = MessageUtils.getVisa(rMsg);
    if (visa != null) {
      // 首次握手场景：检查Visa与发送方ID是否匹配
      bool matched = visa.identifier == sender;
      // 注释：原Meta匹配断言被注释，保留原始代码
      //assert Meta.matches(sender, rMsg.getMeta()) : "meta error: " + rMsg;
      assert(matched, 'visa ID not match: $sender');
      return matched;
    } else if (await getVisaKey(sender) != null) {
      // 发送方Visa密钥存在，验证通过
      return true;
    }
    // 发送方未就绪，挂起消息等待文档
    Map<String, String> error = {
      'message': 'verify key not found',
      'user': sender.toString(),
    };
    suspendReliableMessage(rMsg, error);  // rMsg.put("error", error);
    return false;
  }

  /// 加密消息前检查接收方
  /// [iMsg] 明文即时消息
  /// 返回：false=加密密钥未找到，true=接收方验证通过
  // 受保护方法
  Future<bool> checkReceiver(InstantMessage iMsg) async {
    ID receiver = iMsg.receiver;
    if (receiver.isBroadcast) {
      // 广播消息无需检查
      return true;
    } else if (receiver.isGroup) {
      // 注意：服务器不会发送群组消息，因此无需检查群组信息；
      //      客户端发送群组消息需先发送给群组机器人，由机器人分发给成员
      return false;
    } else if (await getVisaKey(receiver) != null) {
      // 接收方Visa密钥存在，验证通过
      return true;
    }
    // 接收方未就绪，挂起消息等待文档
    Map<String, String> error = {
      'message': 'encrypt key not found',
      'user': receiver.toString(),
    };
    suspendInstantMessage(iMsg, error);  // iMsg.put("error", error);
    return false;
  }

  //
  //  打包逻辑
  //

  /// 加密即时消息（重写父类方法）
  /// [iMsg] 明文即时消息
  /// 返回：安全消息（失败返回null）
  @override
  Future<SecureMessage?> encryptMessage(InstantMessage iMsg) async {
    // 加密前确保Visa密钥存在

    //
    //  检查文件内容
    //  ~~~~~~~~~~~~~~~~~
    //  打包消息前必须先上传文件数据
    //
    Content content = iMsg.content;
    if (content is FileContent && content.data != null) {
      // 文件内容包含原始数据，未上传时抛出错误
      ID sender = iMsg.sender;
      ID receiver = iMsg.receiver;
      ID? group = iMsg.group;
      var error = 'You should upload file data before calling '
          'sendInstantMessage: $sender -> $receiver ($group)';
      logError(error);
      assert(false, error);
      return null;
    }

    // 中间节点只能获取消息签名，无法解密内容获取sn，通常无影响；
    // 但有时需要在回执中返回原始sn，因此建议在此暴露sn字段
    iMsg['sn'] = content.sn;

    // 1. 检查联系人信息
    // 2. 检查群组成员信息
    if (await checkReceiver(iMsg)) {
      // 接收方就绪，继续加密
    } else {
      logWarning('receiver not ready: ${iMsg.receiver}');
      return null;
    }
    // 调用父类方法完成加密
    return await super.encryptMessage(iMsg);
  }

  /// 验证可靠消息（重写父类方法）
  /// [rMsg] 可靠消息
  /// 返回：安全消息（失败返回null）
  @override
  Future<SecureMessage?> verifyMessage(ReliableMessage rMsg) async {
    // 1. 检查接收方/群组与本地用户的关系
    // 2. 检查发送方的Visa信息
    if (await checkSender(rMsg)) {
      // 发送方就绪，继续验证
    } else {
      logWarning('sender not ready: ${rMsg.sender}');
      return null;
    }
    // 调用父类方法完成验证
    return await super.verifyMessage(rMsg);
  }

  /// 签名安全消息（重写父类方法）
  /// [sMsg] 安全消息
  /// 返回：可靠消息（失败返回null）
  @override
  Future<ReliableMessage?> signMessage(SecureMessage sMsg) async {
    if (sMsg is ReliableMessage) {
      // 已签名的消息直接返回
      return sMsg;
    }
    // 调用父类方法完成签名
    return await super.signMessage(sMsg);
  }

  // 注释：原序列化方法被注释，保留原始代码
  // @override
  // Future<Uint8List?> serializeMessage(ReliableMessage rMsg) async {
  //   SymmetricKey? key = await messenger?.getDecryptKey(rMsg);
  //   assert(key != null, 'encrypt key should not empty here');
  //   String? digest = _getKeyDigest(key);
  //   if (digest != null) {
  //     bool reused = key!.getBool('reused') ?? false;
  //     if (reused) {
  //       // replace key/keys with key digest
  //       Map keys = {
  //         'digest': digest,
  //       };
  //       rMsg['keys'] = keys;
  //       rMsg.remove('key');
  //     } else {
  //       // reuse it next time
  //       key['reused'] = true;
  //     }
  //   }
  //   return await super.serializeMessage(rMsg);
  // }

}

// 注释：原密钥摘要方法被注释，保留原始代码
// String? _getKeyDigest(SymmetricKey? key) {
//   if (key == null) {
//     // key error
//     return null;
//   }
//   String? value = key.getString('digest');
//   if (value != null) {
//     return value;
//   }
//   Uint8List data = key.data;
//   if (data.length < 6) {
//     // plain key?
//     return null;
//   }
//   // get digest for the last 6 bytes of key.data
//   Uint8List part = data.sublist(data.length - 6);
//   Uint8List digest = SHA256.digest(part);
//   String base64 = Base64.encode(digest);
//   base64 = base64.trim();
//   int pos = base64.length - 8;
//   value = base64.substring(pos);
//   key['digest'] = value;
//   return value;
// }