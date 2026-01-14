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
 * 核心功能：提供对称/非对称密钥的工厂管理接口，实现算法与实现的解耦
 * 设计模式：工厂模式 + 单例模式，支持动态注册不同算法的工厂类
 */

import 'package:mkm/mkm.dart';

/// 【对称密钥助手接口】
/// 管理对称密钥（如AES）的工厂类注册、生成、解析
abstract interface class SymmetricKeyHelper{
  /// 注册指定算法的对称密钥工厂
  /// [algorithm]：算法名（如"AES"）
  /// [factory]：对应算法的工厂实现类
  void setSymmetricKeyFactory(String algorithm, SymmetricKeyFactory factory);

  /// 获取指定算法的对称秘钥工厂
  SymmetricKeyFactory? getSymmetricKeyFactory(String algorithm);

  /// 生成指定算法的对称秘钥
  SymmetricKey? generateSymmetricKey(String algorithm);

  /// 解析对象为对称密钥（支持Map/Base64字符串等格式）
  SymmetricKey? parseSymmetricKey(Object? key);
}

/// 【公钥助手接口】
/// 管理非对称公钥（如RSA/ECC）的工厂类注册、解析
abstract interface class PublicKeyHelper {
  /// 注册制定算法的公钥工厂
  void setPublicKeyFactory(String algorithm, PublicKeyFactory factory);

  /// 获取指定算法的公钥工厂
  PublicKeyFactory? getPublicKeyFactory(String algorithm);

  /// 解析对象为公钥
  PublicKey? parsePublicKey(Object? key);
}

/// 【私钥助手接口】
/// 管理非对称私钥（如RSA/ECC）的工厂类注册、生成、解析
abstract interface class PrivateKeyHelper {
  /// 注册指定算法的私钥工厂
  void setPrivateKeyFactory(String algorithm, PrivateKeyFactory factory);
  
  /// 获取指定算法的私钥工厂
  PrivateKeyFactory? getPrivateKeyFactory(String algorithm);

  /// 生成指定算法的私钥
  PrivateKey? generatePrivateKey(String algorithm);

  /// 解析对象为私钥
  PrivateKey? parsePrivateKey(Object? key);
}

/// 【加密扩展管理器】
/// 单例类，统一管理对称/公钥/私钥助手实例，是工厂注册的核心入口
// protected：Dart中通过命名规范标识，仅内部使用
class CryptoExtensions {
  /// 工厂构造方法：返回单例实例
  factory CryptoExtensions() => _instance;
  
  /// 静态单例实例
  static final CryptoExtensions _instance = CryptoExtensions._internal();
  
  /// 私有构造方法：防止外部实例化
  CryptoExtensions._internal();

  /// 对称密钥助手实例（由外部注入具体实现）
  SymmetricKeyHelper? symmetricHelper;

  /// 私钥助手实例（由外部注入具体实现）
  PrivateKeyHelper? privateHelper;
  
  /// 公钥助手实例（由外部注入具体实现）
  PublicKeyHelper? publicHelper;
}