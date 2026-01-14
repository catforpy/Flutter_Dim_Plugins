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
 * 核心功能：定义非对称公钥的具体接口和工厂规范
 * 核心能力：验签、加密
 */

import 'package:mkm/mkm.dart';

/// 【非对称加密公钥接口】
/// 继承VerifyKey（验签）+ AsymmetricKey（非对称），是公钥的核心接口
/// 密钥数据格式同私钥（Map）
abstract interface class PublicKey implements VerifyKey{
  // -------------------------- 工厂方法 --------------------------
  /// 解析对象为公钥
  static PublicKey? parse(Object? key){
    var ext = CryptoExtensions();
    return ext.publicHelper!.parsePublicKey(key);
  }

  /// 获取指定算法的公钥工厂
  static PublicKeyFactory? getFactory(String algorithm) {
    var ext = CryptoExtensions();
    return ext.publicHelper!.getPublicKeyFactory(algorithm);
  }

  /// 注册指定算法的公钥工厂
  static void setFactory(String algorithm, PublicKeyFactory factory) {
    var ext = CryptoExtensions();
    ext.publicHelper!.setPublicKeyFactory(algorithm, factory);
  }
}

/// 【公钥工厂接口】
/// 定义公钥的解析规范（公钥无需生成，由私钥导出）
abstract interface class PublicKeyFactory {
  /// 解析Map对象为公钥
  PublicKey? parsePublicKey(Map map);
}