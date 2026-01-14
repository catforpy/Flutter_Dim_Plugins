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

import 'package:dkd/dkd.dart';
import 'package:mkm/mkm.dart';

/// 内容助手接口
/// ~~~~~~~~~~~~~~~
/// 管理不同类型消息内容的工厂，提供解析能力
abstract interface class ContentHelper {
  /// 设置指定消息类型的内容工厂
  /// [msgType] - 消息类型标识
  /// [factory] - 内容工厂实例
  void setContentFactory(String msgType,ContentFactory factory);

  /// 获取指定消息类型的内容工厂
  /// [msgType] - 消息类型标识
  /// 返回：ContentFactory 实例（未找到返回null）
  ContentFactory? getContentFactory(String msgType);

  /// 解析对象为 Content 实例
  /// [content] - 待解析对象（Map/JSON字符串）
  /// 返回：Content 实例（解析失败返回null）
  Content? parseContent(Object? content);
}

/// 信封助手接口
/// ~~~~~~~~~~~~~~~
/// 管理信封工厂，提供信封的创建/解析能力
abstract interface class EnvelopeHelper {

  /// 设置信封工厂
  /// [factory] - 信封工厂实例
  void setEnvelopeFactory(EnvelopeFactory factory);
  
  /// 获取信封工厂
  /// 返回：EnvelopeFactory 实例（未设置返回null）
  EnvelopeFactory? getEnvelopeFactory();

  /// 创建消息信封
  /// [sender] - 发送方ID
  /// [receiver] - 接收方ID
  /// [time] - 消息时间（不传则默认当前时间）
  /// 返回：Envelope 实例
  Envelope createEnvelope({required ID sender, required ID receiver, DateTime? time});

  /// 解析对象为 Envelope 实例
  /// [env] - 待解析对象（Map/JSON字符串）
  /// 返回：Envelope 实例（解析失败返回null）
  Envelope? parseEnvelope(Object? env);
}

/// 即时消息助手接口
/// ~~~~~~~~~~~~~~~
/// 管理即时消息工厂，提供即时消息的创建/解析、序列号生成能力
abstract interface class InstantMessageHelper {

  /// 设置即时消息工厂
  /// [factory] - 即时消息工厂实例
  void setInstantMessageFactory(InstantMessageFactory factory);
  
  /// 获取即时消息工厂
  /// 返回：InstantMessageFactory 实例（未设置返回null）
  InstantMessageFactory? getInstantMessageFactory();

  /// 创建即时消息
  /// [head] - 消息信封
  /// [body] - 消息内容
  /// 返回：InstantMessage 实例
  InstantMessage createInstantMessage(Envelope head, Content body);

  /// 解析对象为 InstantMessage 实例
  /// [msg] - 待解析对象（Map/JSON字符串）
  /// 返回：InstantMessage 实例（解析失败返回null）
  InstantMessage? parseInstantMessage(Object? msg);

  /// 生成消息序列号（SN）
  /// [msgType] - 消息类型
  /// [now] - 消息时间
  /// 返回：uint64 类型的序列号（作为消息ID）
  int generateSerialNumber(String? msgType, DateTime? now);
}

/// 安全消息助手接口
/// ~~~~~~~~~~~~~~~
/// 管理安全消息工厂，提供安全消息的解析能力
abstract interface class SecureMessageHelper {

  /// 设置安全消息工厂
  /// [factory] - 安全消息工厂实例
  void setSecureMessageFactory(SecureMessageFactory factory);
  
  /// 获取安全消息工厂
  /// 返回：SecureMessageFactory 实例（未设置返回null）
  SecureMessageFactory? getSecureMessageFactory();

  /// 解析对象为 SecureMessage 实例
  /// [msg] - 待解析对象（Map/JSON字符串）
  /// 返回：SecureMessage 实例（解析失败返回null）
  SecureMessage? parseSecureMessage(Object? msg);
}

/// 可靠消息助手接口
/// ~~~~~~~~~~~~~~~
/// 管理可靠消息工厂，提供可靠消息的解析能力
abstract interface class ReliableMessageHelper {

  /// 设置可靠消息工厂
  /// [factory] - 可靠消息工厂实例
  void setReliableMessageFactory(ReliableMessageFactory factory);
  
  /// 获取可靠消息工厂
  /// 返回：ReliableMessageFactory 实例（未设置返回null）
  ReliableMessageFactory? getReliableMessageFactory();

  /// 解析对象为 ReliableMessage 实例
  /// [msg] - 待解析对象（Map/JSON字符串）
  /// 返回：ReliableMessage 实例（解析失败返回null）
  ReliableMessage? parseReliableMessage(Object? msg);
}

/// 消息工厂管理器（单例）
/// ~~~~~~~~~~~~~~~~~~~~~~
/// 统一管理所有消息相关的助手实例，提供全局访问入口
// protected - 该类仅内部使用，对外隐藏实现
class MessageExtensions {
  // 单例模式：私有构造 + 静态实例
  factory MessageExtensions() => _instance;
  static final MessageExtensions _instance = MessageExtensions._internal();
  MessageExtensions._internal();

  // 内容助手（管理Content工厂）
  ContentHelper? contentHelper;
  // 信封助手（管理Envelope工厂）
  EnvelopeHelper? envelopeHelper;

  // 即时消息助手（管理InstantMessage工厂）
  InstantMessageHelper? instantHelper;
  // 安全消息助手（管理SecureMessage工厂）
  SecureMessageHelper? secureHelper;
  // 可靠消息助手（管理ReliableMessage工厂）
  ReliableMessageHelper? reliableHelper;
}