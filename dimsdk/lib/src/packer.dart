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

import 'package:dimsdk/core.dart';
import 'package:dimsdk/dimp.dart';
import 'package:dimsdk/msg.dart';

/// 消息打包器核心实现（IM消息加解密/签名验签的核心处理类）
/// 核心定位：实现 `Packer` 接口，整合三类细分打包器（Instant/Secure/Reliable），
/// 完成消息「发送（加密→签名）」和「接收（验签→解密）」的全流程处理，
/// 是DIM协议中消息安全传输的核心实现，兼容分布式/中心化架构（仅需适配密钥来源）。
/// 
/// 设计模式：
/// - 组合模式：通过整合三类细分打包器，拆分复杂的消息处理逻辑，降低耦合；
/// - 模板方法：定义消息处理的固定流程，具体实现由细分打包器完成；
/// - 钩子方法：预留 `createXXXPacker` 方法，支持扩展自定义打包器。
abstract class MessagePacker extends TwinsHelper implements Packer {
   /// 构造方法：初始化核心依赖和细分打包器
  /// @param facebook - 实体管理核心（提供用户/群组/密钥查询）
  /// @param messenger - 信使核心（提供密钥管理、消息收发能力）
  MessagePacker(Facebook facebook, Messenger messenger)
      : super(facebook, messenger) {
    // 创建三类细分打包器，分工处理不同类型消息
    instantPacker  = createInstantMessagePacker(messenger);  // 即时消息打包器（原始消息处理）
    securePacker   = createSecureMessagePacker(messenger);   // 安全消息打包器（加密/解密）
    reliablePacker = createReliableMessagePacker(messenger); // 可靠消息打包器（签名/验签）
  }

  // 受保护字段：各类消息打包器实例（分工处理不同阶段的消息）
  late final InstantMessagePacker  instantPacker;  // 处理原始即时消息（未加密）
  late final SecureMessagePacker   securePacker;   // 处理加密后的安全消息
  late final ReliableMessagePacker reliablePacker; // 处理带签名的可靠消息

  // 受保护方法：创建消息打包器（钩子方法，支持子类重写扩展自定义打包器）
  /// 创建即时消息打包器（可重写为自定义实现）
  /// @param delegate - 即时消息代理（提供密钥、用户信息等）
  /// @return 即时消息打包器实例
  InstantMessagePacker createInstantMessagePacker(InstantMessageDelegate delegate) =>
      InstantMessagePacker(delegate);
  
  /// 创建安全消息打包器（可重写为自定义实现）
  /// @param delegate - 安全消息代理（提供解密密钥等）
  /// @return 安全消息打包器实例
  SecureMessagePacker createSecureMessagePacker(SecureMessageDelegate delegate) =>
      SecureMessagePacker(delegate);
  
  /// 创建可靠消息打包器（可重写为自定义实现）
  /// @param delegate - 可靠消息代理（提供验签公钥等）
  /// @return 可靠消息打包器实例
  ReliableMessagePacker createReliableMessagePacker(ReliableMessageDelegate delegate) =>
      ReliableMessagePacker(delegate);

  // 受保护方法：获取档案管理员（数据持久层，适配中心化/分布式的关键）
  /// 获取档案管理员（数据持久层接口）
  /// 作用：分布式架构从本地存储读写Meta/签证；中心化架构从服务端API读写
  Archivist? get archivist => facebook?.archivist;

  //
  //  消息发送流程：即时消息 → 安全消息 → 可靠消息 → 二进制数据
  //  核心步骤：1.加密 2.签名 3.序列化（序列化方法被注释，可按需启用）
  //

  /// 加密即时消息（发送流程第一步）
  /// 核心逻辑：
  /// 1. 获取「发送方→接收方/群组」的对称加密密钥；
  /// 2. 区分个人/群组消息，调用不同加密逻辑；
  /// 3. 加密消息内容，生成安全消息（SecureMessage）；
  /// 中心化适配：密钥来源由 Messenger 的 CipherKeyDelegate 控制（从服务端获取）。
  /// @param iMsg - 未加密的原始即时消息
  /// @return 加密后的安全消息（加密失败返回null）
  @override
  Future<SecureMessage?> encryptMessage(InstantMessage iMsg)async{
    // TODO: 调用前检查接收方，确保签证密钥存在；
    //       否则暂停消息，等待接收方的签证/元数据；
    //       若接收方是群组，还需查询所有成员的签证！
    assert(facebook != null && messenger != null, '核心依赖未就绪（Facebook/Messenger不能为空）');

    SecureMessage? sMsg;
    // 注意：发送群组消息前，可决定是否暴露群组ID
    //      (A) 若不想暴露群组ID：
    //          加密前拆分为多条消息，将接收方改为每个成员，群组信息隐藏在内容中；
    //          此时打包器会使用个人消息密钥（用户到用户）；
    //      (B) 若群组ID公开：
    //          无需担心暴露问题，可保留接收方为群组ID，或拆分消息时将群组ID设为'group'字段；
    //          此时本地打包器会使用群组消息密钥（用户到群组）加密，
    //          远端打包器解密前可获取公开的群组ID以使用正确密钥。
    ID receiver = iMsg.receiver; // 消息接收方（个人/群组）

    ///
    ///  1. 获取消息密钥（方向：发送方→接收方 或 发送方→群组）
    ///    - 分布式：从本地密钥缓存获取/生成；
    ///    - 中心化：从服务端API获取；
    ///    - generate=true：密钥不存在时自动生成；
    ///
    SymmetricKey? password = await messenger?.getEncryptKey(iMsg);
    if (password == null) {
      assert(false, '获取消息密钥失败: ${iMsg.sender} => $receiver, ${iMsg['group']}');
      return null;
    }

    //
    //  2. 加密消息内容为密文（适配个人/群组消息）
    //
    if (receiver.isGroup) {
      // 群组消息：为每个成员加密密钥（分布式逻辑，中心化可简化）
      List<ID>? members = await facebook?.getMembers(receiver);
      if (members == null || members.isEmpty) {
        assert(false, '群组未就绪（成员列表为空）: $receiver');
        return null;
      }
      // 服务器不会发送群组消息，此处必定是客户端；
      // 客户端在加密前已检查群组元数据和成员，因此成员列表必定存在
      sMsg = await instantPacker.encryptMessage(iMsg, password, members: members);
    } else {
      // 个人消息（或拆分后的群组消息）：直接加密内容
      sMsg = await instantPacker.encryptMessage(iMsg, password);
    }
    if (sMsg == null) {
      // 加密公钥未找到（分布式：本地无接收方签证；中心化：服务端未返回公钥）
      assert(false, '消息加密失败: ${iMsg.sender} => $receiver, ${iMsg['group']}');
      // TODO: 暂停消息，等待接收方元数据（中心化可触发服务端拉取接收方公钥）
      return null;
    }

    // 注意：将内容类型复制到信封中
    //       帮助中间节点（如服务器）识别消息类型（文本/图片/语音等）
    sMsg.envelope.type = iMsg.content.type;

    // 加密完成，返回安全消息
    return sMsg;
  }

  /// 签名安全消息（发送流程第二步）
  /// 核心逻辑：发送方用自己的私钥对加密后的消息密文签名，保证消息不可篡改、身份可追溯；
  /// 中心化适配：私钥来源由 Facebook 控制（本地存储/服务端托管）。
  /// @param sMsg - 加密后的安全消息
  /// @return 带签名的可靠消息（签名失败返回null）
  @override
  Future<ReliableMessage?> signMessage(SecureMessage sMsg) async {
    assert(sMsg.data.isNotEmpty, '消息数据不能为空（加密后的密文为空）: $sMsg');
    // 发送方对消息密文进行签名（调用可靠消息打包器完成签名）
    return await securePacker.signMessage(sMsg);
  }

  // 序列化可靠消息（发送流程第三步，被注释，可按需启用）
  // 核心逻辑：将带签名的可靠消息序列化为字节数组，用于网络传输；
  // 适配说明：中心化/分布式序列化逻辑一致，仅传输方式不同（P2P/服务器转发）。
  // @override
  // Future<Uint8List?> serializeMessage(ReliableMessage rMsg) async =>
  //     compressor.compressReliableMessage(rMsg.toMap());

  //
  //  消息接收流程：二进制数据 → 可靠消息 → 安全消息 → 即时消息
  //  核心步骤：1.反序列化（被注释） 2.验签 3.解密
  //

  // 反序列化可靠消息（接收流程第一步，被注释，可按需启用）
  // 核心逻辑：将网络传输的字节数组反序列化为可靠消息，用于后续验签/解密；
  // @override
  // Future<ReliableMessage?> deserializeMessage(Uint8List data) async {
  //   Object? info = compressor.extractReliableMessage(data);
  //   return ReliableMessage.parse(info);
  // }

  /// 检查消息附件中的元数据和签证（验签前的前置检查）
  /// 核心逻辑：
  /// 1. 提取消息附件中的Meta（身份元数据）和Visa（签证）；
  /// 2. 保存到本地/服务端，保证发送方身份数据的合法性；
  /// 中心化适配：Meta/Visa 保存到服务端，而非本地。
  /// @param rMsg - 接收到的可靠消息
  /// @return 检查通过返回true，否则返回false
  // 受保护方法（仅内部调用）
  Future<bool> checkAttachments(ReliableMessage rMsg) async {
    if (archivist == null) {
      assert(false, '档案管理员未就绪（无法保存Meta/Visa）');
      return false;
    }
    ID sender = rMsg.sender; // 消息发送方ID
    // [元数据协议] 提取并保存发送方的Meta（身份核心数据）
    Meta? meta = MessageUtils.getMeta(rMsg);
    if (meta != null) {
      await archivist?.saveMeta(meta, sender); // 分布式：存本地；中心化：存服务端
    }
    // [签证协议] 提取并保存发送方的Visa（通信密钥文档）
    Visa? visa = MessageUtils.getVisa(rMsg);
    if (visa != null) {
      await archivist?.saveDocument(visa); // 分布式：存本地；中心化：存服务端
    }
    //
    //  TODO: 调用前检查[签证协议]
    //        确保发送方的元数据/签证已存在
    //        (由上层应用实现，中心化可调用服务端接口检查)
    //
    return true;
  }

  /// 验签可靠消息（接收流程第二步）
  /// 核心逻辑：
  /// 1. 前置检查：提取并保存发送方的Meta/Visa；
  /// 2. 用发送方的公钥验证消息签名，确保消息未被篡改、发送方身份合法；
  /// 中心化适配：公钥从服务端获取，而非本地。
  /// @param rMsg - 带签名的可靠消息
  /// @return 验签后的安全消息（验签失败返回null）
  @override
  Future<SecureMessage?> verifyMessage(ReliableMessage rMsg) async {
    // 验签前确保发送方元数据已存在（检查并保存消息附件中的Meta/Visa）
    if (!await checkAttachments(rMsg)) {
      return null;
    }

    assert(rMsg.signature.isNotEmpty, '消息签名不能为空（无法验签）: $rMsg');
    // 用签名验证消息密文完整性（调用可靠消息打包器完成验签）
    return await reliablePacker.verifyMessage(rMsg);
  }

  /// 解密安全消息（接收流程第三步）
  /// 核心逻辑：
  /// 1. 校验接收方合法性：确保当前本地用户是消息的合法接收者（个人/群成员）；
  /// 2. 用对称密钥解密密文，还原原始即时消息；
  /// 中心化适配：本地用户由 Facebook.selectLocalUser 控制（返回当前登录用户）。
  /// @param sMsg - 加密后的安全消息
  /// @return 解密后的原始即时消息（解密失败抛出异常/返回null）
  @override
  Future<InstantMessage?> decryptMessage(SecureMessage sMsg) async {
    // TODO: 调用前检查接收方，确保你是合法接收者，
    //       若是群组消息则确保你是群成员，
    //       这样才能拥有解密所需的私钥。
    ID receiver = sMsg.receiver; // 消息接收方（个人/群组）
    // 匹配本地用户（分布式：遍历本地用户列表；中心化：返回当前登录用户）
    ID? me = await facebook?.selectLocalUser(receiver);
    if (me == null) {
      // 非目标接收者（当前用户无权限解密此消息）
      throw Exception('接收方错误: $receiver, 来自 ${sMsg.sender}, 群组 ${sMsg.group}');
    }
    assert(sMsg.data.isNotEmpty, '消息数据为空（密文为空）: '
        '${sMsg.sender} => ${sMsg.receiver}, ${sMsg.group}');
    // 解密密文还原消息内容（调用安全消息打包器完成解密）
    return await securePacker.decryptMessage(sMsg, me);

    // TODO: 检查绝密消息（由上层应用实现，如权限校验、敏感内容过滤）
    //       (中心化可在此处调用服务端接口校验消息权限)
  }
}