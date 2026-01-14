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


// 通用哈希计算方法（封装pointycastle的Digest接口）
import 'dart:typed_data';

import 'package:dim_plugins/dim_plugins.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/digests/keccak.dart';
import 'package:pointycastle/digests/ripemd160.dart';
import 'package:pointycastle/digests/sha256.dart';

Uint8List _hash(Uint8List data, Digest digester) {
  digester.reset(); // 重置摘要器
  return digester.process(data); // 计算哈希并返回
}

/// SHA256哈希实现类（实现DIMP的MessageDigester接口）
class SHA256Digester implements MessageDigester {

  // 计算数据的SHA256哈希
  @override
  Uint8List digest(Uint8List data) {
    return _hash(data, SHA256Digest()); // 调用pointycastle的SHA256实现
  }
}

/// KECCAK256哈希实现类（以太坊等区块链常用）
class KECCAK256Digester implements MessageDigester {

  @override
  Uint8List digest(Uint8List data) {
    return _hash(data, KeccakDigest(256)); // KECCAK256摘要器
  }
}

/// RIPEMD160哈希实现类（DIMP地址生成用）
class RIPEMD160Digester implements MessageDigester {

  @override
  Uint8List digest(Uint8List data) {
    return _hash(data, RIPEMD160Digest()); // RIPEMD160摘要器
  }
}

/* 
 * 【哈希类核心总结】
 * 1. 无密钥生成逻辑，仅提供哈希计算
 * 2. 核心用途：
 *    - SHA256：ECC/RSA签名验签的摘要算法
 *    - RIPEMD160：DIMP地址生成（公钥→SHA256→RIPEMD160）
 *    - KECCAK256：可选的哈希算法（区块链兼容）
 */