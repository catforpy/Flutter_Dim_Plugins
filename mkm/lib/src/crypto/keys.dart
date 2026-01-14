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
 * 核心功能：定义所有加密密钥的基础接口，划分加密/解密/签名/验签职责
 * 设计思想：接口分离原则（ISP），将不同加密能力拆分为独立接口
 */

import 'dart:typed_data';

import 'package:mkm/type.dart';

/// 【基础接口】加密密钥
/// 所有密钥的根接口，定义算法名和密钥数据的基础属性
abstract interface class CryptographyKey implements Mapper {
  /// 获取秘钥算法名称(如”AES"/"RSA"/"ECC")
  String get algorithm;

  /// 获取秘钥原始二进制数据
  Uint8List get data;
}

/// 【加密秘钥接口】
/// 定义加密能力（对称秘钥/公钥都实现此接口）
abstract interface class EncryptKey implements CryptographyKey {
  /// 加密原始数据
  /// [plaintext]：待加密的明文数据
  /// [extra]：额外参数（如AES需要的IV向量）
  /// 返回：加密后的密文数据
  Uint8List encrypt(Uint8List plaintext, [Map? extra]);
}

/// 【解密密钥接口】
/// 定义解密能力（对称密钥/私钥都实现此接口）
abstract interface class DecryptKey implements CryptographyKey {
  /// 解密密文数据
  /// [ciphertext]：待解密的密文数据
  /// [params]：额外参数（如AES需要的IV向量）
  /// 返回：解密后的明文数据（解密失败返回null）
  Uint8List? decrypt(Uint8List ciphertext, [Map? params]);

  /// 验证当前解密密钥是否与指定加密密钥匹配
  /// 场景：验证私钥是否对应某个公钥、对称密钥是否匹配
  /// [pKey]：加密密钥（公钥/对称密钥）
  /// 返回：true=匹配，false=不匹配
  bool matchEncryptKey(EncryptKey pKey);
}

/// 【非对称密钥接口】
/// 非对称密钥（公钥/私钥）的基础接口，标记算法类型
abstract interface class AsymmetricKey implements CryptographyKey {
  // 预定义算法常量（注释中给出示例，实际由实现类定义）
  // static const String RSA = 'RSA';  //-- "RSA/ECB/PKCS1Padding", "SHA256withRSA"
  // static const String ECC = 'ECC';
}

/// 【签名密钥接口】
/// 定义签名能力（仅私钥实现此接口）
abstract interface class SignKey implements AsymmetricKey {
  /// 对数据进行签名
  /// [data]：待签名的原始数据
  /// 返回：签名数据
  Uint8List sign(Uint8List data);
}

/// 【验签密钥接口】
/// 定义验签能力（仅公钥实现此接口）
abstract interface class VerifyKey implements AsymmetricKey {
  /// 验证数据签名的合法性
  /// [data]：原始数据
  /// [signature]：待验证的签名
  /// 返回：true=签名有效，false=签名无效
  bool verify(Uint8List data, Uint8List signature);

  /// 验证当前验签密钥是否与指定签名密钥匹配
  /// 场景：验证公钥是否对应某个私钥
  /// [sKey]：签名密钥（私钥）
  /// 返回：true=匹配，false=不匹配
  bool matchSignKey(SignKey sKey);
}
