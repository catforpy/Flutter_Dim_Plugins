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

/// 默认元数据（MKM类型）
/// 用于生成"name@address"格式的ID
/// 版本：1 = MKM
/// 地址生成算法：
///   1. CT = 指纹 = 私钥签名(seed)
///   2. hash = RIPEMD160(SHA256(CT))
///   3. code = SHA256(SHA256(network + hash)).前4字节
///   4. address = Base58编码(network + hash + code)
class DefaultMeta extends BaseMeta{
  /// 构造方法1：从Map初始化
  /// [dict] - 包含元数据的Map
  DefaultMeta([super.dict]);

  /// 构造方法2：从原始数据初始化
  /// [type] - 元数据类型（MKM/1）
  /// [key] - 公钥
  /// [seed] - 种子（名称）
  /// [fingerprint] - 指纹（私钥签名seed的结果）
  DefaultMeta.from(String type, VerifyKey key, String seed, TransportableData fingerprint)
      : super.from(type, key, seed: seed, fingerprint: fingerprint);

  /// 是否包含seed（固定为true）
  @override
  bool get hasSeed => true;

  // 地址缓存：key=network，value=Address
  final Map<int, Address> _cachedAddresses = {};

  /// 生成地址（从指纹）
  /// [network] - 网络类型
  /// 返回值：生成的BTC格式地址
  @override
  Address generateAddress(int? network) {
    assert(network != null, 'address type should not be empty');
    // 检查缓存
    Address? cached = _cachedAddresses[network];
    if(cached == null){
      // 获取指纹数据
      var data = fingerprint;
      assert(data != null && data.isNotEmpty, 'meta.fingerprint empty');
      // 生成BTC地址并缓存
      cached = BTCAddress.generate(data!, network!);
      _cachedAddresses[network] = cached;
    }
    return cached;
  }
}

/// BTC类型元数据
/// 用于生成BTC格式地址的ID
/// 版本：2 = BTC
/// 地址生成算法：
///   1. CT = 公钥数据
///   2. hash = RIPEMD160(SHA256(CT))
///   3. code = SHA256(SHA256(network + hash)).前4字节
///   4. address = Base58编码(network + hash + code)
class BTCMeta extends BaseMeta {
  /// 构造方法1：从Map初始化
  /// [dict] - 包含元数据的Map
  BTCMeta([super.dict]);

  /// 构造方法2：从原始数据初始化
  /// [type] - 元数据类型（BTC/2）
  /// [key] - 公钥
  /// [seed] - 种子（可选）
  /// [fingerprint] - 指纹（可选）
  BTCMeta.from(String type, VerifyKey key, {String? seed, TransportableData? fingerprint})
      : super.from(type, key, seed: seed, fingerprint: fingerprint);

  /// 是否包含seed（固定为false）
  @override
  bool get hasSeed => false;

  // 地址缓存：key=network，value=Address
  final Map<int, Address> _cachedAddresses = {};

  /// 生成地址（从公钥）
  /// [network] - 网络类型
  /// 返回值：生成的BTC格式地址
  @override
  Address generateAddress(int? network) {
    assert(network != null, 'address type should not be empty');
    // 检查缓存
    Address? cached = _cachedAddresses[network];
    if (cached == null) {
      // TODO: 公钥压缩？
      VerifyKey key = publicKey;
      Uint8List data = key.data;
      // 生成BTC地址并缓存
      cached = BTCAddress.generate(data, network!);
      _cachedAddresses[network] = cached;
    }
    return cached;
  }
}


/// ETH类型元数据
/// 用于生成ETH格式地址的ID
/// 版本：4 = ETH
/// 地址生成算法：
///   1. CT = 公钥数据（去掉前缀字节）
///   2. digest = KECCAK256(CT)
///   3. address = 十六进制编码(digest最后20字节)
class ETHMeta extends BaseMeta {
  /// 构造方法1：从Map初始化
  /// [dict] - 包含元数据的Map
  ETHMeta([super.dict]);

  /// 构造方法2：从原始数据初始化
  /// [type] - 元数据类型（ETH/4）
  /// [key] - 公钥
  /// [seed] - 种子（可选）
  /// [fingerprint] - 指纹（可选）
  ETHMeta.from(String type, VerifyKey key, {String? seed, TransportableData? fingerprint})
      : super.from(type, key, seed: seed, fingerprint: fingerprint);

  /// 是否包含seed（固定为false）
  @override
  bool get hasSeed => false;

  // 地址缓存
  Address? _cachedAddress;

  /// 生成地址（从公钥）
  /// [network] - 网络类型（固定为用户类型）
  /// 返回值：生成的ETH格式地址
  @override
  Address generateAddress(int? network) {
    assert(type == MetaType.ETH || type == '4', 'meta type error: $type');
    assert(network == null || network == EntityType.USER, 'address type error: $network');
    // 检查缓存
    Address? cached = _cachedAddress;
    if (cached == null/* || cached.type != network*/) {
      // 获取64字节公钥数据（去掉前缀0x04）
      VerifyKey key = publicKey;
      Uint8List data = key.data;
      // 生成ETH地址并缓存
      cached = ETHAddress.generate(data);
      _cachedAddress = cached;
    }
    return cached;
  }
}


/// 基础元数据工厂类
/// 核心作用：
/// 1. 实现MetaFactory接口，提供元数据的生成/创建/解析能力；
/// 2. 支持多类型元数据（MKM/BTC/ETH）的创建和解析；
class BaseMetaFactory implements MetaFactory {
  /// 构造方法：指定元数据类型
  /// [type] - 元数据类型（MKM/BTC/ETH）
  BaseMetaFactory(this.type);

  // 元数据类型
  // protected
  final String type;

  /// 生成元数据（从私钥）
  /// [sKey] - 私钥
  /// [seed] - 种子（可选）
  /// 返回值：生成的元数据
  @override
  Meta generateMeta(SignKey sKey, {String? seed}) {
    TransportableData? fingerprint;
    if (seed == null || seed.isEmpty) {
      // 无seed则无指纹
      fingerprint = null;
    } else {
      // 有seed：私钥签名seed生成指纹
      Uint8List data = UTF8.encode(seed);
      Uint8List sig = sKey.sign(data);
      fingerprint = TransportableData.create(sig);
    }
    // 获取公钥
    VerifyKey pKey = (sKey as PrivateKey).publicKey;
    // 创建元数据
    return createMeta(pKey, seed: seed, fingerprint: fingerprint);
  }

  /// 创建元数据（从公钥）
  /// [pKey] - 公钥
  /// [seed] - 种子（可选）
  /// [fingerprint] - 指纹（可选）
  /// 返回值：创建的元数据
  @override
  Meta createMeta(VerifyKey pKey, {String? seed, TransportableData? fingerprint}) {
    Meta out;
    // 根据类型创建对应元数据
    switch (type) {
      case MetaType.MKM:
      case 'mkm':
        out = DefaultMeta.from(type, pKey, seed!, fingerprint!);
        break;
      case MetaType.BTC:
      case 'btc':
        out = BTCMeta.from(type, pKey);
        break;
      case MetaType.ETH:
      case 'eth':
        out = ETHMeta.from(type, pKey);
        break;
      default:
        throw Exception('unknown meta type: $type');
    }
    assert(out.isValid, 'meta error: $out');
    return out;
  }

  /// 解析Map为元数据
  /// [meta] - 包含元数据的Map
  /// 返回值：元数据对象（解析失败返回null）
  @override
  Meta? parseMeta(Map meta) {
    // 校验核心字段（注释掉的校验逻辑）
    // if (meta['type'] == null || meta['key'] == null) {
    //   assert(false, 'meta error: $meta');
    //   return null;
    // } else if (meta['seed'] == null) {
    //   if (meta['fingerprint'] != null) {
    //     assert(false, 'meta error: $meta');
    //     return null;
    //   }
    // } else if (meta['fingerprint'] == null) {
    //   assert(false, 'meta error: $meta');
    //   return null;
    // }
    
    Meta out;
    // 获取元数据类型
    var ext = SharedAccountExtensions();
    String? version = ext.helper!.getMetaType(meta, '');
    // 根据类型解析对应元数据
    switch (version) {
      case MetaType.MKM:
      case 'mkm':
        out = DefaultMeta(meta);
        break;
      case MetaType.BTC:
      case 'btc':
        out = BTCMeta(meta);
        break;
      case MetaType.ETH:
      case 'eth':
        out = ETHMeta(meta);
        break;
      default:
        throw Exception('unknown meta type: $type');
    }
    // 校验元数据有效性
    if (out.isValid) {
      return out;
    }
    assert(false, 'meta error: $meta');
    return null;
  }

}