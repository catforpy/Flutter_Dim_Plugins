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

import 'package:dimp/dimp.dart';

///
/// 密钥基础抽象类
/// 所有加密密钥的基类，封装密钥算法获取、密钥匹配校验等核心通用逻辑
/// （支撑去中心化IM的加解密、签名验签核心能力）
///
abstract class BaseKey extends Dictionary implements CryptographyKey {
  /// 构造方法： 初始化秘钥字典(存储秘钥的算法、数据等核心信息)
  BaseKey([super.dict]);

  /// 获取秘钥算法类型(如AES、RSA、ECC等)
  /// 从秘钥字典中提取算法标识，是加解密/签名验签的核心参数
  @override
  String get algorithm => getKeyAlgorithm(toMap());

  //
  //  通用工具方法（静态）
  //

  /// 从秘钥字典中提取算法类型
  /// @param key - 秘钥字典（包含algorithm字段）
  /// @return 算法名称（空字符串表示未找到）
  static String getKeyAlgorithm(Map key){
    var ext = SharedCryptoExtensions();
    return ext.helper!.getKeyAlgorithm(key) ?? '';
  }

  /// 校验对称秘钥密匙是否匹配（加密钥=解密钥）
  /// 用于验证：发送方的加密秘钥是否能被接收方的解密密钥匹配
  /// @param pKey - 公钥/加密钥（发送方用）
  /// @param sKey - 私钥/解密钥（接收方用）
  /// @return 匹配返回true，否则false
  static bool matchEncryptKey(EncryptKey pKey, DecryptKey sKey){
    return GeneralCryptoHelper.matchSymmetricKeys(pKey, sKey);
  }

  /// 校验非对称密钥对是否匹配（私钥签名=公钥验证）
  /// 用于验证：发送方的签名私钥是否能被接收方的验证公钥匹配
  /// @param sKey - 签名私钥（发送方用）
  /// @param pKey - 验证公钥（接收方用）
  /// @return 匹配返回true，否则false
  static bool matchSignKey(SignKey sKey, VerifyKey pKey){
    return GeneralCryptoHelper.matchAsymmetricKeys(sKey, pKey);
  }

  /// 比较两个对称密钥是否相等
  /// 先判断是否为同一对象，再通过加密匹配性校验（避免仅比较字典导致的误差）
  /// @param a - 对称密钥A
  /// @param b - 对称密钥B
  /// @return 相等返回true，否则false
  static bool symmetricKeysEqual(SymmetricKey a, SymmetricKey b){
    if(identical(a, b)){
      // 同一对象
      return true;
    }
    // 非同一对象，通过加密匹配性校验
    return matchEncryptKey(a, b);
  }

  /// 比较两个私钥是否相等
  /// 先判断是否为同一对象，再通过签名匹配性校验（私钥→公钥→验证签名）
  /// @param a - 私钥A
  /// @param b - 私钥B
  /// @return 相等返回true，否则false
  static bool privateKeysEqual(PrivateKey a, PrivateKey b) {
    if (identical(a, b)) {
      // 同一对象直接返回true
      return true;
    }
    // 非同一对象时，通过私钥的公钥做签名匹配校验
    return matchSignKey(a, b.publicKey);
  }
}

///
/// 对称密钥抽象类
/// 封装对称加密密钥的相等性判断、算法获取、加密匹配校验
/// （用于消息内容的对称加密，如AES，特点：加解密用同一密钥）
///
abstract class BaseSymmetricKey extends Dictionary implements SymmetricKey {
  /// 构造方法：初始化对称密钥字典
  BaseSymmetricKey([super.dict]);

  /// 重写相等运算符：支持与SymmetricKey/Map类型的比较
  /// 优先级：同一对象 > SymmetricKey匹配 > 字典内容匹配
  @override
  bool operator ==(Object other) { 
    if(other is Mapper){
      if(identical(this, other)){
        // 同一对象
        return true;
      }else if(other is SymmetricKey){
        // 非同一个对象单为SymmetricKey，用对称密钥匹配规则校验
        return BaseKey.symmetricKeysEqual(other, this);
      }
      // 非SymmetricKey类型的Mapper，转为字典比较
      other = other.toMap();
    }
    // 最终按字典内容完全匹配判断
    return other is Map && Comparator.mapEquals(other, toMap());
  }

  /// 重写哈希值：基于秘钥字典的哈希值（保证相等性判断的一致性）
  @override
  int get hashCode => toMap().hashCode;

  /// 获取对称密钥算法类型(如AES、DES)
  @override
  String get algorithm => BaseKey.getKeyAlgorithm(toMap());

  /// 校验当前对称密钥是否与目标加密钥匹配
  /// （接收方用词方法验证）：自己的解密钥能否解密发送方的加密内容
  @override
  bool matchEncryptKey(EncryptKey pKey) => BaseKey.matchEncryptKey(pKey, this);
}

///
/// 非对称密钥抽象类
/// 非对称密钥（公钥/私钥）的基类，封装算法获取逻辑
/// （用于对称密钥的非对称加密，如RSA，特点：公钥加密、私钥解密）
///
abstract class BaseAsymmetricKey extends Dictionary implements AsymmetricKey{
  /// 构造方法：初始化对称密钥字典
  BaseAsymmetricKey([super.dict]);

  /// 获取非对称秘钥算法类型
  @override
  String get algorithm => BaseKey.getKeyAlgorithm(toMap());
}

///
/// 私钥抽象类
/// 封装私钥的相等性判断、算法获取
/// （用于签名消息、解密对称密钥，是去中心化IM中用户的核心身份凭证）
///
abstract class BasePrivateKey extends Dictionary implements PrivateKey{
  /// 构造方法
  BasePrivateKey([super.dict]);

  /// 重写相等运算符：支持与PrivateKey/Map类型的比较
  /// 优先级：同一对象 > PrivateKey匹配 > 字典内容匹配
  @override
  bool operator ==(Object other){
    if(other is Mapper)
    {
      if (identical(this, other)) {
        return true;
      }else if(other is PrivateKey){
        // 非同一对象，但为PrivateKey,用私钥匹配规则校验
        return BaseKey.privateKeysEqual(other, this);
      }
      // 非PrivateKey类型的Mapper,转为字典比较
      other = other.toMap();
    }
    // 最终按字典内容完全匹配判断
    return other is Map && Comparator.mapEquals(other, toMap());
  }

  /// 重写哈希值：基于私钥字典的哈希值（保证相等性判断的一致性）
  @override
  int get  hashCode => toMap().hashCode;

  /// 获取私钥算法类型
  @override
  String get algorithm => BaseKey.getKeyAlgorithm(toMap());
}

///
/// 公钥抽象类
/// 封装公钥的算法获取、签名匹配校验
/// （用于验证消息签名、加密对称密钥，可公开传输，不泄露用户隐私）
///
abstract class BasePublicKey extends Dictionary implements PublicKey { 
  BasePublicKey([super.dict]);

  /// 获取公钥算法类型
  @override
  String get algorithm => BaseKey.getKeyAlgorithm(toMap());

  /// 校验当前公钥是否与目标签名匹配
  /// 接收方用此方法验证：发送方的签名私钥是否合法
  @override
  bool matchSignKey(SignKey sKey) => BaseKey.matchSignKey(sKey, this);
}