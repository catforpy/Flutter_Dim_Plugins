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

/* 
 * 核心功能：封装字符串与二进制数据的互转（字符集编码）
 * 应用场景：文本消息传输（字符串转UTF-8二进制）、密钥注释存储等
 */

import 'dart:typed_data';

/// 【抽象接口】字符串编码器
/// 定义字符串<->二进制数据的字符集编码接口
abstract interface class StringCoder {
  /// 编码：字符串转二进制数据(如UTF-8编码)
  Uint8List encode(String string);

  /// 解码：二进制数据转字符串（如UTF-8解码）
  String? decode(Uint8List data);
}

/// 【UTF-8编码封装】
/// 通用字符集编码（网络传输、文本存储的标准编码）
class UTF8 {
  /// 静态方法：字符串转UTF-8二进制数据
  static Uint8List encode(String string){
    return coder!.encode(string);
  }

  /// 静态方法：UTF-8二进制数据转字符串
  static String? decode(Uint8List utf8) {
    return coder!.decode(utf8);
  }

  static StringCoder? coder;
}

