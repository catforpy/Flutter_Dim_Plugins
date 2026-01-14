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

import 'package:mkm/mkm.dart';
import 'package:mkm/src/protocol/entity.dart';
import 'package:mkm/type.dart';

/// 【核心接口】MKM ID的地址
/// 地址是实体的唯一标识，由Meta（元数据）生成，包含网络类型（用户/群组/广播等）
abstract interface class Address implements Stringer {
  /// 获取地址的网络类型（对应EntityType：用户/群组/广播等）
  /// 返回值：如EntityType.USER(0x00)、EntityType.GROUP(0x01)
  int get network;

  /// 广播地址常量（特殊地址，用于全局/局部广播）
  /// ANYWHERE：任意地址（anyone@anywhere），局部广播
  /// EVERYWHERE：所有地址（everyone@everywhere），全局广播
  static final Address ANYWHERE = _BroadcastAddress('anywhere',EntityType.ANY);
  static final Address EVERYWHERE = _BroadcastAddress('everywhere',EntityType.EVERY);

  // -------------------------- 工厂方法 --------------------------
  /// 解析任意对象为地址（支持字符串/Map）
  static Address? parse(Object? address) {
    var ext = AccountExtensions();    // 获取账户国战单例
    return ext.addressHelper!.parseAddress(address);
  }

  /// 根据Meta（元数据）生成地址
  /// [meta]：实体的元数据（包含公钥）
  /// [network]：地址类型（如用户/群组，默认用户）
  static Address generate(Meta meta,[int? network]){
    var ext = AccountExtensions();
    return ext.addressHelper!.generateAddress(meta, network);
  }

  /// 获取地址工厂（用于自定义地址生成逻辑）
  static AddressFactory? getFactory() {
    var ext = AccountExtensions();
    return ext.addressHelper!.getAddressFactory();
  }
  
  /// 注册地址工厂（支持自定义地址生成规则）
  static void setFactory(AddressFactory factory) {
    var ext = AccountExtensions();
    ext.addressHelper!.setAddressFactory(factory);
  }
}

/// 【地址工厂接口】
/// 定义地址的生成/解析规范，不同算法（如BTC/ETH/MKM）需实现此接口
abstract interface class AddressFactory {
  /// 根据Meta和网络类型生成地址
  Address generateAddress(Meta meta, int? network);

  /// 解析字符串为地址（如Base58字符串转地址对象）
  Address? parseAddress(String address);
}

/// 【内部类】广播地址实现
/// 继承ConstantString（不可变字符串），实现Address接口，专用于广播地址
class _BroadcastAddress extends ConstantString implements Address{
  _BroadcastAddress(String value, this.type) : super(value);

  /// 私有成员：广播地址的网络类型(如EntityType.ANY/EVERY)
  final int type;

  /// 实现Address接口：获取地址的网络类型
  @override
  int get network => type;
}