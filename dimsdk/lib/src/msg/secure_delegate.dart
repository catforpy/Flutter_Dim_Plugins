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

/// 安全消息代理接口
/// 定义两大核心功能：
/// 1. 【安全消息→即时消息】的解密转换（接收方解密消息）；
/// 2. 【安全消息→可靠消息】的签名转换（发送方签名消息）；
/// 是消息解密、签名流程的核心契约，具体算法由实现类决定。
abstract interface class SecureMessageDelegate {
  /*
   *  解密安全消息为即时消息的流程
   *
   *    +----------+      +----------+
   *    | sender   |      | sender   |
   *    | receiver |      | receiver |
   *    | time     |  ->  | time     |
   *    |          |      |          |  1. 对称密钥 = decrypt(key, 接收方私钥)
   *    | data     |      | content  |  2. content = decrypt(data, 对称密钥)
   *    | key/keys |      +----------+
   *    +----------+
   */

  // -------------- 解密对称密钥 --------------

  /// 步骤2：用接收方私钥解密加密后的对称密钥
  /// 核心逻辑：使用接收方私钥（RSA/ECDH）解密对称密钥，
  /// 仅持有私钥的接收方可还原密钥，保证密钥安全性。
  /// @param key      - 加密后的对称密钥数据（Base64解码后的二进制，非空）
  /// @param receiver - 实际接收方（本地用户ID，需持有对应私钥）
  /// @param sMsg     - 安全消息对象（上下文信息）
  /// @return 解密后的密钥二进制数据；解密失败返回null
  Future<Uint8List?> decryptKey(Uint8List key, ID receiver, SecureMessage sMsg);

  /// 步骤3：反序列化密钥数据，还原对称密钥
  /// 核心逻辑：
  /// - 正常场景：将解密后的二进制数据反序列化为 SymmetricKey 对象；
  /// - 复用密钥场景：key为null时，从缓存中读取复用的密钥；
  /// 反序列化格式需与 serializeKey 兼容。
  /// @param key  - 解密后的密钥二进制数据；null表示复用缓存密钥
  /// @param sMsg - 安全消息对象（区分复用密钥场景）
  /// @return 对称密钥；密钥缓存缺失/反序列化失败时返回null
  Future<SymmetricKey?> deserializeKey(Uint8List? key, SecureMessage sMsg);

  // -------------- 解密消息内容 --------------

  /// 步骤5：用对称密钥解密密文数据，还原序列化内容
  /// 核心逻辑：使用对称密钥的解密算法（如AES-256-CBC）解密密文，
  /// 还原序列化后的内容数据，支持解压（由密钥的压缩算法配置决定）。
  /// @param data     - 加密后的消息密文（Base64解码后的二进制，非空）
  /// @param password - 对称密钥（与加密时的密钥一致）
  /// @param sMsg     - 安全消息对象（上下文信息）
  /// @return 解密后的内容二进制数据；解密失败返回null
  Future<Uint8List?> decryptContent(Uint8List data, SymmetricKey password, SecureMessage sMsg);

  /// 步骤6：反序列化内容数据，还原消息内容
  /// 核心逻辑：根据内容类型（文本/图片/音视频）反序列化二进制数据，
  /// 还原为 Content 对象，支持解压（由密钥的压缩算法配置决定）。
  /// @param data     - 解密后的内容二进制数据（非空）
  /// @param password - 对称密钥（包含解压算法配置）
  /// @param sMsg     - 安全消息对象（上下文信息）
  /// @return 消息内容对象；反序列化失败返回null
  Future<Content?> deserializeContent(Uint8List data, SymmetricKey password, SecureMessage sMsg);

  /*
   *  签名安全消息为可靠消息的流程
   *
   *    +----------+      +----------+
   *    | sender   |      | sender   |
   *    | receiver |      | receiver |
   *    | time     |  ->  | time     |
   *    |          |      |          |
   *    | data     |      | data     |
   *    | key/keys |      | key/keys |
   *    +----------+      | signature|  1. signature = sign(data, 发送方私钥)
   *                      +----------+
   */

  /// 步骤1：用发送方私钥对消息密文进行签名
  /// 核心逻辑：使用发送方私钥（RSA/ECDSA）对消息密文签名，
  /// 接收方可通过公钥验签，确认消息来源合法、未被篡改。
  /// @param data - 加密后的消息密文（Base64解码后的二进制，非空）
  /// @param sMsg - 安全消息对象（包含发送方ID，用于获取私钥）
  /// @return 消息签名数据（非空，签名失败触发断言）
  Future<Uint8List> signData(Uint8List data, SecureMessage sMsg);
}