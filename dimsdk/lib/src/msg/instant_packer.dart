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

/// 即时消息打包器
/// 实现【即时消息→安全消息】的加密转换逻辑，
/// 封装消息加密的完整流程，依赖 InstantMessageDelegate 完成具体的
/// 序列化、加密操作，解耦流程控制与算法实现。
class InstantMessagePacker {
  /// 构造方法：传入消息代理（用弱引用避免内存泄漏）
  /// @param messenger - 即时消息代理（提供序列化/加密核心实现）
  InstantMessagePacker(InstantMessageDelegate messenger)
      : _messenger = WeakReference(messenger);
  
  /// 弱引用持有消息代理
  /// 避免循环引用导致的内存泄漏（如代理持有打包器实例）
  final WeakReference<InstantMessageDelegate> _messenger;

  /// 获取消息代理实例（可能为Null,需判空）
  /// @return即时消息代理实例；代理被回收时返回null
  InstantMessageDelegate? get delegate => _messenger.target;

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

  /// 加密消息：将明文内容替换为加密数据，生成安全消息
  /// 核心流程：
  /// 1. 序列化并加密消息内容 → 生成 data 字段；
  /// 2. 序列化并加密对称密钥 → 生成 key（单聊）/keys（群聊）字段；
  /// 3. 移除明文 content，组装为安全消息。
  /// @param iMsg     - 原始即时消息（明文，包含content字段）
  /// @param password - 对称加密密钥（用于加密内容）
  /// @param members  - 群聊成员列表（群消息时必填，单聊传null）
  /// @return 安全消息对象（包含data、key/keys字段）；接收方公钥缺失时返回null
  Future<SecureMessage?> encryptMessage(InstantMessage iMsg,SymmetricKey password,{List<ID>? members}) async{
    // TODO: 处理文件/图片/音视频消息的附件（由上层应用实现）
    // 获取消息代理（核心算法实现）
    InstantMessageDelegate? transceiver = delegate;
    if(transceiver == null){
      assert(false, '消息代理不能为空');
      return null;
    }

    // 1.将消息内容转化为二进制数据
    Uint8List body = await transceiver.serializeContent(iMsg.content, password, iMsg);
    assert(body.isNotEmpty, '内容序列化失败: ${iMsg.content}');

    // 2.用对称密钥加密内容数据，生成密文
    Uint8List ciphertext = await transceiver.encryptContent(body, password, iMsg);
    assert(ciphertext.isNotEmpty, '内容加密失败，密钥: $password');

    // 3.编码密文数据（广播消息特殊处理：仅UTF8编码，不加密）
    Object? encodedData;
    if(BaseMessage.isBroadcast(iMsg)){
      // 广播消息内容不加密，仅UTF8编码（所有接收方可读取）
      encodedData = UTF8.decode(ciphertext);
    }else{
      // 普通消息密文用Base64编码（便于JSON传输）
      encodedData = TransportableData.encode(ciphertext);
    }
    assert(encodedData != null, '密文编码失败: $ciphertext');

    // 替换消息字段：移除明文content，添加加密data
    Map info = iMsg.copyMap();
    info.remove('content');
    info['data'] = encodedData;

    // 4.序列化对称秘钥（广播/复用秘钥场景返回null）
    Uint8List? pwd = await transceiver.serializeKey(password, iMsg);
    if(pwd == null){
      // 无秘钥：广播消息/复用秘钥，直接返回安全消息
      return SecureMessage.parse(info);
    }

    // --------------- 处理密钥加密 ---------------
    Uint8List? encryptedKey;
    Object encodedKey;
    if(members == null){
      // 单聊消息：加密密钥存入key字段
      ID receiver = iMsg.receiver;
      assert(receiver.isUser, '单聊接收方必须是用户: $receiver');
      // 5.用接收方公钥加密秘钥
      encryptedKey = await transceiver.encryptKey(pwd, receiver, iMsg);
      if(encryptedKey == null){
        // 接收方公钥缺失，无法加密密钥（需先获取对方签证）
        return null;
      }
      // 6.Base64编码加密后的秘钥（便于JSON传输）
      encodedKey = TransportableData.encode(encryptedKey);
      info['key'] = encodedKey;
    }else{
      // 群聊消息：为每个成员加密密钥，存入keys字段（key=成员ID，value=加密密钥）
      Map<String,dynamic> keys = {};
      for(ID receiver in members){
        // 5.用群成员公钥加密秘钥（每个成员的秘钥加密结果不同）
        encryptedKey = await transceiver.encryptKey(pwd, receiver, iMsg);
        if(encryptedKey == null){
          // 获取密钥加密公钥失败
          continue;
        }
        // 6.Base64编码加密后的秘钥
        encodedKey = TransportableData.encode(encryptedKey);
      }
      if(keys.isEmpty){
        // 所有成员公钥都确实（无法发送群消息）
        return null;
      }
      info['keys'] = keys;
    }

    // 生成安全消息并返回（解析Map为secureMessage对象）
    return SecureMessage.parse(info);
  }
}