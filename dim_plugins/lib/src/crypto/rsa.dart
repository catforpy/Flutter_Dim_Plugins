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
 * 核心功能：实现DIMP协议的RSA公私钥类（封装rsa_utils的工具方法）
 * 密钥生成逻辑：RSAPrivateKey构造方法自动调用rsa_utils生成私钥
 */
import 'dart:typed_data';

import 'package:dimp/crypto.dart';

import 'rsa_utils.dart';

/// RSA公钥类（继承BasePublicKey，实现EncryptKey加密接口）
/// keyInfo格式：
/// {
///     algorithm : "RSA",      // 算法标识
///     data      : "...",      // Base64编码的PEM公钥
/// }
class RSAPublicKey extends BasePublicKey implements EncryptKey {
  // 构造方法
  RSAPublicKey([super.dict]);

  // 重写：获取公钥原始字节数据
  @override
  Uint8List get data {
    var publicKey = RSAKeyUtils.decodePublicKey(_key());
    return RSAKeyUtils.encodePublicKeyData(publicKey);
  }

  // 获取PEM公钥字符串
  String _key() {
    return getString('data') ?? '';
  }

  // 实现EncryptKey接口：用公钥加密数据
  @override
  Uint8List encrypt(Uint8List plaintext, [Map? extra]) {
    var publicKey = RSAKeyUtils.decodePublicKey(_key());
    return RSAKeyUtils.encrypt(plaintext, publicKey);
  }

  // 重写：验签
  @override
  bool verify(Uint8List data, Uint8List signature) {
    try {
      var publicKey = RSAKeyUtils.decodePublicKey(_key());
      return RSAKeyUtils.verify(data, signature, publicKey);
    } catch (e, st) {
      print('RSA验签失败: $e, $st');
      return false;
    }
  }
}

/// RSA私钥类（继承BasePrivateKey，实现DecryptKey解密接口）
/// keyInfo格式：
/// {
///     algorithm : "RSA",      // 算法标识
///     data      : "...",      // Base64编码的PEM私钥
/// }
class RSAPrivateKey extends BasePrivateKey implements DecryptKey {
  // 构造方法：初始化私钥，缓存公钥
  RSAPrivateKey([super.dict]) : _publicKey = null;

  // 缓存推导后的公钥
  PublicKey? _publicKey;

  // 重写：获取对应的公钥（懒加载）
  @override
  PublicKey get publicKey {
    PublicKey? pubKey = _publicKey;
    if (pubKey == null) {
      // 1. 解析PEM私钥
      var privateKey = RSAKeyUtils.decodePrivateKey(_key());
      // 2. 推导公钥
      var publicKey = RSAKeyUtils.publicKeyFromPrivateKey(privateKey);
      // 3. 编码为PEM
      String pem = RSAKeyUtils.encodeKey(publicKey: publicKey);
      // 4. 构造DIMP公钥对象
      Map info = {
        'algorithm': AsymmetricAlgorithms.RSA,
        'data': pem,
        'mode': 'ECB',
        'padding': 'PKCS1',
        'digest': 'SHA256'
      };
      pubKey = PublicKey.parse(info);
      assert(pubKey != null, 'RSA公钥推导失败: $info');
      // 5. 缓存
      _publicKey = pubKey;
    }
    return pubKey!;
  }

  // 重写：获取私钥原始字节数据
  @override
  Uint8List get data {
    var privateKey = RSAKeyUtils.decodePrivateKey(_key());
    return RSAKeyUtils.encodePrivateKeyData(privateKey);
  }

  // 核心方法：获取/生成RSA私钥PEM
  String _key() {
    // 1. 尝试从dict获取已有的PEM
    String? pem = getString('data');
    if (pem != null) {
      return pem;
    }

    // 2. 无PEM时，【自动生成新私钥】
    var privateKey = RSAKeyUtils.generatePrivateKey(); // 调用工具类生成
    pem = RSAKeyUtils.encodeKey(privateKey: privateKey); // 编码为PEM
    this['data'] = pem; // 存入dict

    return pem;
  }

  // 实现DecryptKey接口：解密数据
  @override
  Uint8List? decrypt(Uint8List ciphertext, [Map? params]) {
    try {
      var privateKey = RSAKeyUtils.decodePrivateKey(_key());
      return RSAKeyUtils.decrypt(ciphertext, privateKey);
    } catch (e, st) {
      print('RSA解密失败: $e, $st');
      return null;
    }
  }

  // 重写：签名数据
  @override
  Uint8List sign(Uint8List data) {
    var privateKey = RSAKeyUtils.decodePrivateKey(_key());
    return RSAKeyUtils.sign(data, privateKey);
  }

  // 校验公钥是否匹配当前私钥
  @override
  bool matchEncryptKey(EncryptKey pKey) {
    return BaseKey.matchEncryptKey(pKey, this);
  }
}

// ------------------------------ RSA密钥工厂类 ------------------------------
/// RSA公钥工厂
class RSAPublicKeyFactory implements PublicKeyFactory {

  @override
  PublicKey? parsePublicKey(Map key) {
    if (key['data'] == null) {
      assert(false, 'RSA公钥数据错误: $key');
      return null;
    }
    return RSAPublicKey(key);
  }
}

/// RSA私钥工厂（生成/解析私钥）
class RSAPrivateKeyFactory implements PrivateKeyFactory {

  // 【工厂方法：生成新RSA私钥】对外暴露的生成入口
  @override
  PrivateKey generatePrivateKey() {
    Map key = {'algorithm': AsymmetricAlgorithms.RSA};
    return RSAPrivateKey(key);
  }

  @override
  PrivateKey? parsePrivateKey(Map key) {
    if (key['data'] == null) {
      assert(false, 'RSA私钥数据错误: $key');
      return null;
    }
    return RSAPrivateKey(key);
  }
}

/* 
 * 【RSA公私钥类核心总结】
 * 1. 私钥生成触发点：
 *    - RSAPrivateKey._key()方法 → 无data字段时调用RSAKeyUtils.generatePrivateKey()
 *    - 工厂方法：RSAPrivateKeyFactory.generatePrivateKey() → 新建RSAPrivateKey → 触发自动生成
 * 2. 公钥生成：从私钥推导（RSAKeyUtils.publicKeyFromPrivateKey）
 * 3. 核心依赖：rsa_utils.dart的工具方法
 * 4. 密钥长度：默认1024位（可通过generatePrivateKey的bitLength参数调整）
 */