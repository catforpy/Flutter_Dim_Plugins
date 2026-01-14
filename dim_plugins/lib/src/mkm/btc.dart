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

/// BTC格式地址实现类比特币地址
/// 核心说明：
/// 数据格式："network+digest+code"
///   - network: 1字节（网络类型）
///   - digest: 20字节（RIPEMD160(SHA256(指纹))）
///   - check code: 4字节（校验码）
/// 生成算法：
///   1. 指纹 = 公钥数据 / 元数据指纹
///   2. 摘要 = RIPEMD160(SHA256(指纹))
///   3. 校验码 = SHA256(SHA256(network + 摘要)).前4字节
///   4. 地址 = Base58编码(network + 摘要 + 校验码)
class BTCAddress extends ConstantString implements Address{
  /// 构造方法：初始化地址字符串和网络类型
  /// [string] - 地址字符串（Base58格式）
  /// [network] - 网络类型（地址类型）
  BTCAddress(super.string, int network) : _type = network;

  /// 网络类型（地址类型）
  final int _type;

  /// 获取网络类型
  @override
  int get network => _type;

  /// 生成BTC地址（从指纹和网络类型）
  /// [fingerprint] - 元数据指纹 / 公钥数据
  /// [network] - 网络类型
  /// 返回值：BTC地址对象
  static BTCAddress generate(Uint8List fingerprint, int network) {
    // 1. 计算摘要：RIPEMD160(SHA256(指纹))
    Uint8List digest = RIPEMD160.digest(SHA256.digest(fingerprint));
    // 2. 拼接头部：network(1字节) + digest(20字节)
    BytesBuilder bb = BytesBuilder(copy: false);
    bb.addByte(network);
    bb.add(digest);
    Uint8List head = bb.toBytes();
    // 3. 计算校验码：SHA256(SHA256(head)).前4字节
    Uint8List cc = _checkCode(head);
    // 4. 拼接完整数据并Base58编码
    bb = BytesBuilder(copy: false);
    bb.add(head);
    bb.add(cc);
    return BTCAddress(Base58.encode(bb.toBytes()), network);
  }

  /// 解析字符串为BTC地址
  /// 补充说明：
  /// 1. 校验地址长度（26-35位）；
  /// 2. Base58解码后校验长度（25字节）；
  /// 3. 验证校验码；
  /// [address] - 地址字符串
  /// 返回值：BTC地址对象（解析失败返回null）
  static BTCAddress? parse(String address) {
    // 校验地址长度
    if (address.length < 26 || address.length > 35) {
      return null;
    }
    // Base58解码
    Uint8List? data = Base58.decode(address);
    // 校验解码后长度（必须25字节：1+20+4）
    if (data == null || data.length != 25) {
      return null;
    }
    // 拆分头部（21字节：network+digest）和校验码（4字节）
    Uint8List prefix = data.sublist(0, 21);
    Uint8List suffix = data.sublist(21, 25);
    // 计算校验码并验证
    Uint8List cc = _checkCode(prefix);
    if (Arrays.equals(cc, suffix)) {
      // 校验通过，创建BTC地址对象
      return BTCAddress(address, data[0]);
    } else {
      // 校验码不匹配
      return null;
    }
  }
}

/// 计算BTC地址校验码
/// [data] - 待校验数据（network + digest）
/// 返回值：4字节校验码
Uint8List _checkCode(Uint8List data) {
  // 双重SHA256后取前4字节
  return SHA256.digest(SHA256.digest(data)).sublist(0, 4);
}