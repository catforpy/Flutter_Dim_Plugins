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

import 'package:dim_client/sdk.dart';
import 'package:dim_client/src/common/compat/compatible.dart';

/// 兼容型消息压缩器
/// 继承MessageCompressor，在解压缩内容时添加兼容处理
class CompatibleCompressor extends MessageCompressor {
  
  /// 构造方法：使用CompatibleShortener作为短化器
  CompatibleCompressor() : super(CompatibleShortener());

  /// 解压缩消息内容（重写）
  /// @param data - 压缩后的二进制数据
  /// @param key - 解密密钥字典
  /// @return 解压缩后的内容字典（已做兼容修复）
  @override
  Map? extractContent(Uint8List data,Map key){
    // 反序列化还原消息内容
    Map? content = super.extractContent(data, key);
    if(content != null){
      // 解压缩后修复入站内容的兼容字段
      CompatibleIncoming.fixContent(content);
    }
  }
}

/// 兼容性消息短化器
/// 继承MessageShortener,暂不执行实际的短化操作
class CompatibleShortener extends MessageShortener{
  /// 移动字典中的键（从from到to）
  /// @param from - 原键名
  /// @param to - 目标键名
  /// @param info - 待处理字典
  @override  // protected
  void moveKey(String from,String to,Map info){
    var value = info[from];
    if(value != null){
      if(info[to] != null){
        assert(false, 'keys conflicted: "$from" -> "$to", $info');
        return;
      }
      info.remove(from);
      info[to] = value;
    }
  }

  /// 压缩内容字典（暂不压缩，直接返回原字典）
  /// @param content - 内容字典
  /// @return 原内容字典
  @override
  Map compressContent(Map content) {
    // DON'T COMPRESS NOW
    return content;
  }

  /// 压缩对称密钥字典（暂不压缩，直接返回原字典）
  /// @param key - 对称密钥字典
  /// @return 原密钥字典
  @override
  Map compressSymmetricKey(Map key) {
    // DON'T COMPRESS NOW
    return key;
  }

  /// 压缩可靠消息字典（暂不压缩，直接返回原字典）
  /// @param msg - 可靠消息字典
  /// @return 原消息字典
  @override
  Map compressReliableMessage(Map msg) {
    // DON'T COMPRESS NOW
    return msg;
  }
}