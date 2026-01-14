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
 * 许可证声明：MIT开源协议
 * 核心功能：封装二进制数据与字符串的互转编码算法（Hex/Base58/Base64）
 * 应用场景：密钥数据传输（二进制转字符串）、哈希值展示、网络传输等
 */

import 'dart:typed_data';

/// 【抽象接口】数据编码器
/// 定义所有二进制<->字符串编码算法的统一接口，实现类需提供具体编码逻辑
abstract interface class DataCoder{
  /// 编码：二进制数据转本地字符串
  /// [data]：原始二进制数据（如密钥、哈希值）
  /// 返回：编码后的字符串（如Base64字符串）
  String encode(Uint8List data);

  /// 解码：字符串转二进制数据
  /// [string]：编码后的字符串
  /// 返回：解码后的二进制数据（失败返回null）
  Uint8List? decode(String string);
}

/// 【Hex编码封装】
/// 用途：二进制数据的十六进制表示（如哈希值展示：0x1234ABCD）
class Hex{
  /// 静态方法: 二进制数据转Hex字符串
  static String encode(Uint8List data){
    return coder!.encode(data);    //委托给已注册的DataCoder实现类
  }

  /// 静态方法：Hex字符串转二进制数据
  static Uint8List? decode(String string) {
    return coder!.decode(string);
  }

  /// Hex编码的具体实现器(由外部插件注入，解耦接口与实现
  static DataCoder? coder;
}

/// 【Base58编码封装】
/// 用途：区块链/去中心化ID常用编码（无特殊字符，易记易传输，如比特币地址）
class Base58 {
  static String encode(Uint8List data) {
    return coder!.encode(data);
  }

  static Uint8List? decode(String string) {
    return coder!.decode(string);
  }

  static DataCoder? coder;
}

/// 【Base64编码封装】
/// 用途：通用网络传输编码（HTTP接口、JSON传输二进制数据的标准方式）
class Base64 {
  static String encode(Uint8List data) {
    return coder!.encode(data);
  }

  static Uint8List? decode(String string) {
    return coder!.decode(string);
  }

  static DataCoder? coder;
}