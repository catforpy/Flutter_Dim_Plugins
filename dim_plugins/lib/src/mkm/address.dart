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

import 'package:dim_plugins/dim_plugins.dart';

/// 基础地址工厂类
/// 核心作用：
/// 1. 实现AddressFactory接口，提供地址的生成/解析能力；
/// 2. 内置缓存机制，避免重复创建相同地址对象；
/// 3. 支持多类型地址解析（BTC/ETH/特殊地址）；
class BaseAddressFactory implements AddressFactory {
  
  // 地址缓存池：key=地址字符串，value=Address对象（避免重复创建）
  // protected
  final Map<String, Address> addresses = {};

  /// 生成地址（从Meta元数据）
  /// [meta] - 身份元数据
  /// [network] - 网络类型（地址类型）
  /// 返回值：生成的地址对象
  @override
  Address generateAddress(Meta meta, int? network){
    // 调用Meta的地址生成方法
    Address address = meta.generateAddress(network);

    // 缓存地址对象
    addresses[address.toString()] = address;
    return address;
  }

  /// 解析地址字符串为地址对象
  /// 补充说明：优先从缓存获取，缓存未命中则解析并缓存；
  /// [address] - 地址字符串
  /// 返回值：地址对象（解析失败返回null）
  @override
  Address? parseAddress(String address){
    // 优先从缓存中获取
    Address? res = addresses[address];
    if(res == null){
      // 缓存为命中，解析地址
      res = parse(address);
      if (res != null) {
        // 解析成功，加入缓存
        addresses[address] = res;
      }
    }
    return res;
  }

  /// 内部解析方法：根据地址长度/格式识别地址类型
  /// [address] - 地址字符串
  /// 返回值：地址对象（解析失败返回null）
  // protected
  Address? parse(String address) { 
    int len = address.length;
    if(len == 0){
      // 地址不能为空
      assert(false, 'address should not be empty');
      return null;
    }else if(len == 8){
      // 8位地址：检查是否为"anywhere"（任意地址）
      if (address.toLowerCase() == Address.ANYWHERE.toString()) {
        return Address.ANYWHERE;
      }
    }else if(len == 10){
      // 10位地址：检查是否为"everywhere"（全网地址）
      if (address.toLowerCase() == Address.EVERYWHERE.toString()) {
        return Address.EVERYWHERE;
      }
    }
    Address? res;
    // 26-35位：BTC地址
    if (26 <= len && len <= 35) {
      res = BTCAddress.parse(address);
    } else if (len == 42) {
      // 42位：ETH地址（0x开头+40位十六进制）
      res = ETHAddress.parse(address);
    } else {
      // 无效地址长度
      assert(false, 'invalid address: $address');
      res = null;
    }
    // TODO: 扩展支持其他类型地址
    assert(res != null, 'invalid address: $address');
    return res;
  }
}