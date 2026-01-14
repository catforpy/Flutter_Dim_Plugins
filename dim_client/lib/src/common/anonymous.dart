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

import 'dart:typed_data';

import 'package:dim_client/plugins.dart';
import 'package:dim_plugins/dim_plugins.dart';

/// 匿名信息工具类
/// 用于生成实体ID的匿名名称、地址数字格式化等功能
class Anonymous{

  /// 获取实体ID的匿名显示名称
  /// [identifier] 实体ID
  /// 返回：格式化的匿名名称（类型+地址数字）
  static String getName(ID identifier){
    // 优先获取ID中自带的名称
    String? name = identifier.name;
    if(name == null || name.isEmpty){
      // 无名称时根据试题类型生成默认名称
      name = _name(identifier.type);
    }
    // 拼接名称和格式化的地址数字（如:User(123-456-7890)）
    return '$name (${getNumberString(identifier.address)})';
  }

  /// 将地址转换为格式化的数字字符串（10位数字，分三段：XXX-XXX-XXXX）
  /// [address]实体地址（BTC/ETH等）
  /// 返回：格式化的数字字符串
  static String getNumberString(Address address){
    // 降低至转换为整数
    int number = getNumber(address);
    // 补零到10位，再分三段拼接
    String string = '$number'.padLeft(10, '0');
    String a = string.substring(0, 3);
    String b = string.substring(3, 6);
    String c = string.substring(6);
    return "$a-$b-$c";
  }

  /// 将地址转换为整数（仅支持BTC/ETH地址）
  /// [address] 实体地址
  /// 返回：地址对应的整数（不支持的地址类型返回0）
  static int getNumber(Address address) {
    if(address is BTCAddress){
      // BTC地址转换为整数
      return _btcNumber(address.toString());
    }
    if(address is ETHAddress){
      // ETH地址转换为整数
      return _ethNumber(address.toString());
    }
    return 0;
  }
}

/// 根据实体类型获取默认名称
/// [type] 实体类型（用户/群组/机器人等）
/// 返回：类型对应的默认名称
String _name(int type){
  switch(type){
    case EntityType.BOT:
      return 'Bot';
    case EntityType.STATION:
      return 'Station';
    case EntityType.ISP:
      return 'ISP';
    case EntityType.ICP:
      return 'ICP';
  }
  if(EntityType.isUser(type)){
    // 普通用户类型
    return 'User';
  }else if (EntityType.isGroup(type)) {
    // 群组类型
    return 'Group';
  }
  // 断言：理论上不会走到这里
  assert(false, 'should not happen');
  return 'Unknown';
}

/// BTC地址转换为整数
/// [address] BTC地址字符串
/// 返回：地址对应的整数（解码失败返回0）
int _btcNumber(String address) {
  // Base58解码BTC地址
  Uint8List? data = Base58.decode(address);
  // 断言：BTC地址解码失败（调试模式触发）
  assert(data != null, 'BTC address error: $address');
  // 解码失败返回0，否则转换为用户编号
  return data == null ? 0 : _userNumber(data);
}

/// ETH地址转换为整数
/// [address] ETH地址字符串
/// 返回：地址对应的整数（解码失败返回0）
int _ethNumber(String address) {
  // 去掉ETH地址前缀"0x"后Hex解码
  Uint8List? data = Hex.decode(address.substring(2));
  // 断言：ETH地址解码失败（调试模式触发）
  assert(data != null, 'ETH address error: $address');
  // 解码失败返回0，否则转换为用户编号
  return data == null ? 0 : _userNumber(data);
}

/// 将字节数组转换为用户编号（取最后4个字节）
/// [cc] 地址解码后的字节数组
/// 返回：4字节对应的整数
int _userNumber(Uint8List cc) {
  int len = cc.length;
  // 取最后4个字节，按位拼接为整数（大端序）
  return
    (cc[len-4] & 0xFF) << 24 |
    (cc[len-3] & 0xFF) << 16 |
    (cc[len-2] & 0xFF) << 8 |
    (cc[len-1] & 0xFF);
}