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
import 'package:lnc/log.dart';
import 'package:object_key/object_key.dart';

import 'compat/compatible.dart';
import 'compat/compressor.dart';
import 'facebook.dart';
import 'session.dart';


/// 通用信使抽象类
/// 继承Messenger并实现Transmitter接口，负责消息的加密、签名、序列化、发送等核心流程
abstract class CommonMessenger extends Messenger with Logging
    implements Transmitter {
  
  /// 构造方法
  /// [session] 会话实例（用于消息队列管理）
  /// [_facebook] Facebook实例（用户/群组数据管理）
  /// [database] 密码密钥代理（用于密钥管理）
  CommonMessenger(this.session, this._facebook, this.database)
      : _packer = null, _processor = null;

  /// 会话实例（管理消息发送队列）
  final Session session;
  /// Facebook实例（用户/群组数据核心）
  final CommonFacebook _facebook;
  /// 密码密钥代理（处理加密/解密密钥）
  final CipherKeyDelegate database;

  /// 消息打包器（负责消息加密/签名）
  Packer? _packer;
  /// 消息处理器（负责消息解析/处理）
  Processor? _processor;

  /// 压缩器实例（兼容型压缩器）
  final Compressor _compressor = CompatibleCompressor();

  /// 获取Facebook实例
  @override
  CommonFacebook get facebook => _facebook;

  /// 获取压缩器实例
  @override
  Compressor get compressor => _compressor;

  /// 获取密码密钥代理
  @override
  CipherKeyDelegate? get cipherKeyDelegate => database;

  /// 获取/设置消息打包器
  @override
  Packer? get packer => _packer;
  set packer(Packer? messagePacker) => _packer = messagePacker;

  /// 获取/设置消息处理器
  @override
  Processor? get processor => _processor;
  set processor(Processor? messageProcessor) => _processor = messageProcessor;

  /// 序列化可靠消息（重写父类方法）
  /// 序列化前修复Meta和Visa附件
  /// [rMsg] 可靠消息（已加密+签名）
  /// 返回：序列化后的字节数组（失败返回null）
  @override
  Future<Uint8List?> serializeMessage(ReliableMessage rMsg) async {
    // 修复消息中的Meta附件（确保Meta完整）
    Compatible.fixMetaAttachment(rMsg);
    // 修复消息中的Visa附件（确保Visa完整）
    Compatible.fixVisaAttachment(rMsg);
    // 调用父类方法完成序列化
    return await super.serializeMessage(rMsg);
  }

  /// 反序列化可靠消息（重写父类方法）
  /// [data] 序列化后的字节数组
  /// 返回：可靠消息实例（失败返回null）
  @override
  Future<ReliableMessage?> deserializeMessage(Uint8List data) async {
    // 数据长度校验：小于等于8字节视为无效
    if (data.length <= 8) {
      // message data error
      return null;
      // 注释：原JSON格式校验逻辑被注释，保留原始代码
      // } else if (data.first != '{'.codeUnitAt(0) || data.last != '}'.codeUnitAt(0)) {
      //   // only support JsON format now
      //   return null;
    }
    // 调用父类方法完成反序列化
    ReliableMessage? rMsg = await super.deserializeMessage(data);
    if (rMsg != null) {
      // 修复消息中的Meta和Visa附件
      Compatible.fixMetaAttachment(rMsg);
      Compatible.fixVisaAttachment(rMsg);
    }
    return rMsg;
  }

  //-------- InstantMessageDelegate 接口实现

  /// 加密密钥（重写父类方法，增加异常捕获）
  /// [key] 待加密的密钥字节数组
  /// [receiver] 接收方ID
  /// [iMsg] 即时消息
  /// 返回：加密后的密钥字节数组（失败返回null）
  @override
  Future<Uint8List?> encryptKey(Uint8List key, ID receiver, InstantMessage iMsg) async {
    try {
      // 调用父类方法加密密钥
      return await super.encryptKey(key, receiver, iMsg);
    } catch (e, st) {
      // 捕获异常并记录日志
      // FIXME: 异常处理待优化
      logError('failed to encrypt key for receiver: $receiver, error: $e');
      logDebug('failed to encrypt key for receiver: $receiver, error: $e, $st');
      return null;
    }
  }

  /// 序列化对称密钥（重写父类方法，处理复用标记）
  /// [password] 对称密钥
  /// [iMsg] 即时消息
  /// 返回：序列化后的密钥字节数组（失败返回null）
  @override
  Future<Uint8List?> serializeKey(SymmetricKey password, InstantMessage iMsg) async {
    // TODO: 复用消息密钥（待实现）

    // 0. 检查消息密钥的复用标记
    Object? reused = password['reused'];
    Object? digest = password['digest'];
    if (reused == null && digest == null) {
      // 无复用标记，直接序列化
      return await super.serializeKey(password, iMsg);
    }
    // 1. 序列化前移除标记（避免序列化包含多余字段）
    password.remove('reused');
    password.remove('digest');
    // 2. 序列化不含标记的密钥
    Uint8List? data = await super.serializeKey(password, iMsg);
    // 3. 序列化后恢复标记
    if (Converter.getBool(reused) == true) {
      password['reused'] = true;
    }
    if (digest != null) {
      password['digest'] = digest;
    }
    // OK
    return data;
  }

  /// 序列化消息内容（重写父类方法，修复内容格式）
  /// [content] 消息内容
  /// [password] 对称密钥
  /// [iMsg] 即时消息
  /// 返回：序列化后的内容字节数组
  @override
  Future<Uint8List> serializeContent(Content content, SymmetricKey password, InstantMessage iMsg) async {
    // 修复出站消息内容格式
    CompatibleOutgoing.fixContent(content);
    // 调用父类方法完成序列化
    return await super.serializeContent(content, password, iMsg);
  }

  //
  //  Transmitting Message 接口实现（Transmitter）
  //

  /// 发送消息内容（核心发送入口）
  /// [content] 消息内容
  /// [sender] 发送方ID（为空则使用当前登录用户）
  /// [receiver] 接收方ID（必传）
  /// [priority] 发送优先级（数值越小优先级越高）
  /// 返回：即时消息和可靠消息的配对（可靠消息为null表示发送失败）
  @override
  Future<Pair<InstantMessage, ReliableMessage?>> sendContent(Content content,
      {required ID? sender, required ID receiver, int priority = 0}) async {
    // 发送方为空时，使用当前登录用户
    if (sender == null) {
      User? current = await facebook.currentUser;
      assert(current != null, 'current suer not set'); // 注意：原代码拼写错误"suer"，保留不修改
      sender = current!.identifier;
    }
    // 创建消息信封
    Envelope env = Envelope.create(sender: sender, receiver: receiver);
    // 创建即时消息
    InstantMessage iMsg = InstantMessage.create(env, content);
    // 发送即时消息
    ReliableMessage? rMsg = await sendInstantMessage(iMsg, priority: priority);
    // 返回消息配对
    return Pair(iMsg, rMsg);
  }

  // 私有方法：为即时消息附加Visa时间
  /// [sender] 发送方ID
  /// [iMsg] 即时消息
  /// 返回：true=附加成功，false=附加失败
  Future<bool> attachVisaTime(ID sender, InstantMessage iMsg) async {
    // 命令类型消息无需附加时间
    if (iMsg.content is Command) {
      // no need to attach times for command
      return false;
    }
    // 获取发送方的Visa文档
    Visa? doc = await facebook.getVisa(sender);
    if (doc == null) {
      assert(false, 'failed to get visa document for sender: $sender');
      return false;
    }
    // 附加发送方文档时间
    DateTime? lastDocumentTime = doc.time;
    if (lastDocumentTime == null) {
      assert(false, 'document error: $doc');
      return false;
    } else {
      // 设置SDT（Sender Document Time）字段
      iMsg.setDateTime('SDT', lastDocumentTime);
    }
    return true;
  }

  /// 发送即时消息（核心流程：加密→签名→发送）
  /// [iMsg] 即时消息（明文）
  /// [priority] 发送优先级
  /// 返回：可靠消息（失败返回null）
  @override
  Future<ReliableMessage?> sendInstantMessage(InstantMessage iMsg, {int priority = 0}) async {
    ID sender = iMsg.sender;
    //
    //  0. 检查循环消息（发送方=接收方）
    //
    if (sender == iMsg.receiver) {
      // 丢弃循环消息并记录日志
      logWarning('drop cycled message: ${iMsg.content} '
          '${iMsg.sender} => ${iMsg.receiver}, ${iMsg.group}');
      return null;
    } else {
      // 记录发送日志
      logDebug('send instant message (type=${iMsg.content.type}): '
          '$sender => ${iMsg.receiver}, ${iMsg.group}');
      // 为接收方附加发送方的文档时间（用于同步用户信息）
      bool ok = await attachVisaTime(sender, iMsg);
      // 断言：命令消息允许附加失败，其他消息必须附加成功
      assert(ok || iMsg.content is Command, 'failed to attach document time: $sender => ${iMsg.content}');
    }
    //
    //  1. 加密消息（明文→安全消息）
    //
    SecureMessage? sMsg = await encryptMessage(iMsg);
    if (sMsg == null) {
      // 公钥未找到时返回null（注释：原断言被注释）
      // assert(false, 'public key not found?');
      return null;
    }
    //
    //  2. 签名消息（安全消息→可靠消息）
    //
    ReliableMessage? rMsg = await signMessage(sMsg);
    if (rMsg == null) {
      // 签名失败抛出异常
      // TODO: 设置消息状态为错误
      throw Exception('failed to sign message: $sMsg');
    }
    //
    //  3. 发送消息
    //
    if (await sendReliableMessage(rMsg, priority: priority)) {
      return rMsg;
    } else {
      // 发送失败返回null
      return null;
    }
  }

  /// 发送可靠消息（最终发送入口）
  /// [rMsg] 可靠消息（已加密+签名）
  /// [priority] 发送优先级
  /// 返回：true=发送成功，false=发送失败
  @override
  Future<bool> sendReliableMessage(ReliableMessage rMsg, {int priority = 0}) async {
    // 0. 检查循环消息
    if (rMsg.sender == rMsg.receiver) {
      logWarning('drop cycled message: ${rMsg.sender} => ${rMsg.receiver}, ${rMsg.group}');
      return false;
    }
    // 1. 序列化消息
    Uint8List? data = await serializeMessage(rMsg);
    if (data == null) {
      assert(false, 'failed to serialize message: $rMsg');
      return false;
    }
    // 2. 调用会话的消息队列方法发送数据包
    //    将消息数据包放入当前会话的等待队列
    return session.queueMessagePackage(rMsg, data, priority: priority);
  }
}