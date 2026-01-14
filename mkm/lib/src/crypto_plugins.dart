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

import 'package:mkm/mkm.dart';
import 'package:mkm/type.dart';

/// 加密密钥通用辅助器接口
/// 补充说明：
/// 1. 整合对称密钥(SymmetricKey)、私钥(PrivateKey)、公钥(PublicKey)相关辅助能力；
/// 2. 提供密钥配对验证、算法类型提取等通用方法；
/// 3. 注：注释中被注释的接口实现表示该接口整合了这些辅助器的能力
abstract interface class GeneralCryptoHelper {
  /// 密钥验证用的样本数据
  /// 补充说明：
  /// - 固定字符串转换为字节数组，用于非对称/对称密钥的配对验证；
  /// - 避免每次生成随机数据，保证验证逻辑的一致性；
  // ignore: non_constant_identifier_names
  static final Uint8List PROMISE = Uint8List.fromList(
    'Moky loves May Lee forever!'.codeUnits,
  );

  /// 验证非对称密钥对是否匹配（私钥+公钥）
  /// 补充说明：
  /// 1. 使用私钥(SignKey)对PROMISE数据签名；
  /// 2. 使用公钥(VerifyKey)验证签名；
  /// 3. 验证通过则表示密钥对匹配；
  /// [sKey] - 签名密钥（私钥）
  /// [pKey] - 验证密钥（公钥）
  /// 返回值：true=密钥对匹配，false=不匹配
  static bool matchAsymmetricKeys(SignKey sKey, VerifyKey pKey) {
    // verify with signature - 使用签名验证
    Uint8List signature = sKey.sign(PROMISE);
    return pKey.verify(PROMISE, signature);
  }

  /// 验证对称密钥对是否匹配（加密密钥+解密密钥）
  /// 补充说明：
  /// 1. 使用加密密钥(EncryptKey)加密PROMISE数据；
  /// 2. 使用解密密钥(DecryptKey)解密密文；
  /// 3. 解密结果与PROMISE一致则表示密钥匹配；
  /// [encKey] - 加密密钥
  /// [decKey] - 解密密钥
  /// 返回值：true=密钥匹配，false=不匹配
  static bool matchSymmetricKeys(EncryptKey encKey, DecryptKey decKey) {
    // 通过加密验证
    Map params = {}; // 加密餐厨(如IV,模式等)
    Uint8List ciphertext = encKey.encrypt(PROMISE, params);
    Uint8List? plaintext = decKey.decrypt(ciphertext, params);
    return plaintext != null && Arrays.equals(plaintext, PROMISE);
  }

  //
  //  Algorithm - 算法类型
  //

  /// 从密钥Map中获取算法类型
  /// 补充说明：
  /// - 不同加密算法（如RSA/ECC/AES）的密钥会存储算法类型字段；
  /// - 该方法用于统一提取密钥的算法类型，适配不同格式的密钥结构；
  /// [key] - 密钥Map
  /// [defaultValue] - 字段不存在/解析失败时返回的默认值
  String? getKeyAlgorithm(Map key, [String? defaultValue]);
}

/// 加密扩展管理器（单例）
/// 补充说明：
/// 1. 采用单例模式，统一管理各类加密密钥相关辅助器的实例；
/// 2. 内部通过CryptoExtensions()转发读写操作，实现辅助器的全局共享；
/// 3. 同时维护一个通用加密辅助器(GeneralCryptoHelper)实例，便于统一调用
class SharedCryptoExtensions {
  /// 工厂构造函数（返回单例）
  factory SharedCryptoExtensions() => _instance;

  /// 静态单例实例
  static final SharedCryptoExtensions _instance =
      SharedCryptoExtensions._internal();

  /// 私有构造函数（防止外部实例化）
  SharedCryptoExtensions._internal();

  /// 对称密钥辅助器 - 读写
  /// 补充说明：封装对称密钥（如AES）的创建、解析、验证等能力
  SymmetricKeyHelper? get symmetricHelper => CryptoExtensions().symmetricHelper;

  set symmetricHelper(SymmetricKeyHelper? helper) =>
      CryptoExtensions().symmetricHelper = helper;

  /// 私钥辅助器 - 读写
  /// 补充说明：封装非对称私钥（如RSA私钥、ECC私钥）的创建、解析、验证等能力
  PrivateKeyHelper? get privateHelper => CryptoExtensions().privateHelper;

  set privateHelper(PrivateKeyHelper? helper) =>
      CryptoExtensions().privateHelper = helper;

  /// 公钥辅助器 - 读写
  /// 补充说明：封装非对称公钥（如RSA公钥、ECC公钥）的创建、解析、验证等能力
  PublicKeyHelper? get publicHelper => CryptoExtensions().publicHelper;

  set publicHelper(PublicKeyHelper? helper) =>
      CryptoExtensions().publicHelper = helper;

  /// 通用加密辅助器
  /// 补充说明：全局共享的GeneralCryptoHelper实例，可统一处理各类加密相关通用操作
  GeneralCryptoHelper? helper;
}
