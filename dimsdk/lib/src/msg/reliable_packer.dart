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
import 'package:dimsdk/msg.dart';

/// 可靠消息打包器
/// 实现【可靠消息→安全消息】的验签转换逻辑，
/// 封装消息验签的完整流程，依赖 ReliableMessageDelegate 完成具体的
/// 验签操作，确保消息来源合法、未被篡改。
class ReliableMessagePacker {
  /// 构造方法：传入消息代理（弱引用避免内存泄漏）
  /// @param messenger - 可靠消息代理（提供验签核心实现）
  ReliableMessagePacker(ReliableMessageDelegate messenger)
      : _messenger = WeakReference(messenger);

  /// 弱引用持有消息代理
  /// 避免循环引用导致的内存泄漏
  final WeakReference<ReliableMessageDelegate> _messenger;
  
  /// 获取消息代理实例
  /// @return 可靠消息代理实例；代理被回收时返回null
  ReliableMessageDelegate? get delegate => _messenger.target;

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

  /// 验签消息：验证data和signature的一致性，生成安全消息
  /// 核心流程：
  /// 1. 解码消息密文和签名数据；
  /// 2. 调用代理验签 → 确认消息来源合法；
  /// 3. 移除签名字段，组装为安全消息。
  /// @param rMsg - 可靠消息（带signature字段，包含data、key/keys）
  /// @return 安全消息对象（移除signature字段）；验签失败返回null
  Future<SecureMessage?> verifyMessage(ReliableMessage rMsg) async{
    // 获取消息代理（验签算法实现）
    ReliableMessageDelegate? transceiver = delegate;
    if (transceiver == null) {
      assert(false, '消息代理不能为空');
      return null;
    }

    // 0.解码消息密文数据（从Base64/UTF8还原为二进制）
    Uint8List ciphertext = rMsg.data;
    if (ciphertext.isEmpty) {
      assert(false, '消息密文解码失败: ${rMsg.sender} => ${rMsg.receiver}');
      return null;
    }

    // 1.解码消息签名数据（从Base64还原为二进制）
    Uint8List signature = rMsg.signature;
    if (signature.isEmpty) {
      assert(false, '消息签名解码失败: ${rMsg.sender} => ${rMsg.receiver}');
      return null;
    }

    // 2.用发送方公钥验证密文和签名的一致性
    bool ok = await transceiver.verifyDataSignature(ciphertext, signature, rMsg);
    if (!ok) {
      assert(false, '消息验签失败: ${rMsg.sender} => ${rMsg.receiver}');
      return null;
    }

    // 移除签名字段，生成安全消息（验签通过后无需保留signature）
    Map info = rMsg.copyMap();
    info.remove('signature');
    return SecureMessage.parse(info);
  }
}