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

/// 消息工具类
/// 提供消息中【元数据(Meta)】和【身份签证(Visa)】的读写方法，
/// 用于握手协议的首个消息包扩展（新用户首次通信时携带Meta/Visa），
/// 支持任意类型消息（Instant/Secure/ReliableMessage）的Meta/Visa操作。
abstract interface class MessageUtils{
  /// 获取消息中的发送者元数据
  /// 核心逻辑：从消息的'meta'字段解析为Meta对象，
  /// 元数据是用户身份的核心依据，仅在首次握手消息中携带。
  /// @param msg - 任意类型消息（Instant/Secure/ReliableMessage）
  /// @return 元数据对象；消息无meta字段/解析失败返回null
  static Meta? getMeta(Message msg) =>
      Meta.parse(msg['meta']);

  /// 向消息中设置发送者元数据
  /// 核心逻辑：将Meta对象序列化为Map，存入消息的'meta'字段，
  /// 仅在新用户首次发送消息时设置（用于接收方验证身份）。
  /// @param meta - 元数据对象（可为null，null表示移除meta字段）
  /// @param msg  - 任意类型消息（Instant/Secure/ReliableMessage）
  static void setMeta(Meta? meta, Message msg) =>
      msg.setMap('meta', meta);
  
  /// 获取消息中的发送者签证
  /// 核心逻辑：
  /// 1. 从消息的'visa'字段解析为Document对象；
  /// 2. 校验Document类型为Visa，非Visa类型返回null；
  /// 签证包含用户扩展信息（昵称/头像/公钥），用于密钥轮换。
  /// @param msg - 任意类型消息（Instant/Secure/ReliableMessage）
  /// @return 签证对象；消息无visa字段/类型错误返回null
  static Visa? getVisa(Message msg) {
    Document? doc = Document.parse(msg['visa']);
    if(doc is Visa){
      return doc;
    }
    assert(doc == null, '签证文档类型错误: $doc');
    return null;
  }

  /// 向消息中设置发送者签证
  /// 核心逻辑：将Visa对象序列化为Map，存入消息的'visa'字段，
  /// 用于密钥轮换场景（用户更新公钥后，携带新Visa通知联系人）。
  /// @param visa - 签证对象（可为null，null表示移除visa字段）
  /// @param msg  - 任意类型消息（Instant/Secure/ReliableMessage）
  static void setVisa(Visa? visa, Message msg) =>
      msg.setMap('visa', visa);
}