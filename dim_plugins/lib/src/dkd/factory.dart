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

import 'dart:math';

import 'package:dim_plugins/dim_plugins.dart';

/// 消息工厂（核心）
/// 核心作用：
/// 1. 实现 4 个工厂接口，一站式处理消息的「创建+解析」；
/// 2. 生成全局唯一的消息序列号（SN），避免重复；
/// 3. 支持 DIMP 协议的 3 层消息解析：InstantMessage → SecureMessage → ReliableMessage；
/// 接口说明：
/// - EnvelopeFactory：消息信封（收发方+时间）的创建/解析；
/// - InstantMessageFactory：明文消息的创建/解析；
/// - SecureMessageFactory：加密消息的创建/解析；
/// - ReliableMessageFactory：可靠消息（加密+签名）的创建/解析；
class MessageFactory implements EnvelopeFactory, InstantMessageFactory, SecureMessageFactory, ReliableMessageFactory {
  
  /// 构造函数：初始化序列号生成器
  /// 补充说明：
  /// - 以当前时间戳为随机种子，初始化 SN 起始值；
  /// - SN 范围：0 ~ 0x7fffffff（2^31-1，避免负数）；
  MessageFactory() {
    Random random = Random(DateTime.now().microsecondsSinceEpoch);
    _sn = random.nextInt(0x80000000);  // 0 ~ 0x7fffffff
  }

  /// 序列号（SN）计数器，用于生成唯一的消息序列号
  int _sn = 0;

  /// 生成下一个序列号（线程安全，内部自增）
  /// 补充说明：
  /// - 范围：1 ~ 0x7fffffff（2^31-1），达到最大值后重置为1；
  /// - 保证同一聊天窗口内的消息 SN 不重复；
  /// 返回值：下一个唯一的序列号
  /* synchronized */int _next() {
    assert(_sn >= 0, 'serial number error: $_sn');
    if (_sn < 0x7fffffff) {  // 2 ** 31 - 1（最大正整数）
      _sn += 1;
    } else {
      _sn = 1;  // 达到最大值后重置
    }
    return _sn;
  }

  // ====================== EnvelopeFactory 接口实现 ======================
  /// 创建消息信封（消息头）
  /// 补充说明：
  /// - 信封包含：发送方ID、接收方ID、可选时间戳；
  /// - 是所有消息的基础载体；
  /// [sender] - 发送方ID（必填）
  /// [receiver] - 接收方ID（必填）
  /// [time] - 消息发送时间（可选，默认当前时间）
  /// 返回值：MessageEnvelope 实例
  @override
  Envelope createEnvelope({required ID sender, required ID receiver, DateTime? time}) {
    return MessageEnvelope.from(sender: sender, receiver: receiver, time: time);
  }

  /// 解析消息信封（从Map还原）
  /// 补充说明：
  /// - 校验必备字段：sender（发送方ID）；
  /// - 接收方、时间戳可选，解析失败返回null；
  /// [env] - 信封的原始Map
  /// 返回值：MessageEnvelope 实例（失败返回null）
  @override
  Envelope? parseEnvelope(Map env) {
    // 检查必备字段：sender（发送方ID）
    if (env['sender'] == null) {
      // env.sender should not empty - 信封发送方不能为空
      assert(false, 'envelope error: $env');
      return null;
    }
    return MessageEnvelope(env);
  }

  // ====================== InstantMessageFactory 接口实现 ======================
  /// 生成消息序列号（SN）
  /// 补充说明：
  /// - 核心设计：不使用时间相关值（避免同一时间多条消息重复），使用自增计数器；
  /// - 保证同一聊天窗口内的消息 SN 全局唯一；
  /// [msgType] - 消息类型（未使用，预留扩展）
  /// [now] - 当前时间（未使用，预留扩展）
  /// 返回值：唯一的序列号
  @override
  int generateSerialNumber(String? msgType, DateTime? now) {
    // 注释翻译：
    // 由于必须确保同一聊天窗口内的所有消息不会有相同的序列号，
    // 因此不能使用与时间相关的数值，最佳选择是完全随机的数字（这里用自增计数器）。
    return _next();
  }

  /// 创建明文消息（InstantMessage）
  /// 补充说明：
  /// - 明文消息 = 信封（头） + 内容（体），未加密、未签名；
  /// - 是消息的原始形态，后续会被加密/签名为 SecureMessage/ReliableMessage；
  /// [head] - 消息信封（头）
  /// [body] - 消息内容（体，如文本、命令、文件等）
  /// 返回值：PlainMessage 实例（明文消息）
  @override
  InstantMessage createInstantMessage(Envelope head, Content body) {
    return PlainMessage.from(head, body);
  }

  /// 解析明文消息（从Map还原）
  /// 补充说明：
  /// - 校验必备字段：sender（发送方）、content（内容）；
  /// - 明文消息是未加密的原始消息，解析失败返回null；
  /// [msg] - 明文消息的原始Map
  /// 返回值：PlainMessage 实例（失败返回null）
  @override
  InstantMessage? parseInstantMessage(Map msg) {
    // 检查必备字段：sender（发送方）、content（内容）
    if (msg['sender'] == null || msg['content'] == null) {
      // msg.sender should not be empty - 消息发送方不能为空
      // msg.content should not be empty - 消息内容不能为空
      assert(false, 'message error: $msg');
      return null;
    }
    return PlainMessage(msg);
  }

  // ====================== SecureMessageFactory 接口实现 ======================
  /// 解析加密消息（SecureMessage）
  /// 补充说明：
  /// - 加密消息分为两种形态：
  ///   1. 仅加密（无签名）：EncryptedMessage（含 data 字段，无 signature）；
  ///   2. 加密+签名：NetworkMessage（含 data + signature 字段）；
  /// - 校验必备字段：sender、data（加密后的内容）；
  /// [msg] - 加密消息的原始Map
  /// 返回值：EncryptedMessage/NetworkMessage 实例（失败返回null）
  @override
  SecureMessage? parseSecureMessage(Map msg) {
    // 检查必备字段：sender（发送方）、data（加密内容）
    if (msg['sender'] == null || msg['data'] == null) {
      // msg.sender should not be empty - 消息发送方不能为空
      // msg.data should not be empty - 加密内容不能为空
      assert(false, 'message error: $msg');
      return null;
    }
    // 检查是否有签名：有则为可靠消息（NetworkMessage），无则为仅加密消息
    if (msg['signature'] != null) {
      return NetworkMessage(msg);
    }
    return EncryptedMessage(msg);
  }

  // ====================== ReliableMessageFactory 接口实现 ======================
  /// 解析可靠消息（ReliableMessage）
  /// 补充说明：
  /// - 可靠消息 = 加密内容 + 数字签名，是最终在网络传输的形态；
  /// - 校验必备字段：sender、data（加密内容）、signature（签名）；
  /// - 解析通过则创建 NetworkMessage（网络传输的最终形态）；
  /// [msg] - 可靠消息的原始Map
  /// 返回值：NetworkMessage 实例（失败返回null）
  @override
  ReliableMessage? parseReliableMessage(Map msg) {
    // 检查必备字段：sender、data、signature（签名）
    if (msg['sender'] == null || msg['data'] == null || msg['signature'] == null) {
      // msg.sender should not be empty - 消息发送方不能为空
      // msg.data should not be empty - 加密内容不能为空
      // msg.signature should not be empty - 数字签名不能为空
      assert(false, 'message error: $msg');
      return null;
    }
    return NetworkMessage(msg);
  }
}