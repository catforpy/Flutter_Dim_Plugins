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

/// Meta类型枚举
/// 作用：定义生成实体地址的算法类型，是去中心化身份的核心标识
/// 设计思路：用二进制位标识不同地址生成规则，适配不同区块链地址格式
/// 类型说明：
///      MKM：先生成种子字符串，签名后得到指纹，再生成地址（用户名+地址绑定）
///      BTC：直接用密钥生成BTC地址（无用户名）
///      ExBTC：直接生成BTC地址，同时签名种子绑定用户名（用户名+BTC地址）
///      ETH：直接用密钥生成ETH地址（无用户名）
///      ExETH：直接生成ETH地址，同时签名种子绑定用户名（用户名+ETH地址）
abstract interface class MetaType{
  /// 默认类型（MKM）
  static const DEFAULT = '1';
  static const MKM     = '1';   // 0000 0001: username@address

  /// 比特币地址相关
  static const BTC     = '2';   // 0000 0010: btc_address
  static const ExBTC   = '3';   // 0000 0011: username@btc_address（预留）

  /// 以太坊地址相关
  static const ETH     = '4';   // 0000 0100: eth_address
  static const ExETH   = '5';   // 0000 0101: username@eth_address（预留）
}

/// Document类型枚举
/// 作用：定义实体资料的类型常量，区分用户/群组的不同资料
abstract interface class DocumentType {
  /// 个人签证（用户核心资料，包含加密公钥）
  static const VISA     = 'visa';
  /// 个人资料（预留，如昵称、头像等扩展信息）
  static const PROFILE  = 'profile';
  /// 群组公告（群组核心资料，包含创始人、管理员等）
  static const BULLETIN = 'bulletin';
}