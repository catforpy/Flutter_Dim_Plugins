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
import 'package:dimsdk/cpu.dart';
import 'package:dimsdk/dimp.dart';

/// 消息处理器核心实现（IM消息接收处理的核心引擎）
/// 核心定位：实现 `Processor` 接口，定义消息接收后的完整处理流程，
/// 涵盖「反序列化→验签→解密→内容处理→响应构建」全链路，
/// 通过「内容处理器工厂」解耦不同类型消息（文本/图片/命令）的业务逻辑，
/// 兼容分布式/中心化架构（仅需适配内容处理器的业务逻辑）。
/// 
/// 设计模式：
/// - 模板方法模式：定义固定的消息处理流程模板，具体业务逻辑由「内容处理器工厂」提供；
/// - 工厂模式：通过 `ContentProcessorFactory` 创建不同类型的内容处理器，适配多类型消息；
/// - 责任链模式：消息处理流程按“包→可靠消息→安全消息→即时消息→内容”逐层处理，每层完成特定职责。
abstract class MessageProcessor extends TwinsHelper implements Processor{
  /// 构造方法：初始化核心依赖和内容处理器工厂
  /// @param facebook - 实体管理核心（提供用户/群组/本地用户查询）
  /// @param messenger - 信使核心（提供消息加解密/签名验签能力）
  MessageProcessor(Facebook facebook, Messenger messenger)
      : super(facebook, messenger) {
    // 创建内容处理器工厂（由子类实现具体创建逻辑，支持扩展）
    factory = createFactory(facebook, messenger);
  }

  /// 内容处理器工厂（私有字段）
  /// 核心作用：根据消息内容类型（文本/图片/命令等）创建对应的处理器，解耦业务逻辑
  // 私有字段（仅内部调用）
  late final ContentProcessorFactory factory;

  // 受保护方法：创建内容处理器工厂（钩子方法，需子类实现）
  /// 创建内容处理器工厂（必须由子类实现）
  /// 作用：中心化/分布式架构可通过实现不同的工厂，提供适配的内容处理器；
  /// 例如：中心化架构下，命令消息处理器可调用服务端API完成业务逻辑。
  /// @param facebook - 实体管理核心
  /// @param messenger - 信使核心
  /// @return 内容处理器工厂实例
  ContentProcessorFactory createFactory(Facebook facebook, Messenger messenger);

  //
  //  消息处理流程（从网络包到业务内容的逐层拆解+响应构建）
  //  核心步骤：
  //  1. processPackage：网络包 → 可靠消息 → 处理 → 响应包
  //  2. processReliableMessage：可靠消息 → 安全消息 → 处理 → 响应可靠消息
  //  3. processSecureMessage：安全消息 → 即时消息 → 处理 → 响应安全消息
  //  4. processInstantMessage：即时消息 → 内容 → 处理 → 响应即时消息
  //  5. processContent：内容 → 业务处理 → 响应内容
  //

  /// 处理网络传输包（消息处理第一层：解包）
  /// 核心逻辑：
  /// 1. 将网络字节包反序列化为可靠消息（ReliableMessage）；
  /// 2. 调用下层处理可靠消息，得到响应可靠消息列表；
  /// 3. 将响应消息序列化为字节包，用于网络发送；
  /// 中心化适配：反序列化/序列化逻辑不变，仅传输方式改为服务器转发。
  /// @param data - 网络接收的原始字节数组
  /// @return 响应消息的字节包列表（无响应返回空列表）
  @override
  Future<List<Uint8List>> processPackage(Uint8List data) async{
    Messenger? transceiver = messenger;
    assert(transceiver != null, '信使未就绪（无法反序列化/序列化消息）');
    // 1.反序列化消息：字节数组 -> 可靠消息（代签名的消息）
    ReliableMessage? rMsg = await transceiver?.deserializeMessage(data);
    if (rMsg == null) {
      // 无效消息（反序列化失败，直接返回空列表）
      return [];
    }
    // 2. 处理消息：调用下层处理可靠消息，得到响应可靠消息列表
    List<ReliableMessage> responses = await transceiver!.processReliableMessage(rMsg);
    if (responses.isEmpty) {
      // 无响应消息（处理完成但无需回复）
      return [];
    }
    // 3. 序列化响应消息：可靠消息 → 字节数组，用于网络发送
    List<Uint8List> packages = [];
    Uint8List? pack;
    for (ReliableMessage res in responses) {
      pack = await transceiver.serializeMessage(res);
      if (pack == null) {
        // 序列化失败（不应发生，跳过该响应）
        continue;
      }
      packages.add(pack);
    }
    return packages;
  }

  /// 处理可靠消息（消息处理第二层：验签）
  /// 核心逻辑：
  /// 1. 验证可靠消息的签名，得到安全消息（SecureMessage）；
  /// 2. 调用下层处理安全消息，得到响应安全消息列表；
  /// 3. 对响应安全消息签名，生成响应可靠消息；
  /// 中心化适配：验签逻辑不变，公钥从服务端获取（由Messenger/Packer适配）。
  /// @param rMsg - 带签名的可靠消息
  /// @return 响应可靠消息列表（无响应返回空列表）
  @override
  Future<List<ReliableMessage>> processReliableMessage(ReliableMessage rMsg) async {
    // TODO: 重写此方法，调用前检查广播消息（过滤无效广播/重复广播）
    Messenger? transceiver = messenger;
    assert(transceiver != null, '信使未就绪（无法验签/签名消息）');
    // 1. 验证消息签名：可靠消息 → 安全消息（验签失败返回空列表）
    SecureMessage? sMsg = await transceiver?.verifyMessage(rMsg);
    if (sMsg == null) {
      // TODO: 若发送方元数据不存在，暂停并等待（中心化可调用服务端拉取元数据）
      return [];
    }
    // 2. 处理消息：调用下层处理安全消息，得到响应安全消息列表
    List<SecureMessage> responses = await transceiver!.processSecureMessage(sMsg, rMsg);
    if (responses.isEmpty) {
      // 无响应消息
      return [];
    }
    // 3. 签名响应消息：安全消息 → 可靠消息，保证响应的合法性
    List<ReliableMessage> messages = [];
    ReliableMessage? msg;
    for (SecureMessage res in responses) {
      msg = await transceiver.signMessage(res);
      if (msg == null) {
        // 签名失败（不应发生，跳过该响应）
        continue;
      }
      messages.add(msg);
    }
    return messages;
    // TODO: 重写此方法，捕获"接收方错误"异常时将消息转发给目标接收者
    //       （中心化架构下，可通过服务器转发给正确的接收方）
  }

  /// 处理安全消息（消息处理第三层：解密）
  /// 核心逻辑：
  /// 1. 解密密安全消息，得到即时消息（InstantMessage）；
  /// 2. 调用下层处理即时消息，得到响应即时消息列表；
  /// 3. 对响应即时消息加密，生成响应安全消息；
  /// 中心化适配：解密密钥从服务端获取（由Messenger的CipherKeyDelegate适配）。
  /// @param sMsg - 加密后的安全消息
  /// @param rMsg - 原始可靠消息（用于上下文传递）
  /// @return 响应安全消息列表（无响应返回空列表）
  @override
  Future<List<SecureMessage>> processSecureMessage(SecureMessage sMsg, ReliableMessage rMsg) async {
    Messenger? transceiver = messenger;
    assert(transceiver != null, '信使未就绪（无法解密/加密消息）');
    // 1. 解密消息：安全消息 → 即时消息（原始未加密消息）
    InstantMessage? iMsg = await transceiver?.decryptMessage(sMsg);
    if (iMsg == null) {
      // 无法解密（非目标接收者/密钥错误），无需响应
      // 是否需要转发给其他接收者？（中心化可由服务器处理转发）
      return [];
    }
    // 2. 处理消息：调用下层处理即时消息，得到响应即时消息列表
    List<InstantMessage> responses = await transceiver!.processInstantMessage(iMsg, rMsg);
    if (responses.isEmpty) {
      // 无响应消息
      return [];
    }
    // 3. 加密响应消息：即时消息 → 安全消息，保证响应的私密性
    List<SecureMessage> messages = [];
    SecureMessage? msg;
    for (InstantMessage res in responses) {
      msg = await transceiver.encryptMessage(res);
      if (msg == null) {
        // 加密失败（不应发生，跳过该响应）
        continue;
      }
      messages.add(msg);
    }
    return messages;
  }

  /// 处理即时消息（消息处理第四层：构建响应消息）
  /// 核心逻辑：
  /// 1. 处理即时消息的内容，得到响应内容列表；
  /// 2. 匹配本地用户作为响应发送方，构建响应即时消息；
  /// 中心化适配：本地用户由Facebook.selectLocalUser返回（仅当前登录用户）。
  /// @param iMsg - 解密后的原始即时消息
  /// @param rMsg - 原始可靠消息（用于上下文传递）
  /// @return 响应即时消息列表（无响应返回空列表）
  @override
  Future<List<InstantMessage>> processInstantMessage(InstantMessage iMsg, ReliableMessage rMsg) async {
    Messenger? transceiver = messenger;
    assert(facebook != null && transceiver != null, '核心依赖未就绪（Facebook/Messenger不能为空）');
    // 1. 处理消息内容：调用下层处理内容，得到响应内容列表
    List<Content>? responses = await transceiver?.processContent(iMsg.content, rMsg);
    if (responses == null || responses.isEmpty) {
      // 无响应内容（业务处理完成但无需回复）
      return [];
    }
    // 2. 选择本地用户构建响应消息（分布式：遍历本地用户；中心化：当前登录用户）
    ID sender = iMsg.sender;       // 原消息发送方（响应的接收方）
    ID receiver = iMsg.receiver;   // 原消息接收方（当前用户/群组）
    ID? me = await facebook?.selectLocalUser(receiver); // 匹配本地合法接收用户
    if (me == null) {
      assert(false, '接收方错误（当前用户无权限处理）: $receiver');
      return [];
    }
    // 3. 打包响应消息：为每个响应内容创建即时消息
    List<InstantMessage> messages = [];
    Envelope env;
    for (Content res in responses) {
      // assert(res.isNotEmpty, '响应内容不能为空（不应发生）');
      // 创建响应信封：发送方=当前本地用户，接收方=原消息发送方
      env = Envelope.create(sender: me, receiver: sender);
      // 构建响应即时消息
      iMsg = InstantMessage.create(env, res);
      // assert(iMsg.isNotEmpty, '构建响应消息失败（不应发生）');
      messages.add(iMsg);
    }
    return messages;
  }

  /// 处理消息内容（消息处理第五层：业务逻辑处理）
  /// 核心逻辑：
  /// 1. 根据内容类型获取对应的内容处理器；
  /// 2. 调用处理器处理内容，得到响应内容；
  /// 中心化适配：通过实现自定义的ContentProcessorFactory，提供对接服务端的内容处理器；
  /// 例如：命令消息处理器调用服务端API完成“创建群组”“添加好友”等操作。
  /// @param content - 消息内容（文本/图片/命令等）
  /// @param rMsg - 原始可靠消息（用于上下文传递，如获取发送方/接收方）
  /// @return 响应内容列表（无响应返回空列表）
  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    // TODO: 重写此方法，调用前检查群组信息（中心化可调用服务端API校验群成员权限）
    // 1. 根据内容类型获取对应的处理器
    ContentProcessor? cpu = factory.getContentProcessor(content);
    if (cpu == null) {
      // 使用默认内容处理器（处理未知类型内容）
      cpu = factory.getContentProcessorForType(ContentType.ANY);
      assert(cpu != null, '获取默认内容处理器失败（无法处理未知类型消息）');
    }
    // 2. 调用处理器处理内容，返回响应内容
    return await cpu!.processContent(content, rMsg);
    // TODO: 重写此方法，过滤响应内容（如敏感内容过滤、权限校验）
    //       （中心化可调用服务端接口完成内容审核）
  }
}