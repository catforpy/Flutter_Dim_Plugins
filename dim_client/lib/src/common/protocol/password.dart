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

import 'package:dim_client/plugins.dart';
import 'package:dim_client/pnf.dart';
import 'package:dim_client/sdk.dart';

/// 密码工具类
/// 用于将文本字符串生成对称密钥（主要是AES密钥）
class Password {

   /// AES密钥长度（32字节）
  static const int _keySize = 32;
  // static const int _blockSize = 16;  // 块大小（注释未启用）

  /// 生成AES对称密钥
  /// [passphrase] 密码字符串
  /// 返回：基于密码生成的AES对称密钥
  static SymmetricKey generate(String passphrase){
    // 1.将密码字符串转换为UTF8字节数组
    Uint8List data = UTF8.encode(passphrase);
    // 2. 计算密码数据的SHA256摘要
    Uint8List digest = SHA256.digest(data);
    // 3. 调整数据长度到32字节（AES秘钥长度）
    int filling = _keySize - data.length;
    if(filling > 0){
      // 长度不足：使用摘要前缀填充+密码数据
      data = Uint8List.fromList(digest.sublist(0,filling) + data);
    }else if(filling < 0){
      // 长度过长：直接使用摘要（优先）或摘要前缀
      // throw Exception('password too long: $passphrase');
      if(_keySize == digest.length){
        data = digest;
      }else{
        // FIXME: what about _keySize > digest.length?
        data = digest.sublist(0, _keySize);
      }
    }

    // 4. 构建AES密钥字典（Base64编码）
    // Uint8List iv = digest.sublist(digest.length - _blockSize); // IV向量（注释未启用）
    Map key = {
      'algorithm' : SymmetricAlgorithms.AES,    // 算法类型：AES
      'data' : Base64.encode(data),             // 秘钥数据（Base64编码）
      //'iv' : Base64.encode(iv),                 // IV向量（注释未启用）
    };
    // 5. 解析为SymmetricKey对象并返回
    return SymmetricKey.parse(key)!;
  }

  //
  //  密钥摘要相关方法
  //

  /// 获取对称密钥的摘要（用于标识密钥）
  /// [password] 对称密钥对象
  /// 返回：6字节摘要的Base64编码（8个字符）
  static String digest(SymmetricKey password){
    Uint8List key = password.data;      // 获取32字节密钥数据
    Uint8List dig = MD5.digest(key);    // 计算MD5摘要（16字节）
    Uint8List pre = dig.sublist(0, 6);  // 取前6字节
    return Base64.encode(pre);          // Base64编码为8个字符
  }

  /// 明文密钥常量定义
  /// ~~~~~~~~~
  /// (no password)
  // ignore: constant_identifier_names
  static const String PLAIN = SymmetricAlgorithms.PLAIN;  // 明文算法标识
  static final SymmetricKey kPlainKey = PlainKey.getInstance();  // 明文密钥单例
}