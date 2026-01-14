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

import 'dart:math';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart' as pc;

import 'package:dimp/crypto.dart' as dim;

/// ECC（secp256k1）密钥工具类（核心工具，被ECCPublicKey/ECCPrivateKey调用）
class ECCKeyUtils {

  // 验签：用公钥验证数据签名
  static bool verify(Uint8List data, Uint8List signature, ECPublicKey publicKey) {
    // 1. 封装公钥参数
    var params = pc.PublicKeyParameter(publicKey);
    // 2. 初始化SHA256+ECDSA验签器
    var signer = pc.Signer('SHA-256/ECDSA')..init(false, params);
    // 3. 解析ASN.1格式的签名（r/s值）
    var elements = ASN1Sequence.fromBytes(signature).elements!;
    BigInt? r = (elements[0] as ASN1Integer).integer;
    BigInt? s = (elements[1] as ASN1Integer).integer;
    // 4. 验证签名
    return signer.verifySignature(data, pc.ECSignature(r!, s!));
  }

  // 签名：用私钥对数据签名
  static Uint8List sign(Uint8List data, ECPrivateKey privateKey) {
    // 1. 封装私钥参数（带随机数）
    var params = pc.PrivateKeyParameter(privateKey);
    var paramsWithRandom = pc.ParametersWithRandom(params, getSecureRandom());
    // 2. 初始化SHA256+ECDSA签名器
    var signer = pc.Signer('SHA-256/ECDSA')..init(true, paramsWithRandom);
    // 3. 生成签名（r/s值）
    var signature = signer.generateSignature(data) as pc.ECSignature;
    // 4. 编码为ASN.1格式（通用签名格式）
    return ASN1Sequence(elements: [
      ASN1Integer(signature.r),
      ASN1Integer(signature.s),
    ]).encode();
  }

  // 生成安全随机数（密钥生成/签名用，避免伪随机）
  static pc.SecureRandom getSecureRandom({String name = 'Fortuna', int length = 32}) {
    var random = Random.secure(); // 安全随机数生成器（系统级）
    // 生成32字节随机种子
    List<int> seeds = List<int>.generate(32, (_) => random.nextInt(256));
    // 初始化Fortuna随机数生成器
    var secureRandom = pc.SecureRandom(name);
    secureRandom.seed(pc.KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  /// 【ECC私钥生成核心方法】生成secp256k1曲线的ECC私钥
  static ECPrivateKey generatePrivateKey({String curve = 'secp256k1'}) {
    // 1. 指定secp256k1曲线参数
    var domainParams = pc.ECDomainParameters("secp256k1");
    var params = pc.ECKeyGeneratorParameters(domainParams);
    // 2. 带安全随机数的参数（防止私钥被预测）
    var paramsWithRandom = pc.ParametersWithRandom(params, getSecureRandom());
    // 3. 初始化ECC密钥生成器
    var generator = pc.ECKeyGenerator()..init(paramsWithRandom);
    // 4. 生成密钥对并返回私钥
    var keypair = generator.generateKeyPair();
    return keypair.privateKey as ECPrivateKey;
  }

  /// 从私钥推导公钥（ECC核心特性：私钥→公钥是单向的）
  static ECPublicKey publicKeyFromPrivateKey(ECPrivateKey privateKey) {
    pc.ECDomainParameters params = privateKey.parameters!;
    // 椭圆曲线计算：公钥 = 基点G * 私钥d
    return ECPublicKey(params.G * privateKey.d, params);
  }

  // ------------------------------ PEM编解码 ------------------------------
  /// 从PEM字符串解码ECC公钥
  static ECPublicKey decodePublicKey(String pem) {
    // 兼容十六进制格式的公钥（130/66字节）
    if (pem.length == 130 || pem.length == 66) {
      var data = dim.Hex.decode(pem); // 十六进制转字节
      var domainParams = pc.ECDomainParameters("secp256k1");
      var Q = domainParams.curve.decodePoint(data!); // 解析椭圆曲线点
      return ECPublicKey(Q, domainParams);
    }
    // 标准PEM格式解析
    return CryptoUtils.ecPublicKeyFromPem(pem);
  }

  /// 从PEM字符串解码ECC私钥
  static ECPrivateKey decodePrivateKey(String pem) {
    // 兼容64字节十六进制私钥
    if (pem.length == 64) {
      var d = BigInt.parse(pem, radix: 16); // 十六进制转大数
      var domainParams = pc.ECDomainParameters("secp256k1");
      return ECPrivateKey(d, domainParams);
    }
    // 标准PEM格式解析
    return CryptoUtils.ecPrivateKeyFromPem(pem);
  }

  /// 公钥/私钥编码为PEM格式（存储/传输用）
  static String encodeKey({ECPublicKey? publicKey, ECPrivateKey? privateKey}) {
    if (publicKey != null) {
      return CryptoUtils.encodeEcPublicKeyToPem(publicKey);
    }
    if (privateKey != null) {
      return CryptoUtils.encodeEcPrivateKeyToPem(privateKey);
    }
    throw Exception('参数错误：必须传入公钥或私钥');
  }

  /// 编码ECC私钥为字节数据（十六进制）
  static Uint8List encodePrivateKeyData(ECPrivateKey privateKey) {
    String hex = privateKey.d!.toRadixString(16); // 私钥d转十六进制
    return dim.Hex.decode(hex)!; // 转字节
  }

  /// 编码ECC公钥为字节数据（支持压缩/非压缩格式）
  static Uint8List encodePublicKeyData(ECPublicKey publicKey, {bool compressed = true}) {
    // 椭圆曲线点编码（压缩格式：33字节，非压缩：65字节）
    return publicKey.Q!.getEncoded(compressed);
  }
}

/* 
 * 【ECC工具类核心总结】
 * 1. 密钥生成核心：generatePrivateKey()方法 → 生成secp256k1私钥
 * 2. 随机数来源：getSecureRandom() → Random.secure()（系统安全随机数）
 * 3. 核心依赖：pointycastle的ECC实现 + basic_utils的PEM解析
 * 4. 关键能力：私钥生成→公钥推导→PEM编解码→签名验签
 */