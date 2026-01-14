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

import 'package:dimsdk/dimp.dart';

/// DIM 协议消息包装接口
/// 核心作用：定义消息全生命周期的转换流程，是 DIM 消息安全传输的核心接口，
/// 正向流程（发送）：明文消息 → 加密 → 签名 → 序列化 → 网络传输；
/// 逆向流程（接收）：网络数据 → 反序列化 → 验签 → 解密 → 明文消息。
/// 核心消息类型：
/// - InstantMessage：明文消息（业务层构建）；
/// - SecureMessage：加密消息（明文加密后）；
/// - ReliableMessage：可靠消息（加密后签名，网络传输用）。
abstract interface class Packer{
  // ======================== 正向流程：明文 → 可靠消息 ========================

  /// 加密明文消息为安全消息
  /// 核心逻辑：用对称密钥加密 InstantMessage 的内容，生成 SecureMessage，
  /// 包含加密后的内容和加密密钥（用接收方公钥加密）。
  /// @param iMsg - 明文消息（InstantMessage）
  /// @return 加密后的安全消息；加密失败返回 null
  Future<SecureMessage?> encryptMessage(InstantMessage iMsg);

  /// 签名安全消息为可靠消息
  /// 核心逻辑：用发送方私钥签名 SecureMessage 的内容，生成 ReliableMessage，
  /// 包含签名信息，保证消息不可篡改、可溯源。
  /// @param sMsg - 加密后的安全消息（SecureMessage）
  /// @return 签名后的可靠消息；签名失败返回 null
  Future<ReliableMessage?> signMessage(SecureMessage sMsg);

  // ======================== 逆向流程：可靠消息 → 明文 ========================

  /// 验证可靠消息签名，还原为安全消息
  /// 核心逻辑：用发送方公钥验证 ReliableMessage 的签名，验证通过后还原为 SecureMessage，
  /// 保证消息未被篡改、发送方身份合法。
  /// @param rMsg - 网络接收的可靠消息（ReliableMessage）
  /// @return 验证后的安全消息；验签失败返回 null
  Future<SecureMessage?> verifyMessage(ReliableMessage rMsg);

  /// 解密密文消息，还原为明文消息
  /// 核心逻辑：用对称密钥解密 SecureMessage 的内容，还原为 InstantMessage，
  /// 得到业务可解析的明文内容。
  /// @param sMsg - 验证后的安全消息（SecureMessage）
  /// @return 解密后的明文消息；解密失败返回 null
  Future<InstantMessage?> decryptMessage(SecureMessage sMsg);
}