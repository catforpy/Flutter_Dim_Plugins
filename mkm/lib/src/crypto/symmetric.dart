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
 * 核心功能：定义对称密钥的具体接口和工厂规范
 * 核心能力：加密、解密（对称密钥同时具备加密和解密能力）
 */

import 'package:mkm/mkm.dart';

/// 【对称加密密钥接口】
/// 继承EncryptKey（加密）+ DecryptKey（解密），同时具备加密和解密能力
/// 用途：加密/解密消息内容（如AES加密聊天消息）
/// 密钥数据格式同非对称密钥（Map）
abstract interface class SymmetricKey implements EncryptKey, DecryptKey {
  // 预定义算法常量（注释示例）
  // static const AES = 'AES';  //-- "AES/CBC/PKCS7Padding"
  // static const DES = 'DES';

  // -------------------------- 工厂方法 --------------------------
  /// 生成指定算法的对称密钥
  static SymmetricKey? generate(String algorithm) {
    var ext = CryptoExtensions();
    return ext.symmetricHelper!.generateSymmetricKey(algorithm);
  }

  /// 解析对象为对称秘钥
  static SymmetricKey? parse(Object? key){
    var ext = CryptoExtensions();
    return ext.symmetricHelper!.parseSymmetricKey(key);
  }

  /// 获取制定算法的对称秘钥工厂
  static SymmetricKeyFactory? getFactory(String algorithm){
    var ext = CryptoExtensions();
    return ext.symmetricHelper!.getSymmetricKeyFactory(algorithm);
  }

  /// 注册制定算法的对称密钥工厂
  static void setFactory(String algorithm,SymmetricKeyFactory factory){
    var ext = CryptoExtensions();
    return ext.symmetricHelper!.setSymmetricKeyFactory(algorithm, factory);
  }
}

/// 【对称密钥工厂接口】
/// 定义对称密钥的生成和解析规范
abstract interface class SymmetricKeyFactory{
  /// 生成对称密钥(由具体算法实现，如AES生成128/256位秘钥)
  SymmetricKey? generateSymmetricKey();

  /// 解析Map对象为对称密钥
  SymmetricKey? parseSymmetricKey(Map map);
}