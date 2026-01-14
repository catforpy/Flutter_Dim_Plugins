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
import 'package:mkm/type.dart';

/// 消息信封接口
/// ~~~~~~~~~~~~~~~~~~~~
/// 定义消息的基础路由信息（发送方、接收方、时间），用于创建/解析消息信封
///
/// 数据格式(JSON)：
/// {
///     sender   : "moki@xxx",  // 发送方ID
///     receiver : "hulk@yyy",  // 接收方ID
///     time     : 123          // 消息创建时间戳
/// }
abstract interface class Envelope implements Mapper{
  /// 【只读】消息发送方ID
  ID get sender;

  /// 【只读】消息接收方ID
  ID get receiver;

  /// 【只读】消息创建时间
  DateTime? get time;

  /// 群组ID（扩展字段）
  /// ~~~~~~~~
  /// 当群消息被拆分为单条消息时，'receiver' 会改为群成员ID，
  /// 原群组ID会保存到该字段
  ID? get group;
  set group(ID? identifier);

  /// 消息类型（扩展字段）
  /// ~~~~~~~~~~~~
  /// 由于消息内容会被加密，中间节点（如服务器）无法识别内容类型，
  /// 因此将内容类型提取到信封中，方便中间节点处理（如路由、过滤）
  String? get type;
  set type(String? msgType);

  //
  //  工厂方法
  //

  /// 创建消息信封
  /// [sender] - 发送方ID
  /// [receiver] - 接收方ID
  /// [time] - 消息时间（不传则默认当前时间）
  /// 返回：Envelope 实例
  static Envelope create({required ID sender, required ID receiver, DateTime? time}) {
    var ext = MessageExtensions();
    return ext.envelopeHelper!.createEnvelope(sender: sender, receiver: receiver, time: time);
  }

  /// 解析对象为 Envelope 实例
  /// [env] - 待解析对象（Map/JSON字符串）
  /// 返回：Envelope 实例（解析失败返回null）
  static Envelope? parse(Object? env) {
    var ext = MessageExtensions();
    return ext.envelopeHelper!.parseEnvelope(env);
  }

  /// 获取信封工厂实例
  /// 返回：EnvelopeFactory 实例（未设置返回null）
  static EnvelopeFactory? getFactory() {
    var ext = MessageExtensions();
    return ext.envelopeHelper!.getEnvelopeFactory();
  }
  
  /// 设置信封工厂实例
  /// [factory] - 信封工厂实例
  static void setFactory(EnvelopeFactory factory) {
    var ext = MessageExtensions();
    ext.envelopeHelper!.setEnvelopeFactory(factory);
  }
}

/// 信封工厂接口
/// ~~~~~~~~~~~~~~~~
/// 定义消息信封的创建/解析规则
abstract interface class EnvelopeFactory {

  /// 创建消息信封
  /// [sender] - 发送方ID
  /// [receiver] - 接收方ID
  /// [time] - 消息时间（不传则默认当前时间）
  /// 返回：Envelope 实例
  Envelope createEnvelope({required ID sender, required ID receiver, DateTime? time});

  /// 将Map对象解析为 Envelope 实例
  /// [env] - 信封信息（Map/JSON）
  /// 返回：Envelope 实例（解析失败返回null）
  Envelope? parseEnvelope(Map env);
}

/*
 *  消息转换流程
 *  ~~~~~~~~~~~~~~~~~~~~
 *
 *     即时消息 <-> 安全消息 <-> 可靠消息
 *     Instant Message <-> Secure Message <-> Reliable Message
 *     +-------------+     +------------+     +--------------+
 *     |  sender     |     |  sender    |     |  sender      |
 *     |  receiver   |     |  receiver  |     |  receiver    |
 *     |  time       |     |  time      |     |  time        |
 *     |             |     |            |     |              |
 *     |  content    |     |  data      |     |  data        |
 *     +-------------+     |  key/keys  |     |  key/keys    |
 *                         +------------+     |  signature   |
 *                                            +--------------+
 *     加密算法说明：
 *         data      = 对称密钥.encrypt(内容)          // 加密消息内容
 *         key       = 接收方公钥.encrypt(对称密钥)     // 加密对称密钥
 *         signature = 发送方私钥.sign(data)           // 签名加密后的内容
 */

/// 带信封的消息基接口
/// ~~~~~~~~~~~~~~~~~~~~~
/// 所有消息的基接口，定义信封相关的通用属性
/// 数据格式(JSON)：
/// {
///     //-- 信封字段
///     sender   : "moki@xxx",
///     receiver : "hulk@yyy",
///     time     : 123,
///     //-- 消息体字段（不同类型消息扩展）
///     ...
/// }
abstract interface class Message implements Mapper {

  /// 【只读】消息信封（包含路由信息）
  Envelope get envelope;

  /// 快捷获取：信封中的发送方ID
  ID get sender;       // envelope.sender
  
  /// 快捷获取：信封中的接收方ID
  ID get receiver;     // envelope.receiver
  
  /// 快捷获取：消息时间（优先取内容的time，无则取信封的time）
  DateTime? get time;  // content.time or envelope.time

  /// 快捷获取：群组ID（优先取内容的group，无则取信封的group）
  ID? get group;       // content.group or envelope.group
  
  /// 快捷获取：消息类型（优先取内容的type，无则取信封的type）
  String? get type;    // content.type or envelope.type
}