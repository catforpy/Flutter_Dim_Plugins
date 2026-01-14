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

/* 
 * 许可证声明：MIT开源协议
 * 核心功能：封装各类哈希算法（SHA256/KECCAK256/RIPEMD160），提供统一的摘要计算接口 这个算法更多是用来做验签的 
 * 也就是说只是对数据生成指纹的作用。通过验证哈希值来检测数据是否被修改过，
 * 但是缺点是，如果数据被修改过，并且也用相同的哈希值进行指纹生成，那么这个验签就会失效，所以需要复合加密
 * 应用场景：非对称密钥地址生成（如公钥哈希生成地址）、数据完整性校验
 */

import 'dart:typed_data';

/// 【抽象接口】消息摘要器
/// 定义所有哈希算法的统一接口，实现类需提供具体的摘要计算逻辑
abstract interface class MessageDigester {
  /// 计算数据的哈希摘要
  /// [data]：原始二进制数据
  /// 返回：哈希后的字节数组（固定长度，如SHA256返回32字节）
  Uint8List digest(Uint8List data);
}

/// 【SHA256算法封装】
/// 用途：最常用的哈希算法，用于数据完整性校验、公钥哈希等
class SHA256{
  /// 静态方法：计算数据的SHA256摘要
  /// 核心逻辑：委托给自己注册的MessageDigester实现类处理
  static Uint8List digest(Uint8List data){
    return digester!.digest(data);
  }

  /// 静态成员：SHA256算法的具体实现器（延迟初始化，由外部注入）
  static MessageDigester? digester;
}

/// 【KECCAK256算法封装】
/// 用途：区块链常用哈希算法（如以太坊地址生成），区别于标准SHA3
class KECCAK256 {
  /// 静态方法：计算数据的KECCAK256摘要
  static Uint8List digest(Uint8List data) {
    return digester!.digest(data);
  }

  static MessageDigester? digester;
}

/// 【RIPEMD160算法封装】
/// 用途：加密货币/去中心化ID常用算法（如比特币地址生成），输出160位（20字节）摘要
class RIPEMD160 {
  /// 静态方法：计算数据的RIPEMD160摘要
  static Uint8List digest(Uint8List data) {
    return digester!.digest(data);
  }

  static MessageDigester? digester;
}