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
 * 核心功能：RSA密钥生成/加解密/签名验签/编解码工具类
 * 密钥生成逻辑：generatePrivateKey()生成1024位RSA私钥
 */
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/asn1.dart' show ASN1Integer, ASN1Sequence;
import 'package:pointycastle/export.dart' show RSAPrivateKey, RSAPublicKey;
import 'package:pointycastle/export.dart' as pc;

import 'package:dimp/crypto.dart' as dim;

/// RSA密钥工具类
class RSAKeyUtils {

  // 加密：用公钥加密数据
  static Uint8List encrypt(Uint8List plaintext, RSAPublicKey publicKey) {
    Encrypter cipher = Encrypter(RSA(publicKey: publicKey));
    return cipher.encryptBytes(plaintext).bytes;
  }

  // 验签：用公钥验证签名
  static bool verify(Uint8List data, Uint8List signature, RSAPublicKey publicKey) {
    Signer signer = Signer((RSASigner(RSASignDigest.SHA256, publicKey: publicKey)));
    return signer.verifyBytes(data, Encrypted(signature));
  }

  // 解密：用私钥解密数据
  static Uint8List decrypt(Uint8List ciphertext, RSAPrivateKey privateKey) {
    Encrypter cipher = Encrypter(RSA(privateKey: privateKey));
    List<int> result = cipher.decryptBytes(Encrypted(ciphertext));
    return Uint8List.fromList(result);
  }

  // 签名：用私钥签名数据
  static Uint8List sign(Uint8List data, RSAPrivateKey privateKey) {
    Signer signer = Signer((RSASigner(RSASignDigest.SHA256, privateKey: privateKey)));
    return signer.signBytes(data).bytes;
  }

  // 生成安全随机数（密钥生成/签名用）
  static pc.SecureRandom getSecureRandom({String name = 'Fortuna', int length = 32}) {
    var random = Random.secure(); // 系统安全随机数
    List<int> seeds = List<int>.generate(32, (_) => random.nextInt(256)); // 32字节种子
    var secureRandom = pc.SecureRandom(name);
    secureRandom.seed(pc.KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  /// 【RSA私钥生成核心方法】生成1024位RSA私钥（默认）
  static RSAPrivateKey generatePrivateKey({int bitLength = 1024}) {
    // 1. RSA密钥生成参数（公钥指数65537，密钥长度1024位）
    var params = pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), bitLength, 64);
    // 2. 带安全随机数的参数
    var paramsWithRandom = pc.ParametersWithRandom(params, getSecureRandom());
    // 3. 初始化RSA密钥生成器
    var generator = pc.RSAKeyGenerator()..init(paramsWithRandom);
    // 4. 生成密钥对并返回私钥
    var keyPair = generator.generateKeyPair();
    return keyPair.privateKey as RSAPrivateKey;
  }

  /// 从私钥推导公钥（RSA核心特性：私钥包含公钥参数n/e）
  static RSAPublicKey publicKeyFromPrivateKey(RSAPrivateKey privateKey) {
    BigInt n = privateKey.modulus!; // 模数n
    BigInt e = privateKey.publicExponent!; // 公钥指数e
    return RSAPublicKey(n, e);
  }

  // ------------------------------ PEM编解码 ------------------------------
  /// 从PEM解码RSA公钥
  static RSAPublicKey decodePublicKey(String pem) {
    RSAKeyParser parser = RSAKeyParser();
    return parser.parse(pem) as RSAPublicKey;
  }

  /// 从PEM解码RSA私钥（兼容两种PEM格式）
  static RSAPrivateKey decodePrivateKey(String pem) {
    RSAKeyParser parser = RSAKeyParser();
    // 格式1：BEGIN RSA PRIVATE KEY
    String beginTag = _rsaPriBeginTag1;
    String endTag = _rsaPriEndTag1;
    int start = pem.indexOf(beginTag);
    // 兼容格式2：BEGIN PRIVATE KEY（PKCS8）
    if (start < 0) {
      beginTag = _rsaPriBeginTag8;
      endTag = _rsaPriEndTag8;
      start = pem.indexOf(beginTag);
    }
    // 校验格式
    if (start < 0) {
      assert(false, 'RSA私钥格式错误: $pem');
    } else {
      // 截取完整的PEM块
      int end = pem.indexOf(endTag, start + beginTag.length);
      if (end < 0) {
        assert(false, 'RSA私钥PEM不完整: $pem');
      } else {
        pem = pem.substring(start, end + endTag.length);
      }
    }
    return parser.parse(pem) as RSAPrivateKey;
  }

  // RSA私钥PEM格式常量
  static const String _rsaPriBeginTag1 = '-----BEGIN RSA PRIVATE KEY-----';
  static const String _rsaPriEndTag1   =   '-----END RSA PRIVATE KEY-----';
  static const String _rsaPriBeginTag8 =     '-----BEGIN PRIVATE KEY-----';
  static const String _rsaPriEndTag8   =       '-----END PRIVATE KEY-----';

  /// 编码RSA公钥/私钥为PEM格式
  static String encodeKey({RSAPublicKey? publicKey, RSAPrivateKey? privateKey}) {
    String pem = '';
    Uint8List data;
    String b64;
    // 编码公钥
    if (publicKey != null) {
      data = encodePublicKeyData(publicKey);
      b64 = dim.Base64.encode(data);
      pem += '-----BEGIN RSA PUBLIC KEY-----\r\n$b64\r\n-----END RSA PUBLIC KEY-----';
    }
    // 编码私钥
    if (privateKey != null) {
      if (pem.isNotEmpty) {
        pem += '\r\n';
      }
      data = encodePrivateKeyData(privateKey);
      b64 = dim.Base64.encode(data);
      pem += '-----BEGIN RSA PRIVATE KEY-----\r\n$b64\r\n-----END RSA PRIVATE KEY-----';
    }
    return pem;
  }

  /// 编码RSA私钥为ASN.1格式字节（PKCS1）
  static Uint8List encodePrivateKeyData(RSAPrivateKey privateKey) {
    // 提取RSA私钥参数
    BigInt n = privateKey.modulus!;
    BigInt e = privateKey.publicExponent!;
    BigInt d = privateKey.privateExponent!;
    BigInt p = privateKey.p!;
    BigInt q = privateKey.q!;

    // 计算衍生参数
    BigInt dP = d % (p - _one);
    BigInt dQ = d % (q - _one);
    BigInt iQ = q.modInverse(p);

    // 构造ASN.1序列（PKCS1格式）
    ASN1Sequence sequence = ASN1Sequence();
    sequence.add(ASN1Integer(_zero));     // 版本
    sequence.add(ASN1Integer(n));         // 模数n
    sequence.add(ASN1Integer(e));         // 公钥指数e
    sequence.add(ASN1Integer(d));         // 私钥指数d
    sequence.add(ASN1Integer(p));         // 素数p
    sequence.add(ASN1Integer(q));         // 素数q
    sequence.add(ASN1Integer(dP));        // d mod (p-1)
    sequence.add(ASN1Integer(dQ));        // d mod (q-1)
    sequence.add(ASN1Integer(iQ));        // q的逆元 mod p

    // 编码为字节
    return sequence.encode();
  }

  /// 编码RSA公钥为ASN.1格式字节
  static Uint8List encodePublicKeyData(RSAPublicKey publicKey) {
    BigInt n = publicKey.modulus!;
    BigInt e = publicKey.publicExponent!;

    // 构造ASN.1序列
    ASN1Sequence sequence = ASN1Sequence();
    sequence.add(ASN1Integer(n));         // 模数n
    sequence.add(ASN1Integer(e));         // 公钥指数e

    return sequence.encode();
  }

  // 常量：0和1的BigInt
  static final BigInt _zero = BigInt.from(0);
  static final BigInt _one = BigInt.from(1);
}

/* 
 * 【RSA工具类核心总结】
 * 1. 密钥生成核心：generatePrivateKey() → 生成1024位RSA私钥（默认）
 * 2. 随机数来源：getSecureRandom() → Random.secure()
 * 3. 核心依赖：encrypt库（RSA加解密） + pointycastle（密钥生成）
 * 4. 兼容两种RSA私钥PEM格式（BEGIN RSA PRIVATE KEY / BEGIN PRIVATE KEY）
 */