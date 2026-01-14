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

/// 信使核心接口（IM系统的核心引擎）
/// 核心定位：整合「消息打包（加解密/签名）」「消息处理（解析/分发）」「消息收发（网络传输）」三大核心能力，
/// 是DIM协议中消息全生命周期的统一入口，同时兼容分布式/中心化架构（仅需适配底层密钥管理和网络传输）。
/// 
/// 接口继承关系：
/// - Transceiver：提供消息发送（send）、接收（receive）的基础网络能力；
/// - Packer：提供消息加密、签名、序列化/反序列化的打包能力；
/// - Processor：提供消息解析、验签、解密、内容分发的处理能力。
abstract class Messenger extends Transceiver implements Packer, Processor{
  // 受保护方法：获取加密密钥代理（密钥管理核心）
  // 作用：封装密钥的查询、生成、缓存逻辑，是适配中心化/分布式架构的关键（分布式从本地取，中心化从服务端取）
  CipherKeyDelegate? get cipherKeyDelegate;

  // 受保护方法：获取消息打包器（消息加解密/签名的具体实现）
  // 作用：解耦打包逻辑，Messenger仅做接口转发，具体实现由Packer完成
  Packer? get packer;

  // 受保护方法：获取消息处理器（消息解析/分发的具体实现）
  // 作用：解耦处理逻辑，Messenger仅做接口转发，具体实现由Processor完成
  Processor? get processor;

  //-------- SecureMessageDelegate 接口实现（密钥反序列化+缓存）

  /// 反序列化并缓存消息解密密钥（核心辅助方法）
  /// 核心逻辑：
  /// 1. 若传入key为空，先从缓存/密钥代理中获取解密密钥；
  /// 2. 若传入key不为空，先反序列化密钥，解密成功后缓存该密钥；
  /// 3. 密钥缓存的核心目的：避免重复解密，提升后续相同会话的消息处理效率。
  /// @param key - 序列化后的密钥字节数组（可为空）
  /// @param sMsg - 安全消息（已加密/签名的消息）
  /// @return 反序列化后的对称解密密钥（解密失败返回null）
  @override
  Future<SymmetricKey?> deserializeKey(Uint8List? key, SecureMessage sMsg) async{
    if (key == null) {
      // 场景1：密钥未随消息传输，从缓存/密钥代理中获取解密密钥
      // 密钥查找方向：发送方 → 接收方/群组（保证只有合法接收方能解密）
      return await getDecryptKey(sMsg);
    }
    // 场景2：密钥随消息传输，先调用父类方法反序列化密钥
    SymmetricKey? password = await super.deserializeKey(key, sMsg);
    // 解密成功时缓存密钥（后续同会话消息可直接复用）
    if(password != null){
      // 缓存密钥：按「发送方→接收方/群组」方向缓存，保证后续消息快速解密
      await cacheDecryptKey(password, sMsg);
    }
    return password;
  }

  //
  //  加密密钥相关核心接口（消息加解密的密钥管理）
  //

  /// 获取消息加密密钥（发送消息时调用）
  /// 核心逻辑：
  /// 1. 从密钥代理（CipherKeyDelegate）中获取「发送方→接收方/群组」的对称加密密钥；
  /// 2. 若密钥不存在且generate=true，自动生成新密钥并缓存；
  /// 3. 中心化架构适配：只需修改CipherKeyDelegate的实现，从服务端获取/生成密钥。
  /// @param iMsg - 即时消息（未加密的原始消息）
  /// @return 用于加密消息的对称密钥（获取/生成失败返回null）
  Future<SymmetricKey?> getEncryptKey(InstantMessage iMsg) async {
     ID sender = iMsg.sender; // 消息发送方ID
    // 获取消息的实际接收方（个人/群组，处理群组消息的特殊逻辑）
    ID target = CipherKeyDelegate.getDestinationForMessage(iMsg);
    var db = cipherKeyDelegate;
    // 从密钥代理中获取/生成加密密钥（generate=true：允许自动生成新密钥）
    return await db?.getCipherKey(sender: sender, receiver: target, generate: true);
  }

  /// 获取消息解密密钥（接收消息时调用）
  /// 核心逻辑：
  /// 1. 从密钥代理（CipherKeyDelegate）中获取「发送方→接收方/群组」的对称解密密钥；
  /// 2. generate=false：仅从缓存/历史记录中查找，不自动生成新密钥；
  /// 3. 分布式架构：从本地密钥缓存查找；中心化架构：从服务端API查找。
  /// @param sMsg - 安全消息（已加密的消息）
  /// @return 用于解密消息的对称密钥（查找失败返回null）
  Future<SymmetricKey?> getDecryptKey(SecureMessage sMsg) async {
    ID sender = sMsg.sender; // 消息发送方ID
    // 获取消息的实际接收方（个人/群组）
    ID target = CipherKeyDelegate.getDestinationForMessage(sMsg);
    var db = cipherKeyDelegate;
    // 从密钥代理中查找解密密钥（generate=false：不生成新密钥）
    return await db?.getCipherKey(sender: sender, receiver: target, generate: false);
  }

  /// 缓存解密密钥（解密成功后调用）
  /// 核心目的：缓存「发送方→接收方/群组」的解密密钥，避免后续同会话消息重复解密，提升性能；
  /// 中心化适配：可将密钥缓存到本地（如SharedPreferences），或同步到服务端。
  /// @param key  - 解密成功的对称密钥
  /// @param sMsg - 安全消息（已解密的消息）
  Future<void> cacheDecryptKey(SymmetricKey key, SecureMessage sMsg) async {
    ID sender = sMsg.sender; // 消息发送方ID
    // 获取消息的实际接收方（个人/群组）
    ID target = CipherKeyDelegate.getDestinationForMessage(sMsg);
    var db = cipherKeyDelegate;
    // 调用密钥代理缓存密钥
    return await db?.cacheCipherKey(sender: sender, receiver: target, key: key);
  }

  //
  //  消息打包相关接口（发送消息时的打包流程：加密→签名→序列化）
  //

  /// 加密即时消息（打包第一步）
  /// 核心逻辑：调用Packer的实现，将原始即时消息（InstantMessage）加密为安全消息（SecureMessage）；
  /// 适配说明：中心化/分布式架构的加密逻辑一致，仅密钥来源不同（由CipherKeyDelegate控制）。
  /// @param iMsg - 未加密的原始即时消息
  /// @return 加密后的安全消息（加密失败返回null）
  @override
  Future<SecureMessage?> encryptMessage(InstantMessage iMsg) async =>
      await packer?.encryptMessage(iMsg);

  /// 签名安全消息（打包第二步）
  /// 核心逻辑：调用Packer的实现，为加密后的安全消息添加发送方签名，生成可靠消息（ReliableMessage）；
  /// 作用：保证消息的不可篡改性和身份可追溯性。
  /// @param sMsg - 加密后的安全消息
  /// @return 带签名的可靠消息（签名失败返回null）
  @override
  Future<ReliableMessage?> signMessage(SecureMessage sMsg) async =>
      await packer?.signMessage(sMsg);

  // 以下两个序列化/反序列化方法被注释，如需启用可取消注释：
  // /// 序列化可靠消息（打包第三步）
  // /// 核心逻辑：将带签名的可靠消息序列化为字节数组，用于网络传输；
  // /// @param rMsg - 带签名的可靠消息
  // /// @return 序列化后的字节数组（序列化失败返回null）
  // @override
  // Future<Uint8List?> serializeMessage(ReliableMessage rMsg) async =>
  //     await packer?.serializeMessage(rMsg);
  //
  // /// 反序列化可靠消息（接收消息第一步）
  // /// 核心逻辑：将网络传输的字节数组反序列化为可靠消息，用于后续验签/解密；
  // /// @param data - 网络传输的字节数组
  // /// @return 反序列化后的可靠消息（反序列化失败返回null）
  // @override
  // Future<ReliableMessage?> deserializeMessage(Uint8List data) async =>
  //     await packer?.deserializeMessage(data);

  /// 验签可靠消息（接收消息第二步）
  /// 核心逻辑：调用Packer的实现，验证可靠消息的签名，确认消息未被篡改且发送方身份合法；
  /// 验签成功后，剥离签名得到安全消息（SecureMessage），用于后续解密。
  /// @param rMsg - 带签名的可靠消息
  /// @return 验签后的安全消息（验签失败返回null）
  @override
  Future<SecureMessage?> verifyMessage(ReliableMessage rMsg) async =>
      await packer?.verifyMessage(rMsg);

  /// 解密安全消息（接收消息第三步）
  /// 核心逻辑：调用Packer的实现，将验签后的安全消息解密为原始即时消息（InstantMessage）；
  /// 解密密钥来源：由deserializeKey方法从缓存/密钥代理中获取。
  /// @param sMsg - 加密后的安全消息
  /// @return 解密后的原始即时消息（解密失败返回null）
  @override
  Future<InstantMessage?> decryptMessage(SecureMessage sMsg) async =>
      await packer?.decryptMessage(sMsg);

  //
  //  消息处理相关接口（接收消息后的处理流程：解析包→验签→解密→处理内容）
  //

  /// 处理网络传输包（接收消息第一步：解包）
  /// 核心逻辑：调用Processor的实现，将原始网络字节包解析为可靠消息列表；
  /// 作用：处理粘包/拆包、协议版本兼容等底层网络问题。
  /// @param data - 网络接收的原始字节数组
  /// @return 解析后的可靠消息列表（解析失败返回空列表）
  @override
  Future<List<Uint8List>> processPackage(Uint8List data) async =>
      await processor!.processPackage(data);

  /// 处理可靠消息（接收消息第二步：验签）
  /// 核心逻辑：调用Processor的实现，对可靠消息验签，得到安全消息列表；
  /// 作用：过滤篡改/伪造的消息，保证消息合法性。
  /// @param rMsg - 带签名的可靠消息
  /// @return 验签后的安全消息列表（验签失败返回空列表）
  @override
  Future<List<ReliableMessage>> processReliableMessage(ReliableMessage rMsg) async =>
      await processor!.processReliableMessage(rMsg);

  /// 处理安全消息（接收消息第三步：解密）
  /// 核心逻辑：调用Processor的实现，对安全消息解密，得到即时消息列表；
  /// 作用：仅合法接收方能解密，保证消息私密性。
  /// @param sMsg - 加密后的安全消息
  /// @param rMsg - 原始可靠消息（用于辅助解密）
  /// @return 解密后的即时消息列表（解密失败返回空列表）
  @override
  Future<List<SecureMessage>> processSecureMessage(SecureMessage sMsg, ReliableMessage rMsg) async =>
      await processor!.processSecureMessage(sMsg, rMsg);

  /// 处理即时消息（接收消息第四步：内容分发）
  /// 核心逻辑：调用Processor的实现，解析即时消息的内容，分发到对应业务模块（如聊天、通知）；
  /// 作用：将通用的消息结构转换为业务可识别的内容类型（文本、图片、语音等）。
  /// @param iMsg - 解密后的原始即时消息
  /// @param rMsg - 原始可靠消息（用于辅助处理）
  /// @return 处理后的消息内容列表（处理失败返回空列表）
  @override
  Future<List<InstantMessage>> processInstantMessage(InstantMessage iMsg, ReliableMessage rMsg) async =>
      await processor!.processInstantMessage(iMsg, rMsg);

  /// 处理消息内容（接收消息第五步：业务处理）
  /// 核心逻辑：调用Processor的实现，对消息内容进行业务层处理（如显示聊天、触发通知）；
  /// 适配说明：中心化架构下，可在此处对接服务端的业务逻辑（如消息已读回执、同步消息记录）。
  /// @param content - 消息内容（文本/图片/语音等）
  /// @param rMsg - 原始可靠消息（用于获取发送方/接收方等上下文）
  /// @return 处理后的内容列表（业务处理失败返回空列表）
  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async =>
      await processor!.processContent(content, rMsg);
}