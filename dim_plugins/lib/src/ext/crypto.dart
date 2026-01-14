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

import 'package:dim_plugins/dim_plugins.dart';

/// 加密密钥通用工厂
/// 核心作用：
/// 1. 实现所有加密密钥相关接口，一站式管理「对称密钥/私钥/公钥」的创建/解析；
/// 2. 维护不同算法的密钥工厂映射（如AES/RSA/ECC）；
/// 3. 提供算法类型提取、格式校验等通用能力；
/// 接口说明：
/// - GeneralCryptoHelper：通用加密辅助（提取算法类型）；
/// - SymmetricKeyHelper：对称密钥（如AES）的创建/解析；
/// - PrivateKeyHelper/PublicKeyHelper：非对称密钥（如RSA）的创建/解析；
class CryptoKeyGeneralFactory implements GeneralCryptoHelper,
                                         SymmetricKeyHelper,
                                         PrivateKeyHelper, PublicKeyHelper {

  /// 对称密钥工厂映射：key=算法类型（如AES），value=对应工厂
  final Map<String, SymmetricKeyFactory> _symmetricKeyFactories = {};
  /// 私钥工厂映射：key=算法类型（如RSA），value=对应工厂
  final Map<String, PrivateKeyFactory>     _privateKeyFactories = {};
  /// 公钥工厂映射：key=算法类型（如RSA），value=对应工厂
  final Map<String, PublicKeyFactory>       _publicKeyFactories = {};

  /// 提取密钥算法类型（从Map中）
  /// 补充说明：
  /// - 密钥的algorithm字段标识其加密算法（如AES/RSA/ECC）；
  /// - 若字段不存在，返回默认值；
  /// [key] - 密钥原始Map
  /// [defaultValue] - 字段不存在时的默认值
  /// 返回值：算法类型字符串
  @override
  String? getKeyAlgorithm(Map key, [String? defaultValue]) {
    return Converter.getString(key['algorithm'], defaultValue);
  }

  // ====================== SymmetricKey 对称密钥相关方法 ======================

  /// 设置对称密钥工厂（按算法映射）
  /// [algorithm] - 算法类型（如AES）
  /// [factory] - 对应算法的SymmetricKey工厂
  @override
  void setSymmetricKeyFactory(String algorithm, SymmetricKeyFactory factory) {
    _symmetricKeyFactories[algorithm] = factory;
  }

  /// 获取对称密钥工厂（按算法）
  /// [algorithm] - 算法类型
  /// 返回值：对应SymmetricKey工厂（未找到返回null）
  @override
  SymmetricKeyFactory? getSymmetricKeyFactory(String algorithm) {
    return _symmetricKeyFactories[algorithm];
  }

  /// 生成对称密钥（按算法）
  /// 补充说明：
  /// - 不同算法的对称密钥由对应工厂生成（如AES-128/AES-256）；
  /// - 适用于消息加密、文件加密等场景；
  /// [algorithm] - 算法类型
  /// 返回值：生成的SymmetricKey实例
  @override
  SymmetricKey? generateSymmetricKey(String algorithm) {
    SymmetricKeyFactory? factory = getSymmetricKeyFactory(algorithm);
    assert(factory != null, 'key algorithm not support: $algorithm');
    return factory?.generateSymmetricKey();
  }

  /// 解析对称密钥（支持多类型输入）
  /// 补充说明：
  /// 1. 先提取算法类型，再用对应工厂解析；
  /// 2. 未知算法时使用默认工厂（key='*'）；
  /// 3. 全程做类型校验，确保输入合法性；
  /// [key] - 待解析的对称密钥（任意类型）
  /// 返回值：SymmetricKey实例（失败返回null）
  @override
  SymmetricKey? parseSymmetricKey(Object? key) {
    if (key == null) {
      return null;
    } else if (key is SymmetricKey) {
      return key;
    }
    Map? info = Wrapper.getMap(key);
    if (info == null) {
      assert(false, 'symmetric key error: $key');
      return null;
    }
    // 提取算法类型
    String? algo = getKeyAlgorithm(info);
    assert(algo != null, 'symmetric key error: $key');
    // 获取对应工厂
    var factory = algo == null ? null : getSymmetricKeyFactory(algo);
    if (factory == null) {
      // 未知算法，使用默认工厂
      factory = getSymmetricKeyFactory('*');  // unknown
      assert(factory != null, 'default symmetric key factory not found');
    }
    return factory?.parseSymmetricKey(info);
  }

  // ====================== PrivateKey 私钥相关方法 ======================

  /// 设置私钥工厂（按算法映射）
  /// [algorithm] - 算法类型（如RSA）
  /// [factory] - 对应算法的PrivateKey工厂
  @override
  void setPrivateKeyFactory(String algorithm, PrivateKeyFactory factory) {
    _privateKeyFactories[algorithm] = factory;
  }

  /// 获取私钥工厂（按算法）
  /// [algorithm] - 算法类型
  /// 返回值：对应PrivateKey工厂（未找到返回null）
  @override
  PrivateKeyFactory? getPrivateKeyFactory(String algorithm) {
    return _privateKeyFactories[algorithm];
  }

  /// 生成私钥（按算法）
  /// 补充说明：
  /// - 不同算法的私钥由对应工厂生成（如RSA-2048/ECC-secp256r1）；
  /// - 适用于签名、解密等场景；
  /// [algorithm] - 算法类型
  /// 返回值：生成的PrivateKey实例
  @override
  PrivateKey? generatePrivateKey(String algorithm) {
    PrivateKeyFactory? factory = getPrivateKeyFactory(algorithm);
    assert(factory != null, 'key algorithm not support: $algorithm');
    return factory?.generatePrivateKey();
  }

  /// 解析私钥（支持多类型输入）
  /// 补充说明：
  /// 1. 逻辑与对称密钥解析一致，仅工厂类型不同；
  /// 2. 未知算法时使用默认工厂（key='*'）；
  /// [key] - 待解析的私钥（任意类型）
  /// 返回值：PrivateKey实例（失败返回null）
  @override
  PrivateKey? parsePrivateKey(Object? key) {
    if (key == null) {
      return null;
    } else if (key is PrivateKey) {
      return key;
    }
    Map? info = Wrapper.getMap(key);
    if (info == null) {
      assert(false, 'private key error: $key');
      return null;
    }
    String? algo = getKeyAlgorithm(info);
    assert(algo != null, 'private key error: $key');
    var factory = algo == null ? null : getPrivateKeyFactory(algo);
    if (factory == null) {
      factory = getPrivateKeyFactory('*');  // unknown
      assert(factory != null, 'default private key factory not found');
    }
    return factory?.parsePrivateKey(info);
  }

  // ====================== PublicKey 公钥相关方法 ======================

  /// 设置公钥工厂（按算法映射）
  /// [algorithm] - 算法类型（如RSA）
  /// [factory] - 对应算法的PublicKey工厂
  @override
  void setPublicKeyFactory(String algorithm, PublicKeyFactory factory) {
    _publicKeyFactories[algorithm] = factory;
  }

  /// 获取公钥工厂（按算法）
  /// [algorithm] - 算法类型
  /// 返回值：对应PublicKey工厂（未找到返回null）
  @override
  PublicKeyFactory? getPublicKeyFactory(String algorithm) {
    return _publicKeyFactories[algorithm];
  }

  /// 解析公钥（支持多类型输入）
  /// 补充说明：
  /// 1. 逻辑与私钥解析一致，无generate方法（公钥由私钥导出）；
  /// 2. 未知算法时使用默认工厂（key='*'）；
  /// [key] - 待解析的公钥（任意类型）
  /// 返回值：PublicKey实例（失败返回null）
  @override
  PublicKey? parsePublicKey(Object? key) {
    if (key == null) {
      return null;
    } else if (key is PublicKey) {
      return key;
    }
    Map? info = Wrapper.getMap(key);
    if (info == null) {
      assert(false, 'public key error: $key');
      return null;
    }
    String? algo = getKeyAlgorithm(info);
    assert(algo != null, 'public key error: $key');
    var factory = algo == null ? null : getPublicKeyFactory(algo);
    if (factory == null) {
      factory = getPublicKeyFactory('*');  // unknown
      assert(factory != null, 'default public key factory not found');
    }
    return factory?.parsePublicKey(info);
  }

}