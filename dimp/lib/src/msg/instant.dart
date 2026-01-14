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
import 'package:dimp/msg.dart';

///  即时消息（明文）
///  ~~~~~~~~~~~~~~~
///  作用：用户发送前的原始消息，包含明文信封+明文内容，是加密/签名的源数据
///  说明：仅在本地存储/处理，不会直接传输到网络
///
///  数据格式：{
///      //-- 信封（路由信息）
///      sender   : "moki@xxx",
///      receiver : "hulk@yyy",
///      time     : 123,
///      //-- 正文（明文内容）
///      content  : {...}
///  }
class PlainMessage extends BaseMessage implements InstantMessage {
  // 构造方法：从字典初始化（解析本地的明文消息）
  PlainMessage([super.dict]);

  /// 消息正文（缓存）
  Content? _content;

  // 构造方法：从信封+正文创建明文消息
  // @param head - 信封（路由信息）
  // @param body - 正文（明文内容）
  PlainMessage.from(Envelope head, Content body) : super.fromEnvelope(head) {
    content = body;
  }

  // 获取发送时间（优先从内容读取，兼容内容自带时间的场景）
  @override
  DateTime? get time => content.time ?? envelope.time;

  // 获取群组ID（从内容读取，群消息专用）
  @override
  ID? get group => content.group;

  // 获取消息类型（从内容读取，标识正文类型）
  @override
  String get type => content.type;

  // 获取消息正文（懒加载+非空校验）
  @override
  Content get content {
    Content? body = _content;
    if (body == null) {
      var info = this['content'];
      body = Content.parse(info);
      assert(body != null, '消息正文解析失败: $toMap()');
      _content = body;
    }
    return body!;
  }

  // 设置消息正文（序列化存储）
  @override
  set content(Content body) {
    setMap('content', body);
    _content = body;
  }
}