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

/// DIM 协议对称密钥管理接口
/// 核心作用：负责消息加密所需对称密钥的获取、缓存，是消息安全的核心组件，
/// 解决“不同场景（单聊/群聊/广播）该用哪个密钥”的问题，同时避免重复生成密钥，保证加密一致性。
/// 核心能力：
/// 1. 密钥目标计算：getDestination 确定消息对应的密钥目标 ID；
/// 2. 密钥获取/生成：getCipherKey 获取缓存密钥，不存在时可生成；
/// 3. 密钥缓存：cacheCipherKey 缓存密钥，避免重复生成。
abstract interface class CipherKeyDelegate {

  /*  密钥目标计算场景矩阵：
                      +-------------+-------------+-------------+-------------+
                      |  receiver   |  receiver   |  receiver   |  receiver   |
                      |     is      |     is      |     is      |     is      |
                      |             |             |  broadcast  |  broadcast  |
                      |    user     |    group    |    user     |    group    |
        +-------------+-------------+-------------+-------------+-------------+
        |             |      A      |             |             |             |
        |             +-------------+-------------+-------------+-------------+
        |    group    |             |      B      |             |             |
        |     is      |-------------+-------------+-------------+-------------+
        |    null     |             |             |      C      |             |
        |             +-------------+-------------+-------------+-------------+
        |             |             |             |             |      D      |
        +-------------+-------------+-------------+-------------+-------------+
        |             |      E      |             |             |             |
        |             +-------------+-------------+-------------+-------------+
        |    group    |             |             |             |             |
        |     is      |-------------+-------------+-------------+-------------+
        |  broadcast  |             |             |      F      |             |
        |             +-------------+-------------+-------------+-------------+
        |             |             |             |             |      G      |
        +-------------+-------------+-------------+-------------+-------------+
        |             |      H      |             |             |             |
        |             +-------------+-------------+-------------+-------------+
        |    group    |             |      J      |             |             |
        |     is      |-------------+-------------+-------------+-------------+
        |    normal   |             |             |      K      |             |
        |             +-------------+-------------+-------------+-------------+
        |             |             |             |             |             |
        +-------------+-------------+-------------+-------------+-------------+
     */

  /// 根据消息计算密钥目标 ID
  /// 核心逻辑：解析消息的接收者、群组字段，调用 getDestination 确定密钥目标，
  /// 解决“该用哪个密钥加密/解密消息”的问题。
  /// @param msg - 待处理的消息（InstantMessage/SecureMessage 等）
  /// @return 密钥目标 ID（用于获取对应的对称密钥）
  static ID getDestinationForMessage(Message msg) =>
      getDestination(receiver: msg.receiver, group: ID.parse(msg['group']));
  
  /// 根据接收者和群组计算密钥目标 ID
  /// 核心逻辑：
  /// 1. 若群组为空且接收者是群组 → 群组=接收者（B→J、D→G）；
  /// 2. 若群组为空 → 目标=接收者（A/C，单聊/广播）；
  /// 3. 若群组是广播 → 目标=群组（E/F/G，广播消息不加密）；
  /// 4. 若接收者是广播 → 目标=接收者（K，群组消息不加密）；
  /// 5. 其他场景 → 目标=群组（H/J，群组消息用群组密钥）。
  /// @param receiver - 消息接收者 ID
  /// @param group - 消息所属群组 ID（可为 null）
  /// @return 密钥目标 ID
  static ID getDestination({required ID receiver, required ID? group}){
    if(group == null && receiver.isGroup){
      /// 转换规则：接受这是群组 -> 群组=接收者 （B->J、D->G）
      group = receiver;
    }
    if(group == null){
      /// 场景 A/C：单聊/广播消息，目标=接收者（必须是用户类型）
      assert(receiver.isUser, 'receiver error: $receiver');
      return receiver;
    }
    assert(group.isGroup, 'group error: $group, receiver: $receiver');
    if(group.isBroadcast){
      /// 场景 E/F/G：广播群组，目标=群组（禁用加密）
      assert(receiver.isUser || receiver == group, 'receiver error: $receiver');
      return group;
    }else if(receiver.isBroadcast){
      /// 场景 K：广播接收者，目标=接收者（禁用加密）
      assert(receiver.isUser, 'receiver error: $receiver, group: $group');
      return receiver;
    }else{
      /// 场景 H/J：普通群组，目标=群组（用群组密钥）
      return group;
    }
  }

  /// 获取发送者→接收者的对称密钥
  /// 核心逻辑：优先从缓存读取，缓存未命中时可根据 generate 参数生成新密钥。
  /// @param sender - 消息发送者 ID
  /// @param receiver - 密钥目标 ID（由 getDestination 计算）
  /// @param generate - 无缓存时是否生成新密钥（true=生成，false=返回 null）
  /// @return 对称密钥；无缓存且不生成返回 null
  Future<SymmetricKey?> getCipherKey({required ID sender, required ID receiver,
                                      bool generate = false});

  /// 缓存发送者→接收者的对称密钥
  /// 核心逻辑：将密钥存入缓存，后续调用 getCipherKey 可直接获取，避免重复生成。
  /// @param sender - 消息发送者 ID
  /// @param receiver - 密钥目标 ID
  /// @param key - 待缓存的对称密钥
  Future<void> cacheCipherKey({required ID sender, required ID receiver,
                               required SymmetricKey key});
}