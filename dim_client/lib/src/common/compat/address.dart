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

import 'package:dim_client/sdk.dart';
import 'package:dim_client/src/common/utils/cache.dart';

/// 兼容型地址工厂
/// 扩展BaseAddressFactory，支持解析多种格式地址并提供内存优化能力
class CompatibleAddressFactory extends BaseAddressFactory{
  
  /// 内存优化方法：收到内存警告时调用，移除50%缓存对象
  /// @return 剩余缓存对象数量
  int reduceMemory(){
    int finger = 0;
    finger = thanos(addresses, finger);
    return finger >> 1;
  }

  /// 解析地址字符串为Address对象
  /// @param address - 地址字符串
  /// @return 解析后的Address对象（null=解析失败）
  @override
  Address? parse(String address){
    int len = address.length;
    if (len == 0) {
      assert(false, 'address empty');
      return null;
    } else if (len == 8) {
      // 处理"anywhere"广播地址
      String lower = address.toLowerCase();
      if (lower == Address.ANYWHERE.toString()) {
        return Address.ANYWHERE;
      }
    } else if (len == 10) {
      // 处理"everywhere"广播地址
      String lower = address.toLowerCase();
      if (lower == Address.EVERYWHERE.toString()) {
        return Address.EVERYWHERE;
      }
    }
    Address? res;
    // 解析BTC地址（26-35位）
    if (26 <= len && len <= 35) {
      res = BTCAddress.parse(address);
    } 
    // 解析ETH地址（42位）
    else if (len == 42) {
      res = ETHAddress.parse(address);
    } 
    // 其他长度先标记为null
    else {
      res = null;
    }
    //
    //  TODO: 扩展支持其他类型地址解析
    //
    // 兼容处理：4-64位的未知地址格式，封装为UnknownAddress
    if (res == null && 4 <= len && len <= 64) {
      res = UnknownAddress(address);
    }
    assert(res != null, 'invalid address: $address');
    return res;
  }
}

/// 不支持的地址类型
/// 用于封装无法识别但符合长度要求的地址字符串
class UnknownAddress extends ConstantString implements Address {
  /// 构造方法
  /// @param string - 地址字符串
  UnknownAddress(super.string);

  /// 获取网络类型（固定返回0，对应EntityType.USER）
  @override
  int get network => 0;  // EntityType.USER;

}