/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2025 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2025 Albert Moky
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

/// 元数据版本枚举说明（注释原文）：
///  enum MKMMetaVersion
///
///  abstract Defined for algorithm that generating address.
///
///  discussion Generate and check ID/Address
///
///      MKMMetaVersion_MKM give a seed string first, and sign this seed to get
///      fingerprint; after that, use the fingerprint to generate address.
///      This will get a firmly relationship between (username, address and key).
///
///      MKMMetaVersion_BTC use the key data to generate address directly.
///      This can build a BTC address for the entity ID (no username).
///
///      MKMMetaVersion_ExBTC use the key data to generate address directly, and
///      sign the seed to get fingerprint (just for binding username and key).
///      This can build a BTC address, and bind a username to the entity ID.
///
///  版本位说明（注释原文）：
///      0000 0001 - this meta contains seed as ID.name（包含种子作为ID名称）
///      0000 0010 - this meta generate BTC address（生成BTC地址）
///      0000 0100 - this meta generate ETH address（生成ETH地址）
///      ...
///
/// 元数据版本/算法类型常量类
/// 定义了生成地址的不同算法版本，用于身份认证（Ming-Ke-Ming）
class MetaVersion {

  // ignore_for_file: constant_identifier_names
  /// 默认版本：0000 0001（等同于MKM）
  static const int DEFAULT = (0x01);
  /// MKM算法：先签名种子获取指纹，再生成地址（绑定用户名、地址、密钥）
  static const int MKM     = (0x01);  // 0000 0001

  /// BTC算法：直接使用密钥数据生成BTC地址（无用户名）
  static const int BTC     = (0x02);  // 0000 0010
  /// 扩展BTC算法：直接生成BTC地址 + 签名种子绑定用户名
  static const int ExBTC   = (0x03);  // 0000 0011

  /// ETH算法：直接使用密钥数据生成ETH地址（无用户名）
  static const int ETH     = (0x04);  // 0000 0100
  /// 扩展ETH算法：直接生成ETH地址 + 签名种子绑定用户名
  static const int ExETH   = (0x05);  // 0000 0101

  /// 将元数据类型转换为字符串
  /// [type] 类型（字符串/数字/MetaVersion）
  /// 返回：类型字符串
  static String parseString(dynamic type) {
    if (type is String) {
      return type;
    } else if (type is MetaVersion) {
      return type.toString();
    } else if (type is int) {
      return type.toString();
    } else if (type is num) {
      return type.toString();
    } else {
      assert(type == null, 'meta type error: $type');
      return '';
    }
  }

  /// 检查元数据版本是否包含种子（ID.name）
  /// [type] 版本类型（任意类型）
  /// 返回：true=包含种子，false=不包含
  static bool hasSeed(dynamic type) {
    int version = parseInt(type, 0);
    return 0 < version && (version & MKM) == MKM;
  }

  /// 将元数据类型转换为整数版本号
  /// [type] 类型（字符串/数字/枚举）
  /// [defaultValue] 默认值
  /// 返回：整数版本号（解析失败返回-1或默认值）
  static int parseInt(dynamic type, int defaultValue) {
    if (type == null) {
      return defaultValue;
    } else if (type is int) {
      // 精确匹配整数类型
      return type;
    } else if (type is num) {
      // 数字类型转换为整数
      return type.toInt();
    } else if (type is String) {
      // 字符串类型：匹配固定值
      if (type == 'MKM' || type == 'mkm') {
        return MKM;
      } else if (type == 'BTC' || type == 'btc') {
        return BTC;
      } else if (type == 'ExBTC') {
        return ExBTC;
      } else if (type == 'ETH' || type == 'eth') {
        return ETH;
      } else if (type == 'ExETH') {
        return ExETH;
      }
      // TODO: other algorithms（其他算法待扩展）
    // } else if (type is MetaVersion) {
    //   // enum（枚举类型注释未启用）
    //   return type;
    } else {
      return -1;
    }
    // 尝试解析字符串为整数
    try {
      return int.parse(type);
    } catch (e) {
      return -1;
    }
  }
}