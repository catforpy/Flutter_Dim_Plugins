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

/// 即时消息代理接口
/// 定义将【即时消息(明文)】加密转换为【安全消息(加密)】的核心方法，
/// 是消息加密流程的核心契约，具体加密算法（如AES/RSA）由实现类决定，
/// 支持不同加密策略的灵活扩展。
abstract interface class InstantMessageDelegate {
  /*
   *  加密即时消息为安全消息的流程
   *
   *    +----------+      +----------+
   *    | sender   |      | sender   |
   *    | receiver |      | receiver |
   *    | time     |  ->  | time     |
   *    |          |      |          |
   *    | content  |      | data     |  1. data = encrypt(content, 对称密钥)
   *    +----------+      | key/keys |  2. key  = encrypt(对称密钥, 接收方公钥)
   *                      +----------+
   */

  // -------------- 加密消息内容 --------------

  /// 步骤1：将消息内容序列化为二进制数据
  /// 核心逻辑：根据内容类型（文本/图片/音视频）选择序列化方式，
  /// 支持数据压缩（由对称密钥的压缩算法配置决定）。
  /// @param content  - 待序列化的消息内容（如文本、图片、文件等）
  /// @param password - 对称密钥（包含数据压缩算法、加密算法配置）
  /// @param iMsg     - 原始即时消息对象（包含收发方、时间戳等上下文）
  /// @return 序列化后的内容二进制数据（非空，序列化失败触发断言）
  Future<Uint8List> serializeContent(Content content, SymmetricKey password, InstantMessage iMsg);

  /// 步骤2：用对称密钥加密序列化后的内容数据，生成消息密文
  /// 核心逻辑：使用对称密钥的加密算法（如AES-256-CBC）加密内容，
  /// 保证消息内容的机密性，仅持有对称密钥的接收方可解密。
  /// @param data     - 序列化后的内容二进制数据（非空）
  /// @param password - 对称密钥（指定加密算法、模式、填充方式）
  /// @param iMsg     - 原始即时消息对象（上下文信息）
  /// @return 加密后的消息内容数据（非空，加密失败触发断言）
  Future<Uint8List> encryptContent(Uint8List data, SymmetricKey password, InstantMessage iMsg);

  // -------------- 加密对称密钥 --------------

  /// 步骤4：将对称密钥序列化为二进制数据
  /// 核心逻辑：
  /// - 单聊/群聊消息：序列化对称密钥，用于后续加密传输；
  /// - 广播消息/复用密钥场景：返回null，无需传输密钥；
  /// 序列化格式需与 decryptKey/deserializeKey 兼容。
  /// @param password - 待序列化的对称密钥（非空）
  /// @param iMsg     - 原始即时消息对象（区分单聊/群聊/广播）
  /// @return 序列化后的密钥二进制数据；广播消息/复用密钥时返回null
  Future<Uint8List?> serializeKey(SymmetricKey password, InstantMessage iMsg);

  /// 步骤5：用接收方公钥加密序列化后的密钥数据
  /// 核心逻辑：使用接收方公钥（RSA/ECDH）加密对称密钥，
  /// 保证密钥仅接收方（持有私钥）可解密，防止密钥泄露。
  /// @param key      - 序列化后的对称密钥二进制数据（非空）
  /// @param receiver - 实际接收方（个人/群成员，需为用户ID）
  /// @param iMsg     - 原始即时消息对象（上下文信息）
  /// @return 加密后的对称密钥数据；接收方公钥不存在/获取失败时返回null
  Future<Uint8List?> encryptKey(Uint8List key, ID receiver, InstantMessage iMsg);
}