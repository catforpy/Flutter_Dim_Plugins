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

import 'package:dimp/dkd.dart';
import 'package:dimp/mkm.dart';

/// 引用回复消息接口
/// 作用：定义“引用一条消息并回复”的消息结构，适配IM的“回复”场景
/// 数据格式：{
///      type : i2s(0x37),  // 消息类型标识（0x37=引用回复）
///      sn   : 456,        // 当前消息序列号
///
///      text    : "...",  // 回复的文本内容
///      origin  : {       // 被引用的原始消息信封信息
///          sender    : "...",  // 原始消息发送者ID
///          receiver  : "...",  // 原始消息接收者ID
///
///          type      : 0x01,   // 原始消息内容类型
///          sn        : 123,    // 原始消息序列号
///      }
///  }
abstract interface class QuoteContent implements Content {
  /// 获取回复的文本内容
  String get text;

  /// 获取被引用的原始消息信封
  Envelope? get originalEnvelope;

  //-------- 工厂方法 --------
  /// 创建引用回复消息
  /// @param text - 回复的文本内容
  /// @param head - 原始消息的信封
  /// @param body - 原始消息的内容
  /// @return 引用回复消息实例
  static QuoteContent create(String text, Envelope head, Content body) {
    // 精华原始信封信息（仅保留核心字段）
    Map origin = purify(head);
    // 补充原始消息的类型和序列号
    origin['type'] = body.type;
    origin['sn'] = body.sn;
    // 更新接受者为群组ID（群聊场景）
    ID? group = body.group;
    if (group != null) {
      origin['receiver'] = group.toString();
    }
    return BaseQuoteContent.from(text, origin);
  }

  /// 净化信封信息（仅保留发送者、接收者核心字段）
  /// @param envelope - 原始消息信封
  /// @return 净化后的信封字典
  static Map purify(Envelope envelope) {
    ID from = envelope.sender;
    ID? to = envelope.group;
    to ??= envelope.receiver;
    // 构建精简的原始信息
    Map origin = {'sender': from.toString(), 'receiver': to.toString()};
    return origin;
  }
}
