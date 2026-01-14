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
 * 核心功能：定义实体的元数据接口，是ID/地址生成的核心依据，存储固定不变的信息
 * 设计背景：Meta包含公钥、指纹等核心信息，是去中心化身份认证的基石
 * 核心特性：不可篡改，指纹由私钥签名生成，可验证ID和公钥的合法性
 */


import 'dart:typed_data';

import 'package:mkm/mkm.dart';
import 'package:mkm/type.dart';

/// 【核心接口】实体元数据（Meta）
/// 存储实体的固定信息，是ID/地址生成的依据，格式：
/// {
///     type        : 1,              // 算法版本（1=MKM，2=BTC，4=ETH）
///     key         : "{public key}", // 公钥（用于验签）
///     seed        : "moKy",         // 名称（生成指纹的种子）
///     fingerprint : "..."           // 指纹（私钥签名seed的结果）
/// }
abstract interface class Meta implements Mapper{
  /// Meta算法版本
  /// - 1 = MKM：username@address（默认）
  /// - 2 = BTC：比特币地址格式
  /// - 4 = ETH：以太坊地址格式
  String get type;

  /// 公钥（用于验证签名，不可变）
  VerifyKey get publicKey;

  /// 种子(生成指纹的原始数据，如用户名)
  String? get seed;

  /// 指纹(私钥签名seed的结果，用于验证ID合法性)
  Uint8List? get fingerprint;

  // -------------------------- 验证方法 --------------------------
  /// 检查Meta是否有效（指纹是否匹配）
  bool get isValid;

  /// 根据Meta生成地址
  Address generateAddress(int? network);

  // -------------------------- 工厂方法 --------------------------
  /// 创建Meta（从存储加载）
  static Meta create(String type, VerifyKey pKey, {String? seed, TransportableData? fingerprint}) {
    var ext = AccountExtensions();
    return ext.metaHelper!.createMeta(type, pKey, seed: seed, fingerprint: fingerprint);
  }

  /// 生成Meta（用私钥生成指纹）
  static Meta generate(String type,SignKey sKey,{String? seed}){
    var ext = AccountExtensions();
    return ext.metaHelper!.generateMeta(type,sKey,seed:seed);
  }

  /// 解析任意对象为Meta（支持字符串/Map）
  static Meta? parse(Object? meta) {
    var ext = AccountExtensions();
    return ext.metaHelper!.parseMeta(meta);
  }

  /// 获取指定版本的Meta工厂
  static MetaFactory? getFactory(String type) {
    var ext = AccountExtensions();
    return ext.metaHelper!.getMetaFactory(type);
  }
  
  /// 注册指定版本的Meta工厂
  static void setFactory(String type, MetaFactory factory) {
    var ext = AccountExtensions();
    ext.metaHelper!.setMetaFactory(type, factory);
  }
}

/// 【Meta工厂接口】
/// 定义Meta的创建/生成/解析规范，不同版本（MKM/BTC/ETH）需实现此接口
abstract interface class MetaFactory{
  /// 创建Meta（从存储加载）
  Meta createMeta(VerifyKey pKey,{String? seed,TransportableData? fingerprint});

  /// 生成Meta（用私钥签名seed生成指纹）
  Meta generateMeta(SignKey sKey, {String? seed});

  /// 解析Map为Meta对象
  Meta? parseMeta(Map meta);
}
