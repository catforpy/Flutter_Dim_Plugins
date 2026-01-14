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

/// 明文密钥类（对称密钥的特例，无加密）
/// 用途：广播消息/公开消息（无需加密，兼容对称密钥接口）
class PlainKey extends BaseSymmetricKey {
  // 构造方法
  PlainKey([super.dict]);

  // 重写：空字节数据（无密钥）
  @override
  Uint8List get data => Uint8List(0);

  // 重写：解密=直接返回原数据
  @override
  Uint8List? decrypt(Uint8List ciphertext, [Map? params]) {
    return ciphertext;
  }

  // 重写：加密=直接返回原数据
  @override
  Uint8List encrypt(Uint8List plaintext, [Map? extra]) {
    return plaintext;
  }

  // 单例模式：全局唯一实例（避免重复创建）
  static final PlainKey _instance = PlainKey({'algorithm': SymmetricAlgorithms.PLAIN});
  factory PlainKey.getInstance() => _instance;
}

/// 明文密钥工厂类
class PlainKeyFactory implements SymmetricKeyFactory {

  // 生成明文密钥（返回单例）
  @override
  SymmetricKey generateSymmetricKey() {
    return PlainKey.getInstance();
  }

  // 解析明文密钥（返回单例）
  @override
  SymmetricKey? parseSymmetricKey(Map key) {
    return PlainKey.getInstance();
  }
}

/* 
 * 【明文密钥核心总结】
 * 1. 无密钥生成逻辑（单例，无随机数/密钥数据）
 * 2. 核心作用：兼容对称密钥接口，避免区分“加密/明文”消息的逻辑分支
 * 3. 所有加解密操作均透传数据，无任何处理
 */