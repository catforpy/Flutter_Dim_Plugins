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

import 'package:dimsdk/core.dart';
import 'package:dimsdk/dimp.dart';
import 'package:dimsdk/mkm.dart';
import 'package:dimsdk/msg.dart';

/// DIM 协议消息收发核心实现类
/// 核心作用：实现消息的序列化/反序列化、加密/解密、签名/验签等全链路逻辑，
/// 是 Packer 接口的底层支撑，整合了实体管理、消息压缩、加密算法等组件，
/// 完成消息从明文到网络传输格式的全转换。
/// 核心设计：实现多个委托接口，将消息各阶段逻辑拆分到不同方法，保证代码可维护性。
abstract class Transceiver implements InstantMessageDelegate, SecureMessageDelegate, ReliableMessageDelegate{
  
  /// 实体管理委托（核心依赖）
  /// 提供 User/Group 实例的获取、公钥/私钥的查询，是加解密/签名验签的基础。
  EntityDelegate get facebook;

  /// 消息压缩工具（核心依赖）
  /// 提供消息/秘钥的序列化/反序列化、字段压缩/还原，是网络传输的基础
  Compressor get compressor;

  /// 序列化可靠消息为字节数组
  /// 核心逻辑：将可靠消息转为 Map，通过 Compressor 压缩序列化，得到网络传输的字节数组。
  /// @param rMsg - 可靠消息（ReliableMessage）
  /// @return 压缩后的字节数组；序列化失败返回 null
  Future<Uint8List?> serializeMessage(ReliableMessage rMsg) async{
    Map info = rMsg.toMap();
    return compressor.compressReliableMessage(info);
  }

  /// 反序列化字节数组为可靠消息
  /// 核心逻辑：通过 Compressor 解压缩反序列化，得到 Map 后解析为可靠消息。
  /// @param data - 网络接收的字节数组
  /// @return 可靠消息实例；反序列化失败返回 null
  Future<ReliableMessage?> deserializeMessage(Uint8List data) async {
    Object? info = compressor.extractReliableMessage(data);
    return ReliableMessage.parse(info);
  }

  // ======================== InstantMessageDelegate 实现（明文→加密） ========================

  @override
  Future<Uint8List> serializeContent(Content content, SymmetricKey password, InstantMessage iMsg) async {
    // 注意：文件/图片/音视频消息需先处理附件，该逻辑由子类实现
    // NOTICE: check attachment for File/Image/Audio/Video message content
    //         before serialize content, this job should be do in subclass
    return compressor.compressContent(content.toMap(), password.toMap());
  }

  @override
  Future<Uint8List> encryptContent(Uint8List data, SymmetricKey password, InstantMessage iMsg) async {
    // 将 AES 加密所需的 IV 存入消息，供解密时使用
    // store 'IV' in iMsg for AES decryption
    return password.encrypt(data, iMsg.toMap());
  }

  @override
  Future<Uint8List?> serializeKey(SymmetricKey password, InstantMessage iMsg) async {
    // 广播消息无需加密，因此无对称密钥
    if (BaseMessage.isBroadcast(iMsg)) {
      return null;
    }
    return compressor.compressSymmetricKey(password.toMap());
  }

  @override
  Future<Uint8List?> encryptKey(Uint8List key, ID receiver, InstantMessage iMsg) async {
    // 断言校验：非广播消息、接收者为用户类型
    assert(!BaseMessage.isBroadcast(iMsg), 'broadcast message has no key: $iMsg');
    assert(receiver.isUser, 'receiver error: $receiver');
    // 获取接收者实例（用于获取公钥）
    User? contact = await facebook.getUser(receiver);
    if (contact == null) {
      assert(false, 'failed to encrypt message key for contact: $receiver');
      return null;
    }
    // 用接收者公钥加密对称密钥（仅接收者能解密）
    return await contact.encrypt(key);
  }

  // ======================== SecureMessageDelegate 实现（加密→明文） ========================

  @override
  Future<Uint8List?> decryptKey(Uint8List key, ID receiver, SecureMessage sMsg) async {
    // 断言校验：非广播消息、接收者为用户类型（群组消息需传群成员 ID）
    assert(!BaseMessage.isBroadcast(sMsg), 'broadcast message has no key: $sMsg');
    assert(receiver.isUser, 'receiver error: $receiver');
    // 获取本地用户实例（用于获取私钥）
    User? user = await facebook.getUser(receiver);
    if (user == null) {
      assert(false, 'failed to decrypt key: ${sMsg.sender} => $receiver, ${sMsg.group}');
      return null;
    }
    // 用本地用户私钥解密对称密钥
    return await user.decrypt(key);
  }

  @override
  Future<SymmetricKey?> deserializeKey(Uint8List? key, SecureMessage sMsg) async {
    // 断言校验：非广播消息
    assert(!BaseMessage.isBroadcast(sMsg), 'broadcast message has no key: $sMsg');
    if (key == null) {
      // 密钥为空时，从缓存获取（复用密钥场景）
      assert(false, 'reused key? get it from cache: '
          '${sMsg.sender} => ${sMsg.receiver}, ${sMsg.group}');
      return null;
    }
    // 反序列化并还原对称密钥
    Object? info = compressor.extractSymmetricKey(key);
    return SymmetricKey.parse(info);
  }

  @override
  Future<Uint8List?> decryptContent(Uint8List data, SymmetricKey password, SecureMessage sMsg) async {
    // 从消息中读取 AES 解密所需的 IV
    // check 'IV' in sMsg for AES decryption
    return password.decrypt(data, sMsg.toMap());
  }

  @override
  Future<Content?> deserializeContent(Uint8List data, SymmetricKey password, SecureMessage sMsg) async {
    // 反序列化并还原消息内容
    Object? info = compressor.extractContent(data, password.toMap());
    return Content.parse(info);
    // 注意：文件/图片/音视频消息需后续处理附件，该逻辑由子类实现
    // NOTICE: check attachment for File/Image/Audio/Video message content
    //         after deserialize content, this job should be do in subclass
  }

  @override
  Future<Uint8List> signData(Uint8List data, SecureMessage sMsg) async {
    // 获取发送者实例（用于获取私钥）
    User? user = await facebook.getUser(sMsg.sender);
    assert(user != null, 'failed to sign message data for user: ${sMsg.sender}');
    // 用发送者私钥签名消息内容
    return await user!.sign(data);
  }

  // ======================== ReliableMessageDelegate 实现（验签） ========================

  @override
  Future<bool> verifyDataSignature(Uint8List data, Uint8List signature, ReliableMessage rMsg) async {
    // 获取发送者实例（用于获取公钥）
    User? contact = await facebook.getUser(rMsg.sender);
    if (contact == null) {
      assert(false, 'failed to verify message signature for contact: ${rMsg.sender}');
      return false;
    }
    // 用发送者公钥验证消息签名
    return await contact.verify(data, signature);
  }
}