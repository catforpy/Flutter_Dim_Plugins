/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
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
import 'package:dim_client/sdk.dart';    // DIM-SDK核心库（密钥/ID相关）
import 'package:dim_client/common.dart'; // DIM-SDK通用接口（PrivateKeyDBI）

import 'manager.dart';

/// 密钥链通道（iOS/macOS专用）：封装原生Keychain存储
/// 实现PrivateKeyDBI接口，统一密钥存储/读取的入口
/// 核心功能：安全存储用户私钥（签名/解密用），适配iOS/macOS的Keychain安全机制
class KeychainChannel extends SafeChannel implements PrivateKeyDBI {
  /// 构造方法：初始化密钥通道，绑定通道名称
  /// [name] - 原生通道名称（对应ChannelNames.database）
  KeychainChannel(super.name);

  // ===================== 实现PrivateKeyDBI接口（私钥存储） =====================
  /// 保存私钥到原生Keychain
  /// [key] - 要保存的私钥对象
  /// [type] - 私钥类型（签名/解密）
  /// [user] - 私钥所属用户ID
  /// [sign/decrypt] - 预留参数（签名/解密用途标记）
  /// 返回：是否保存成功（1=成功，其他=失败）
  @override
  Future<bool> savePrivateKey(PrivateKey key, String type, ID user,
  {int sign = 1,required int decrypt}) async {
    int? res = await invoke(ChannelMethods.savePrivateKey,{
      'user':user.toString(),     // 用户ID转字符串（原生无法直接解析ID对象）
      'type':type,                // 私钥类型
      'key':key.toMap(),          // 私钥转Map（序列化后传递给原生）
    });
    return res == 1;      // 原生返回1表示保存成功
  }

  /// 获取用户签名用私钥（用于消息签名/身份验证）
  /// [user] - 目标用户ID
  /// 返回：私钥对象（null表示未找到）
  @override
  Future<PrivateKey?> getPrivateKeyForSignature(ID user) async {
    Map? key = await invoke(ChannelMethods.privateKeyForSignature,{
      'user':user.toString(),     // 用户ID转字符串（原生无法直接解析ID对象）
    });
    return PrivateKey.parse(key);       // 反序列化Map为私钥对象
  }

  /// 获取用户Visa文档签名用私钥（Visa是用户身份凭证，需专属签名私钥）
  /// [user] - 目标用户ID
  /// 返回：私钥对象（null表示未找到）
  @override
  Future<PrivateKey?> getPrivateKeyForVisaSignature(ID user) async {
    Map? key = await invoke(ChannelMethods.privateKeyForVisaSignature,{
      'user':user.toString(),     // 用户ID转字符串（原生无法直接解析ID对象）
    });
    return PrivateKey.parse(key);
  }

  /// 获取用户解密用私钥列表（支持多密钥解密）
  /// [user] - 目标用户ID
  /// 返回：解密密钥列表（空列表表示无可用密钥）
  @override
  Future<List<DecryptKey>> getPrivateKeysForDecryption(ID user) async {
    List? keys = await invoke(ChannelMethods.privateKeysForDecryption,{
      'user':user.toString(),     // 用户ID转字符串（原生无法直接解析ID对象）
    });
    // 空值处理：五米要返回空列表
    if(keys == null || keys.isEmpty){
      return [];
    }
    List<PrivateKey> privateKeys = [];
    PrivateKey? sk;
    // 遍历原生返回的秘钥列表，反序列化为私钥对象
    for(var item in keys){
      sk = PrivateKey.parse(item);
      if(sk == null){
        assert(false, 'private key error: $item'); // 开发期断言：密钥解析失败
        continue;
      }
      privateKeys.add(sk);
    }
    // 转换为DecryptKey类型（适配DIM-SDK的解密接口）
    return PrivateKeyDBI.convertDecryptKeys(privateKeys);
  }
}