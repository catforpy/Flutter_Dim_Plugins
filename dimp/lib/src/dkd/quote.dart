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

import 'package:dimp/dimp.dart';
import 'package:dimp/dkd.dart';

/// 引用回复内容类
/// 作用：封装带上下文的引用回复消息，支持关联原消息的信封信息
class BaseQuoteContent extends BaseContent implements QuoteContent {
  /// 构造方法1：从字典初始化（解析网络传输的引用回复消息）
  BaseQuoteContent([super.dict]);

  /// 缓存：原消息的信封（避免重复解析）
  Envelope? _env;

  /// 构造方法2：从回复文本+原消息信封初始化（创建引用回复消息）
  /// @param text     - 回复的文本内容
  /// @param origin   - 原消息的信封字典（包含sender/receiver/sn等）
  BaseQuoteContent.from(String text, Map origin)
    : super.fromType(ContentType.QUOTE) {
    //  填充回复文本
    this['text'] = text;
    // 填充原消息信封（上下文关联核心）
    this['origin'] = origin;
  }

  /// 获取回复的文本内容（空字符串表示未设置）
  @override
  String get text => getString('text') ?? '';

  /// 内部方法：获取原消息信封字典（protected）
  Map? get origin {
    var info = this['origin'];
    if (info is Map) {
      return info;
    }
    assert(info == null, '原消息信封解析异常: $info');
    return null;
  }

  /// 获取原消息的信封（核心方法：上下文关联）
  @override
  Envelope? get originalEnvelope {
    // origin字段格式：{ sender: "...", receiver: "...", time: 0, sn: 0 }
    _env ??= Envelope.parse(origin);
    return _env;
  }

  /// 获取原消息的序列号（用于定位原消息）
  @override
  int? get originalSerialNumber => Converter.getInt(origin?['sn']);
}
