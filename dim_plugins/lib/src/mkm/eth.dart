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

/// ETH格式地址实现类以太坊地址
/// 核心说明：
/// 数据格式："0x{address}"（42字符：0x + 40位十六进制）
/// 生成算法：
///   1. 指纹 = 公钥数据（64字节，去掉前缀0x04）
///   2. 摘要 = KECCAK256(指纹)
///   3. 地址 = 十六进制编码(摘要最后20字节) + EIP55大小写规范
class ETHAddress extends ConstantString implements Address {

  /// 构造方法：初始化地址字符串
  /// [string] - ETH地址字符串（0x开头）
  ETHAddress(super.string);

  /// 获取网络类型（固定为用户类型）
  @override
  int get network => EntityType.USER;

  /// 获取规范化的ETH地址（EIP55格式）
  /// [address] - 原始ETH地址
  /// 返回值：规范化地址（失败返回null）
  static String? getValidateAddress(String address) {
    if (!_ETH.isETH(address)) {
      // 不是合法的ETH地址格式
      return null;
    }
    // 提取0x后的部分并转为小写
    String lower = address.substring(2).toLowerCase();
    // 应用EIP55规范
    String eip55 = _ETH.eip55(lower);
    return '0x$eip55';
  }

  /// 验证ETH地址是否符合EIP55规范
  /// [address] - ETH地址字符串
  /// 返回值：是否合法
  static bool isValidate(String address) {
    String? validate = getValidateAddress(address);
    return validate != null && validate == address;
  }

  /// 生成ETH地址（从公钥指纹）
  /// [fingerprint] - 公钥数据（64/65字节）
  /// 返回值：ETH地址对象
  static ETHAddress generate(Uint8List fingerprint) {
    if (fingerprint.length == 65) {
      // 65字节公钥：去掉前缀字节（0x04）
      fingerprint = fingerprint.sublist(1);
    }
    // 校验公钥长度（必须64字节）
    assert(fingerprint.length == 64, 'key data error: ${fingerprint.length}');
    // 1. 计算KECCAK256摘要
    Uint8List digest = KECCAK256.digest(fingerprint);
    // 2. 取最后20字节并转为十六进制
    Uint8List tail = digest.sublist(digest.length - 20);
    // 3. 应用EIP55规范并添加0x前缀
    String address = _ETH.eip55(Hex.encode(tail));
    return ETHAddress('0x$address');
  }

  /// 解析字符串为ETH地址
  /// [address] - 地址字符串
  /// 返回值：ETH地址对象（解析失败返回null）
  static ETHAddress? parse(String address) {
    if (!_ETH.isETH(address)) {
      // 不是合法的ETH地址格式
      return null;
    }
    return ETHAddress(address);
  }
}

/// ETH地址工具类（内部使用）
class _ETH {

  /// EIP55地址大小写规范实现
  /// 参考：https://eips.ethereum.org/EIPS/eip-55
  /// [hex] - 40位小写十六进制字符串
  /// 返回值：EIP55规范的地址字符串
  static String eip55(String hex) {
    StringBuffer sb = StringBuffer();
    // 计算字符串的KECCAK256哈希
    Uint8List hash = KECCAK256.digest(UTF8.encode(hex));
    int ch;
    for (int i = 0; i < 40; ++i) {
      ch = hex.codeUnitAt(i);
      if (ch > _c9) {
        // 字母字符：根据哈希值决定大小写
        // 检查哈希对应位是否为1，若是则转为大写
        ch -= (hash[i >> 1] << (i << 2 & 4) & 0x80) >> 2;
      }
      sb.writeCharCode(ch);
    }
    return sb.toString();
  }

  /// 检查是否为合法的ETH地址格式
  /// [address] - 地址字符串
  /// 返回值：是否合法
  static bool isETH(String address) {
    // 长度必须42位
    if (address.length != 42) {
      return false;
    }
    // 必须以0x开头
    if (address.codeUnitAt(0) != _c0 || address.codeUnitAt(1) != _cx) {
      return false;
    }
    // 检查后续40位是否为十六进制字符
    int ch;
    for (int i = 2; i < 42; ++i) {
      ch = address.codeUnitAt(i);
      if (ch >= _c0 && ch <= _c9) {
        continue; // 数字0-9
      }
      if (ch >= _cA && ch <= _cZ) {
        continue; // 大写字母A-Z
      }
      if (ch >= _ca && ch <= _cz) {
        continue; // 小写字母a-z
      }
      // 包含非法字符
      return false;
    }
    return true;
  }

  // 字符编码常量
  static final int _c0 = '0'.codeUnitAt(0);
  static final int _c9 = '9'.codeUnitAt(0);
  static final int _cA = 'A'.codeUnitAt(0);
  static final int _cZ = 'Z'.codeUnitAt(0);
  static final int _ca = 'a'.codeUnitAt(0);
  static final int _cx = 'x'.codeUnitAt(0);
  static final int _cz = 'z'.codeUnitAt(0);
}