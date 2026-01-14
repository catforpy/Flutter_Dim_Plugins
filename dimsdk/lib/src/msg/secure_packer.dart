/* license: https://mit-license.org
 *
 *  ObjectKey : Object & Key kits
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

import 'dart:typed_data';

import 'package:dimsdk/dimp.dart';
import 'package:dimsdk/msg.dart';

/// 安全消息打包器
/// 实现两大核心功能：
/// 1. 【安全消息→即时消息】的解密转换（接收方解密消息）；
/// 2. 【安全消息→可靠消息】的签名转换（发送方签名消息）；
/// 封装消息解密、签名的完整流程，依赖 SecureMessageDelegate 完成具体的
/// 解密、签名操作，解耦流程控制与算法实现。
class SecureMessagePacker {
  /// 构造方法：传入消息代理（弱引用避免内存泄漏）
  /// @param messenger - 安全消息代理（提供解密/签名核心实现）
  SecureMessagePacker(SecureMessageDelegate messenger)
      : _messenger = WeakReference(messenger);

  /// 弱引用持有消息代理
  /// 避免循环引用导致的内存泄漏
  final WeakReference<SecureMessageDelegate> _messenger;

  /// 获取消息代理实例
  /// @return 安全消息代理实例；代理被回收时返回null
  SecureMessageDelegate? get delegate => _messenger.target;

  /*
   *  解密安全消息为即时消息的流程
   *
   *    +----------+      +----------+
   *    | sender   |      | sender   |
   *    | receiver |      | receiver |
   *    | time     |  ->  | time     |
   *    |          |      |          |  1. 对称密钥 = decrypt(key, 接收方私钥)
   *    | data     |      | content  |  2. content = decrypt(data, 对称密钥)
   *    | key/keys |      +----------+
   *    +----------+
   */

  /// 解密消息：将加密data替换为明文content，生成即时消息
  /// 核心流程：
  /// 1. 解密对称密钥 → 还原 password；
  /// 2. 解密密文数据 → 反序列化还原 content；
  /// 3. 移除 key/keys/data，添加明文 content，组装为即时消息。
  /// @param sMsg     - 安全消息（加密，包含data、key/keys字段）
  /// @param receiver - 实际接收方（本地用户ID，需持有私钥）
  /// @return 即时消息对象（包含content字段）；解密失败抛出异常
  Future<InstantMessage?> decryptMessage(SecureMessage sMsg, ID receiver) async{
    assert(receiver.isUser, '接收方必须是用户: $receiver');
    // 获取消息代理（核心算法实现）
    SecureMessageDelegate? transceiver = delegate;
    if(transceiver == null){
      assert(false, '消息代理不能为空');
      return null;
    }

    // 1.获取加密后的对称密钥（从key/keys字段解码）
    Uint8List? encryptedKey = sMsg.encryptedKey;
    Uint8List? keyData;
    if(encryptedKey != null){
      assert(encryptedKey.isNotEmpty, '加密密钥不能为空: ${sMsg.sender} => $receiver');
      // 2. 用接收方私钥解密秘钥（进本地用户可解密）
      keyData = await transceiver.decryptKey(encryptedKey, receiver, sMsg);
      if (keyData == null) {
        // 解密失败：接收方签证更新/私钥错误/密钥不匹配
        throw Exception('密钥解密失败: ${encryptedKey.length}字节 ${sMsg.sender} => $receiver');
      }
      assert(keyData.isNotEmpty, '密钥数据不能为空: ${sMsg.sender} => $receiver');
    }

    // 3. 反序列化秘钥数据，还原对称密钥（支持复用缓存秘钥）
    SymmetricKey? password = await transceiver.deserializeKey(keyData, sMsg);
    if(password == null){
      // 密钥缺失：缓存未命中/密钥反序列化失败/复用密钥过期
      throw Exception('获取密钥失败: ${keyData?.length}字节 ${sMsg.sender} => $receiver');
    }

    // 4. 解码消息密文数据（从data字段Base64/UTF8还原）
    Uint8List ciphertext = sMsg.data;
    if (ciphertext.isEmpty) {
      assert(false, '消息密文解码失败: ${sMsg.sender} => $receiver');
      return null;
    }

    // 5. 用对称密钥解密密文（还原序列化后的内容数据）
    Uint8List? body = await transceiver.decryptContent(ciphertext, password, sMsg);
    if (body == null) {
      // 解密失败：密钥过期/密钥不匹配/密文被篡改
      throw Exception('内容解密失败，密钥: $password ${sMsg.sender} => $receiver');
    }
    assert(body.isNotEmpty, '内容数据不能为空: ${sMsg.sender} => $receiver');

    // 6.反序列化内容数据，还原消息内容（文本/图片/音视频）
    Content? content = await transceiver.deserializeContent(body, password, sMsg);
    if (content == null) {
      assert(false, '内容反序列化失败: ${body.length}字节 ${sMsg.sender} => $receiver');
      return null;
    }

    // TODO: 处理文件/图片/音视频附件（由上层应用实现）
    //  - 若包含CDN URL，保存密钥到content.key
    //  - 从CDN下载文件数据，用content.key解密

    // 替换消息字段：移除相关字段，添加明文content
    Map info = sMsg.copyMap();
    info.remove('key');
    info.remove('keys');
    info.remove('data');
    info['content'] = content.toMap();
    // 解析Map为即时消息对象并返回
    return InstantMessage.parse(info);
  }

  /*
   *  签名安全消息为可靠消息的流程
   *
   *    +----------+      +----------+
   *    | sender   |      | sender   |
   *    | receiver |      | receiver |
   *    | time     |  ->  | time     |
   *    |          |      |          |
   *    | data     |      | data     |
   *    | key/keys |      | key/keys |
   *    +----------+      | signature|  1. signature = sign(data, 发送方私钥)
   *                      +----------+
   */

  /// 签名消息：为消息密文添加签名，生成可靠消息
  /// 核心流程：
  /// 1. 解码消息密文 → 用发送方私钥签名；
  /// 2. Base64编码签名数据 → 添加 signature 字段；
  /// 3. 组装为可靠消息（包含signature字段）。
  /// @param sMsg - 安全消息（加密，包含data、key/keys字段）
  /// @return 可靠消息对象（包含signature字段）；签名失败触发断言
  Future<ReliableMessage> signMessage(SecureMessage sMsg) async{
    SecureMessageDelegate? transceiver = delegate;
    assert(transceiver != null, '消息代理不能为空');

    // 0. 解码消息密文数据（从data字段Base64/UTF8还原）
    Uint8List ciphertext = sMsg.data;
    assert(ciphertext.isNotEmpty, '消息密文解码失败: ${sMsg.sender} => ${sMsg.receiver}');

    // 1.用发送方私钥对密文加密（保证消息来源合法）
    Uint8List signature = await transceiver!.signData(ciphertext, sMsg);
    assert(signature.isNotEmpty, '消息签名失败: ${ciphertext.length}字节 ${sMsg.sender} => ${sMsg.receiver}');

    // 2. Base64编码签名数据（便于JSON传输）
    Object base64 = TransportableData.encode(signature);

    // 添加签名字段，生成可靠消息
    Map info = sMsg.copyMap();
    info['signature'] = base64;
    // 解析Map为可靠消息对象并返回（非空，解析失败触发断言）
    return ReliableMessage.parse(info)!;
  }
}