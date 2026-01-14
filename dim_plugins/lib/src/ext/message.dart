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

import 'package:dim_plugins/dim_plugins.dart';

/// 消息通用工厂
/// 核心作用：
/// 1. 实现DIMP协议中所有消息相关接口，一站式管理「内容/信封/各层级消息」的创建/解析；
/// 2. 维护不同类型的内容工厂映射（如文本/命令/文件）；
/// 3. 管理各层级消息工厂实例，标准化消息生命周期；
/// 接口说明：
/// - GeneralMessageHelper：通用消息辅助（提取内容类型）；
/// - ContentHelper/EnvelopeHelper：内容/信封的创建/解析；
/// - InstantMessageHelper：明文消息的创建/解析；
/// - SecureMessageHelper：加密消息的创建/解析；
/// - ReliableMessageHelper：可靠消息的创建/解析；
class MessageGeneralFactory implements GeneralMessageHelper,
                                       ContentHelper, EnvelopeHelper,
                                       InstantMessageHelper, SecureMessageHelper, ReliableMessageHelper {

  /// 内容工厂映射：key=内容类型（如text/command/file），value=对应工厂
  final Map<String, ContentFactory> _contentFactories = {};

  /// 信封工厂实例（全局唯一）
  EnvelopeFactory?        _envelopeFactory;
  /// 明文消息工厂实例（全局唯一）
  InstantMessageFactory?  _instantMessageFactory;
  /// 加密消息工厂实例（全局唯一）
  SecureMessageFactory?   _secureMessageFactory;
  /// 可靠消息工厂实例（全局唯一）
  ReliableMessageFactory? _reliableMessageFactory;

  /// 提取内容类型（从Map中）
  /// 补充说明：
  /// - 消息内容的type字段标识其类型（如text/command/file）；
  /// - 若字段不存在，返回默认值；
  /// [content] - 内容原始Map
  /// [defaultValue] - 字段不存在时的默认值
  /// 返回值：内容类型字符串
  @override
  String? getContentType(Map content, [String? defaultValue]) {
    return Converter.getString(content['type'], defaultValue);
  }

  // ====================== Content 内容相关方法 ======================

  /// 设置内容工厂（按类型映射）
  /// [msgType] - 内容类型（如text/command）
  /// [factory] - 对应类型的Content工厂
  @override
  void setContentFactory(String msgType, ContentFactory factory) {
    _contentFactories[msgType] = factory;
  }

  /// 获取内容工厂（按类型）
  /// [msgType] - 内容类型
  /// 返回值：对应Content工厂（未找到返回null）
  @override
  ContentFactory? getContentFactory(String msgType) {
    return _contentFactories[msgType];
  }

  /// 解析内容（支持多类型输入）
  /// 补充说明：
  /// 1. 先提取内容类型，再用对应工厂解析；
  /// 2. 未知类型时使用默认工厂（key='*'）；
  /// 3. 全程做类型校验，确保输入合法性；
  /// [content] - 待解析的内容（任意类型）
  /// 返回值：Content实例（失败返回null）
  @override
  Content? parseContent(Object? content) {
    if (content == null) {
      return null;
    } else if (content is Content) {
      return content;
    }
    Map? info = Wrapper.getMap(content);
    if (info == null) {
      assert(false, 'content error: $content');
      return null;
    }
    // 提取内容类型
    String? type = getContentType(info);
    assert(type != null, 'content error: $content');
    // 获取对应工厂
    ContentFactory? factory = type == null ? null : getContentFactory(type);
    if (factory == null) {
      // 未知类型，使用默认工厂
      factory = getContentFactory('*');  // unknown
      assert(factory != null, 'default content factory not found');
    }
    return factory?.parseContent(info);
  }

  // ====================== Envelope 信封相关方法 ======================

  /// 设置信封工厂实例
  @override
  void setEnvelopeFactory(EnvelopeFactory factory) {
    _envelopeFactory = factory;
  }

  /// 获取信封工厂实例
  @override
  EnvelopeFactory? getEnvelopeFactory() {
    return _envelopeFactory;
  }

  /// 创建信封（手动指定收发方+时间）
  /// 补充说明：
  /// - 信封是消息的头部，包含发送方、接收方、时间戳；
  /// - 是所有消息的基础载体；
  /// [sender] - 发送方ID（必填）
  /// [receiver] - 接收方ID（必填）
  /// [time] - 时间戳（可选）
  /// 返回值：创建的Envelope实例
  @override
  Envelope createEnvelope({required ID sender, required ID receiver, DateTime? time}) {
    EnvelopeFactory? factory = getEnvelopeFactory();
    assert(factory != null, 'envelope factory not ready');
    return factory!.createEnvelope(sender: sender, receiver: receiver, time: time);
  }

  /// 解析信封（支持多类型输入）
  /// 补充说明：
  /// - 逻辑与其他解析方法一致，优先类型校验，再用工厂解析；
  /// [env] - 待解析的信封（任意类型）
  /// 返回值：Envelope实例（失败返回null）
  @override
  Envelope? parseEnvelope(Object? env) {
    if (env == null) {
      return null;
    } else if (env is Envelope) {
      return env;
    }
    Map? info = Wrapper.getMap(env);
    if (info == null) {
      assert(false, 'envelope error: $env');
      return null;
    }
    EnvelopeFactory? factory = getEnvelopeFactory();
    assert(factory != null, 'envelope factory not ready');
    return factory?.parseEnvelope(info);
  }

  // ====================== InstantMessage 明文消息相关方法 ======================

  /// 设置明文消息工厂实例
  @override
  void setInstantMessageFactory(InstantMessageFactory factory) {
    _instantMessageFactory = factory;
  }

  /// 获取明文消息工厂实例
  @override
  InstantMessageFactory? getInstantMessageFactory() {
    return _instantMessageFactory;
  }

  /// 创建明文消息（信封+内容）
  /// 补充说明：
  /// - 明文消息是消息的原始形态，未加密、未签名；
  /// - 由信封（头）+ 内容（体）组成；
  /// [head] - 消息信封
  /// [body] - 消息内容
  /// 返回值：创建的InstantMessage实例
  @override
  InstantMessage createInstantMessage(Envelope head, Content body) {
    InstantMessageFactory? factory = getInstantMessageFactory();
    assert(factory != null, 'instant message factory not ready');
    return factory!.createInstantMessage(head, body);
  }

  /// 解析明文消息（支持多类型输入）
  /// 补充说明：
  /// - 逻辑与信封解析一致，使用明文消息工厂解析；
  /// [msg] - 待解析的明文消息（任意类型）
  /// 返回值：InstantMessage实例（失败返回null）
  @override
  InstantMessage? parseInstantMessage(Object? msg) {
    if (msg == null) {
      return null;
    } else if (msg is InstantMessage) {
      return msg;
    }
    Map? info = Wrapper.getMap(msg);
    if (info == null) {
      assert(false, 'instant message error: $msg');
      return null;
    }
    InstantMessageFactory? factory = getInstantMessageFactory();
    assert(factory != null, 'instant message factory not ready');
    return factory?.parseInstantMessage(info);
  }

  /// 生成消息序列号（SN）
  /// 补充说明：
  /// - 委托给明文消息工厂生成，保证全局唯一；
  /// - SN用于标识消息，避免重复；
  /// [msgType] - 消息类型（未使用，预留）
  /// [now] - 当前时间（未使用，预留）
  /// 返回值：唯一的序列号
  @override
  int generateSerialNumber(String? msgType, DateTime? now) {
    InstantMessageFactory? factory = getInstantMessageFactory();
    assert(factory != null, 'instant message factory not ready');
    return factory!.generateSerialNumber(msgType, now);
  }

  // ====================== SecureMessage 加密消息相关方法 ======================

  /// 设置加密消息工厂实例
  @override
  void setSecureMessageFactory(SecureMessageFactory factory) {
    _secureMessageFactory = factory;
  }

  /// 获取加密消息工厂实例
  @override
  SecureMessageFactory? getSecureMessageFactory() {
    return _secureMessageFactory;
  }

  /// 解析加密消息（支持多类型输入）
  /// 补充说明：
  /// - 加密消息包含data字段（加密后的内容），可选signature字段；
  /// - 解析逻辑与明文消息一致，使用加密消息工厂；
  /// [msg] - 待解析的加密消息（任意类型）
  /// 返回值：SecureMessage实例（失败返回null）
  @override
  SecureMessage? parseSecureMessage(Object? msg) {
    if (msg == null) {
      return null;
    } else if (msg is SecureMessage) {
      return msg;
    }
    Map? info = Wrapper.getMap(msg);
    if (info == null) {
      assert(false, 'secure message error: $msg');
      return null;
    }
    SecureMessageFactory? factory = getSecureMessageFactory();
    assert(factory != null, 'secure message factory not ready');
    return factory?.parseSecureMessage(info);
  }

  // ====================== ReliableMessage 可靠消息相关方法 ======================

  /// 设置可靠消息工厂实例
  @override
  void setReliableMessageFactory(ReliableMessageFactory factory) {
    _reliableMessageFactory = factory;
  }

  /// 获取可靠消息工厂实例
  @override
  ReliableMessageFactory? getReliableMessageFactory() {
    return _reliableMessageFactory;
  }

  /// 解析可靠消息（支持多类型输入）
  /// 补充说明：
  /// - 可靠消息包含data+signature字段，是最终传输形态；
  /// - 解析逻辑与加密消息一致，使用可靠消息工厂；
  /// [msg] - 待解析的可靠消息（任意类型）
  /// 返回值：ReliableMessage实例（失败返回null）
  @override
  ReliableMessage? parseReliableMessage(Object? msg) {
    if (msg == null) {
      return null;
    } else if (msg is ReliableMessage) {
      return msg;
    }
    Map? info = Wrapper.getMap(msg);
    if (info == null) {
      assert(false, 'reliable message error: $msg');
      return null;
    }
    ReliableMessageFactory? factory = getReliableMessageFactory();
    assert(factory != null, 'reliable message factory not ready');
    return factory?.parseReliableMessage(info);
  }

}