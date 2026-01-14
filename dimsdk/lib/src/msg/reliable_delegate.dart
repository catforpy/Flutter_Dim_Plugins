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

import 'package:dimsdk/dimp.dart';

/// 可靠消息代理接口
/// 定义将【可靠消息(带签名)】验签转换为【安全消息(加密)】的核心方法，
/// 验签逻辑由实现类完成（如RSA/ECDSA验签），保证消息来源的合法性。
abstract interface class ReliableMessageDelegate{

  /*
   *  验证可靠消息为安全消息的流程
   *
   *    +----------+      +----------+
   *    | sender   |      | sender   |
   *    | receiver |      | receiver |
   *    | time     |  ->  | time     |
   *    |          |      |          |
   *    | data     |      | data     |  1. verify(data, signature, 发送方公钥)
   *    | key/keys |      | key/keys |
   *    | signature|      +----------+
   *    +----------+
   */

  /// 步骤2：用发送方公钥验证消息数据和签名的一致性
  /// 核心逻辑：
  /// 1. 获取发送方公钥（从元数据/签证文档中读取）；
  /// 2. 使用公钥验证 signature 是否为 data 的合法签名；
  /// 3. 验签通过则确认消息未被篡改、来源合法。
  /// @param data      - 加密后的消息内容数据（非空）
  /// @param signature - 消息签名数据（发送方私钥对data的签名，非空）
  /// @param rMsg      - 可靠消息对象（包含发送方ID，用于获取公钥）
  /// @return 验签通过返回true，否则返回false
  Future<bool> verifyDataSignature(Uint8List data, Uint8List signature, ReliableMessage rMsg);
}