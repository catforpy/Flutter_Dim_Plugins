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

import 'dart:typed_data';
// 导入业务层的消息摘要接口
import 'package:mkm/digest.dart';

// 导入PointyCastle加密库（包含MD5Digest实现）
import 'package:pointycastle/export.dart';

/// MD5哈希工具类（静态封装）
/// 核心作用：提供简洁的MD5哈希计算入口，内部复用MD5Digester实例
class MD5{

  /// 计算字节数据的MD5哈希值
  /// [data] - 待计算哈希的原始字节数据
  /// 返回值：16字节的MD5哈希结果
  static Uint8List digest(Uint8List data){
    return digester.digest(data);
  }

  /// MD5摘要器单例（复用实例避免重复创建）
  static MessageDigester digester = MD5Digester();
}

/// MD5摘要器实现类（适配业务层MessageDigester接口）
/// 核心作用：封装PointyCastle的MD5Digest，实现统一的消息摘要接口
class MD5Digester implements MessageDigester {

  /// 计算MD5哈希（接口实现）
  /// [data] - 待计算哈希的原始字节数据
  /// 返回值：16字节的MD5哈希结果
  @override
  Uint8List digest(Uint8List data) {
    // 创建PointyCastle的MD5摘要器实例
    Digest digester = MD5Digest();
    digester.reset(); // 重置摘要器（避免残留数据影响计算）
    return digester.process(data); // 执行MD5哈希计算并返回结果
  }
}