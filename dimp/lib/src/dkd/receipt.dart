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

/// 消息回执命令类
/// 作用：封装消息状态回执（已读/已送达/失败），支持关联原消息的关键信息
class BaseReceiptCommand extends BaseCommand implements ReceiptCommand {
  /// 构造方法1：从字典初始化（解析网络传输的回执命令）
  BaseReceiptCommand([super.dict]);

  /// 缓存：原消息的信封（避免重复解析）
  Envelope? _env;

  /// 构造方法2：从回执文本+原消息信封初始化（创建回执命令）
  /// @param text - 回执文本（如"已读"、"消息发送失败"）
  /// @param origin - 原消息的信封字典（包含sn/signature等）
  BaseReceiptCommand.from(String text, Map? origin)
    : super.fromName(Command.RECEIPT) {
    // 填充回执文本
    this['text'] = text;
    // 填充原消息信封（核心：关联原消息）
    if (origin != null) {
      // 严格校验：origin不能包含消息内容相关字段，保证信封纯净
      assert(
        !(origin.isEmpty ||
            origin.containsKey('data') ||
            origin.containsKey('key') ||
            origin.containsKey('keys') ||
            origin.containsKey('meta') ||
            origin.containsKey('visa')),
        '非法信封数据: $origin',
      );
      this['origin'] = origin;
    }
  }

  /// 获取绘制文本内容（空字符串表示未设置）
  @override
  String get text => getString('text') ?? '';

  /// 内部方法：获取原消息信封字典（protected）
  Map? get origin => this['origin'];

  /// 获取原消息的信封（核心方法，关联原消息）
  @override
  Envelope? get originalEnvelope {
    // origin字段格式：{ sender: "...", receiver: "...", time: 0, sn: 0, signature: "..." }
    _env ??= Envelope.parse(origin);
    return _env;
  }

  /// 获取原消息的序列号（用于定位原消息）
  @override
  int? get originalSerialNumber => Converter.getInt(origin?['sn']);

  /// 获取原消息的签名（用于验证原消息的完整性）
  @override
  String? get originalSignature => Converter.getString(origin?['signature']);
}
