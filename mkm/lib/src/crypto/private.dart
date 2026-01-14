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
 * 核心功能：定义非对称私钥的具体接口和工厂规范
 * 核心能力：签名、解密、关联公钥
 */
import 'package:mkm/mkm.dart';

/// 【非对称加密私钥接口】
/// 继承SignKey（签名）+ AsymmetricKey（非对称），是私钥的核心接口
/// 密钥数据格式：Map {
///     algorithm : "RSA", // "ECC", ...
///     data      : "{BASE64_ENCODE}", // 密钥二进制数据的Base64编码
///     ...
/// }
abstract interface class PrivateKey implements SignKey {
  /// 获取与当前私钥配对的公钥
  /// 核心：非对称加密的私钥必须能导出对应的公钥
  PublicKey get publicKey;
  
  // -------------------------- 工厂方法 --------------------------
  /// 生成指定算法的私钥
  /// [algorithm]：算法名（如"ECC"）
  /// 返回：生成的私钥实例（由注册的工厂类创建）
  static PrivateKey? generate(String algorithm) {
    var ext = CryptoExtensions();   // 获取加密扩展单例
    return ext.privateHelper!.generatePrivateKey(algorithm);
  }

  /// 解析对象为私钥（支持Map/Base64字符串等格式）
  /// [key]：待解析的对象
  /// 返回：解析后的私钥实例
  static PrivateKey? parse(Object? key) {
    var ext = CryptoExtensions();
    return ext.privateHelper!.parsePrivateKey(key);
  }

  /// 获取指定算法的私钥工厂
  static PrivateKeyFactory? getFactory(String algorithm) {
    var ext = CryptoExtensions();
    return ext.privateHelper!.getPrivateKeyFactory(algorithm);
  }
  
  /// 注册指定算法的私钥工厂
  static void setFactory(String algorithm, PrivateKeyFactory factory) {
    var ext = CryptoExtensions();
    ext.privateHelper!.setPrivateKeyFactory(algorithm, factory);
  }
}

/// 【私钥工厂接口】
/// 定义私钥的生成和解析规范，不同算法（RSA/ECC）需实现此接口
abstract interface class PrivateKeyFactory {
  /// 生成私钥（由具体算法实现）
  PrivateKey generatePrivateKey();

  /// 解析Map对象为私钥（处理不同算法的密钥格式）
  /// [key]：包含密钥信息的Map
  PrivateKey? parsePrivateKey(Map key);
}