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

import 'package:dim_plugins/dim_plugins.dart';

/// ECC公钥类（继承DIMP的BasePublicKey）
/// keyInfo格式：
/// {
///     algorithm    : "ECC",      // 算法标识
///     curve        : "secp256k1",// 曲线类型
///     data         : "...",      // Base64编码的PEM公钥
///     compressed   : 0           // 公钥是否压缩（0=非压缩，1=压缩）
/// }
class ECCPublicKey extends BasePublicKey {
  // 构造方法：从dict初始化
  ECCPublicKey([super.dict]);

  // 重写父类方法：获取公钥原始字节数据
  @override
  Uint8List get data {
    // 1. 解析PEM公钥
    var publicKey = ECCKeyUtils.decodePublicKey(_key());
    // 2. 编码为字节（支持压缩格式）
    return ECCKeyUtils.encodePublicKeyData(publicKey, compressed: compressed);
  }

  // 获取公钥压缩标识（默认false）
  bool get compressed => getBool('compressed') ?? false;

  // 从dict获取data字段（PEM公钥字符串）
  String _key() => getString('data') ?? '';

  // 重写父类方法：验签
  @override
  bool verify(Uint8List data, Uint8List signature) {
    try {
      var publicKey = ECCKeyUtils.decodePublicKey(_key());
      // 调用工具类验签
      return ECCKeyUtils.verify(data, signature, publicKey);
    } catch (e, st) {
      print('ECC验签失败: $e, $st');
      return false;
    }
  }
}

/// ECC私钥类（继承DIMP的BasePrivateKey）
/// keyInfo格式：
/// {
///     algorithm    : "ECC",      // 算法标识
///     curve        : "secp256k1",// 曲线类型
///     data         : "...",      // Base64编码的PEM私钥
/// }
class ECCPrivateKey extends BasePrivateKey {
  // 构造方法：初始化私钥，缓存公钥（懒加载）
  ECCPrivateKey([super.dict]) : _publicKey = null;

  // 缓存推导后的公钥（避免重复计算）
  PublicKey? _publicKey;

  // 重写父类方法：获取对应的公钥（懒加载）
  @override
  PublicKey get publicKey {
    PublicKey? pubKey = _publicKey;
    if (pubKey == null) {
      // 1. 解析PEM私钥
      var privateKey = ECCKeyUtils.decodePrivateKey(_key());
      // 2. 从私钥推导公钥
      var publicKey = ECCKeyUtils.publicKeyFromPrivateKey(privateKey);
      // 3. 编码为公钥PEM
      String pem = ECCKeyUtils.encodeKey(publicKey: publicKey);
      // 4. 构造DIMP公钥对象
      Map info = {
        'algorithm': AsymmetricAlgorithms.ECC,
        'data': pem,
        'curve': 'SECP256k1',
        'digest': 'SHA256'
      };
      pubKey = PublicKey.parse(info);
      assert(pubKey != null, '公钥推导失败: $info');
      // 5. 缓存公钥
      _publicKey = pubKey;
    }
    return pubKey!;
  }

  // 重写父类方法：获取私钥原始字节数据
  @override
  Uint8List get data {
    var privateKey = ECCKeyUtils.decodePrivateKey(_key());
    return ECCKeyUtils.encodePrivateKeyData(privateKey);
  }

  // 核心方法：获取/生成私钥PEM
  String _key() {
    // 1. 尝试从dict获取已有的PEM私钥
    String? pem = getString('data');
    if (pem != null) {
      return pem;
    }

    // 2. 无PEM时，【自动生成新私钥】
    var privateKey = ECCKeyUtils.generatePrivateKey(); // 调用工具类生成
    pem = ECCKeyUtils.encodeKey(privateKey: privateKey); // 编码为PEM
    this['data'] = pem; // 存入dict

    return pem;
  }

  // 重写父类方法：用私钥签名数据
  @override
  Uint8List sign(Uint8List data) {
    var privateKey = ECCKeyUtils.decodePrivateKey(_key());
    return ECCKeyUtils.sign(data, privateKey); // 调用工具类签名
  }
}

// ------------------------------ ECC密钥工厂类 ------------------------------
/// ECC公钥工厂（解析公钥）
class ECCPublicKeyFactory implements PublicKeyFactory {

  @override
  PublicKey? parsePublicKey(Map key) {
    if (key['data'] == null) {
      assert(false, 'ECC公钥数据错误: $key');
      return null;
    }
    return ECCPublicKey(key);
  }
}

/// ECC私钥工厂（生成/解析私钥）
class ECCPrivateKeyFactory implements PrivateKeyFactory {

  // 【工厂方法：生成新ECC私钥】对外暴露的生成入口
  @override
  PrivateKey generatePrivateKey() {
    // 构造空dict（仅指定算法），ECCPrivateKey构造方法会自动生成私钥
    Map key = {'algorithm': AsymmetricAlgorithms.ECC};
    return ECCPrivateKey(key);
  }

  // 解析已有的ECC私钥
  @override
  PrivateKey? parsePrivateKey(Map key) {
    if (key['data'] == null) {
      assert(false, 'ECC私钥数据错误: $key');
      return null;
    }
    return ECCPrivateKey(key);
  }
}

/* 
 * 【ECC公私钥类核心总结】
 * 1. 私钥生成触发点：
 *    - ECCPrivateKey._key()方法 → 无data字段时调用ECCKeyUtils.generatePrivateKey()
 *    - 工厂方法生成：ECCPrivateKeyFactory.generatePrivateKey() → 新建ECCPrivateKey → 触发自动生成
 * 2. 公钥生成：从私钥推导（ECCKeyUtils.publicKeyFromPrivateKey）
 * 3. 核心依赖：ecc_utils.dart的工具方法
 */