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

import 'package:dkd/dkd.dart';

/// 安全消息接口
/// ~~~~~~~~~~~~~~
/// 即时消息经对称加密后的消息（内容加密，密钥加密）
///
/// 数据格式(JSON)：
/// {
///     //-- 信封字段
///     sender   : "moki@xxx",
///     receiver : "hulk@yyy",
///     time     : 123,
///     //-- 核心加密字段
///     data     : "...",  // base64编码的加密内容（对称加密Content）
///     key      : "...",  // base64编码的加密密钥（非对称加密对称密钥）
///     keys     : {
///         "ID1": "key1", // 多接收方时，每个接收方的加密密钥
///     }
/// }
abstract interface class SecureMessage implements Message {
  /// 【只读】加密后的内容数据（base64解码后为对称加密的Content）
  Uint8List get data;

  /// 【只读】单接收方的加密秘钥（base64解码后为非对称加密的对称密钥）
  /// 多接收方时该字段为Null，需从keys中获取
  Uint8List? get encryptedKey;

  /// 【只读】多接收方的加密密钥映射（key: 接收方ID, value: base64编码的加密密钥）
  /// String => String
  Map? get encryptedKeys;

  //
  //  工厂方法
  //

  /// 解析对象为 SecureMessage 实例
  /// [msg] - 待解析对象（Map/JSON字符串）
  /// 返回：SecureMessage 实例（解析失败返回null）
  static SecureMessage? parse(Object? msg) {
    var ext = MessageExtensions();
    return ext.secureHelper!.parseSecureMessage(msg);
  }

  /// 获取安全消息工厂
  /// 返回：SecureMessageFactory 实例（未设置返回null）
  static SecureMessageFactory? getFactory() {
    var ext = MessageExtensions();
    return ext.secureHelper!.getSecureMessageFactory();
  }
  
  /// 设置安全消息工厂
  /// [factory] - 安全消息工厂实例
  static void setFactory(SecureMessageFactory factory) {
    var ext = MessageExtensions();
    ext.secureHelper!.setSecureMessageFactory(factory);
  }
}

/// 安全消息工厂接口
/// ~~~~~~~~~~~~~~~
/// 定义安全消息的解析规则
abstract interface class SecureMessageFactory {

  /// 将Map对象解析为 SecureMessage 实例
  /// [msg] - 消息信息（Map/JSON）
  /// 返回：SecureMessage 实例（解析失败返回null）
  SecureMessage? parseSecureMessage(Map msg);
}