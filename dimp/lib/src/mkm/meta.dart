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

import 'package:dimp/dimp.dart';

///  用户/群组元数据（Meta）基类
///  ~~~~~~~~~~~~~~~~~~~~
///  核心作用：生成用户/群组的唯一ID（去中心化身份的根基）
///
///      数据格式：{
///          type        : 1,              // 算法版本（1=MKM，2=BTC，4=ETH）
///          key         : "{公钥}",       // 签名用公钥（由私钥生成）
///          seed        : "moKy",         // 用户名/群组名（可选）
///          fingerprint : "..."           // 指纹（用私钥签名seed生成）
///      }
///
///      核心算法：
///          fingerprint = 私钥.sign(seed); // 生成指纹
///          验证：公钥.verify(seed, fingerprint) // 验证指纹
///
///  抽象方法：
///      - Address generateAddress(int? network); // 生成实体ID的地址部分
abstract class BaseMeta extends Dictionary implements Meta{
  // 构造方法1：从字典初始化（解析网络/本地存储的Meta）
  BaseMeta([super.dict]);

  /// Meta算法版本（缓存）
  String? _type;

  /// 签名用公钥（缓存）
  VerifyKey? _key;

  /// 生成指纹的种子（用户名/群组名，缓存）
  String? _seed;

  /// 指纹（验证ID和公钥的核心，缓存）
  TransportableData? _fingerprint;

  /// Meta验证状态：1=有效，0=未验证，-1=无效
  int _status = 0;

  /// 构造方法2：创建新的Meta（本地生成/加载已验证的Meta）
  /// @param type         - 算法版本（1=MKM,2=BTC,4=ETH）
  /// @param key          - 签名用公钥
  /// @param seed         - 用户名/群组名（可选）
  /// @param fingerprint  - 指纹（可选，seed的签名）
  BaseMeta.from(String type,VerifyKey key,{String? seed,TransportableData? fingerprint}){
    // 1. 存储算法版本
    this['type'] = type;
    _type = type;

    // 2. 存储签名用公钥
    this['key'] = key;
    _key = key;

    // 3. 存储种子（用户名/群组名）
    if(seed != null){
      this['seed'] = seed;
    }
    _seed = seed;

    // 4. 存储指纹
    if(fingerprint != null){
      this['fingerprint'] = fingerprint.toObject();
    }
    _fingerprint = fingerprint;

    // 本地生成/加载的Meta，无需重复验证
    _status = 1;
  }

  /// 获取Meta算法版本（懒加载+兼容处理）
  @override
  String get type{
    String? version = _type;
    if(version == null){
      // 从扩展工具中获取版本（兼容不同格式）
      version = SharedAccountExtensions().helper!.getMetaType(toMap());
      version ??= '';
      _type = version;
    }
    return version;
  }

  /// 获取签名用公钥（懒加载+非空校验）
  @override
  VerifyKey get publicKey{
    _key ??= PublicKey.parse(this['key']);
    assert(_key != null, 'Meta公钥错误: $this');
    return _key!;
  }

  /// 保护方法：当前Meta是否需要seed（子类实现）
  /// 注：MKM算法（type=1）需要seed，BTC/ETH不需要
  bool get hasSeed;

  /// 获取种子（用户名/群组名，仅MKM算法有效）
  @override
  String? get seed{
    String? name = _seed;
    if(name == null && hasSeed){
      // 懒加载seed字段（非空校验）
      name = getString('seed');
      assert(name != null && name.isNotEmpty, 'Meta种子为空: $this');
      _seed = name;
    }
    return name;
  }

  /// 获取指纹（seed的签名，仅MKM算法有效）
  @override
  Uint8List? get fingerprint{
    TransportableData? ted = _fingerprint;
    if(ted == null && hasSeed){
      // 懒加载指纹字段（非空校验）
      Object? base64 = this['fingerprint'];
      assert(base64 != null, 'Meta指纹不能为空: ${toMap()}');
      _fingerprint = ted = TransportableData.parse(base64);
      assert(ted != null, 'Meta指纹格式错误: $base64');
    }
    return ted?.data;
  }

  /// 
  /// 验证逻辑
  /// 
  
  /// 获取Meta验证状态（是否有效）
  @override
  bool get isValid{
    if(_status == 0){
      // 网络获取的meta,首次验证
      _status = checkValid() ? 1 : -1;
    }
    return _status > 0 ;
  }

  /// 私有方法：校验Meta的合法性
  bool checkValid() {
    VerifyKey key = publicKey;
    if (hasSeed) {
      // 场景1：MKM算法（需要校验seed和fingerprint）
    } else if (containsKey('seed') || containsKey('fingerprint')) {
      // 场景2：非MKM算法（BTC/ETH），禁止包含seed/fingerprint
      return false;
    } else {
      // 场景3：非MKM算法，仅需公钥存在即有效
      return true;
    }

    // 校验MKM算法的seed和fingerprint
    String? name = seed;
    Uint8List? signature = fingerprint;
    if (signature == null || signature.isEmpty ||
        name == null || name.isEmpty) {
      assert(false, 'Meta参数错误: $toMap()');
      return false;
    }
    // 验证指纹：公钥.verify(seed的二进制, 指纹)
    Uint8List data = UTF8.encode(name);
    return key.verify(data, signature);
  }
}