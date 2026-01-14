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

import 'package:dkd/dkd.dart';

/// 可靠消息接口
/// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
/// 对安全消息进行签名后的消息，包含发送方的数字签名，用于验证消息完整性和真实性
///
/// 数据格式(JSON)：
/// {
///     //-- 信封字段
///     sender   : "moki@xxx",
///     receiver : "hulk@yyy",
///     time     : 123,
///     //-- 安全消息字段（加密后的内容和密钥）
///     data     : "...",  // base64编码的加密内容（对称加密）
///     key      : "...",  // base64编码的加密密钥（非对称加密）
///     keys     : {
///         "ID1": "key1", // 多接收方时，每个接收方的加密密钥
///     },
///     //-- 签名字段（核心扩展）
///     signature: "..."   // base64编码的数字签名（发送方私钥签名data）
/// }
abstract interface class ReliableMessage implements SecureMessage{
  /// 【只读】数字签名（发送方私钥对data的签名）
  Uint8List get signature;

  //
  //  便捷方法
  //

  /// 将对象数组转换为 ReliableMessage 列表
  /// [array] - 待转换的对象数组（每个元素为Map/JSON）
  /// 返回：ReliableMessage 列表（过滤掉转换失败的元素）
  static List<ReliableMessage> convert(Iterable array) {
    List<ReliableMessage> messages = [];
    ReliableMessage? msg;
    for (var item in array) {
      msg = parse(item);
      if (msg == null) {
        continue;
      }
      messages.add(msg);
    }
    return messages;
  }

  /// 将 ReliableMessage 列表转换为 Map 数组
  /// [messages] - ReliableMessage 列表
  /// 返回：Map 数组（每个元素为ReliableMessage的JSON映射）
  static List<Map> revert(Iterable<ReliableMessage> messages) {
    List<Map> array = [];
    for (ReliableMessage msg in messages) {
      array.add(msg.toMap());
    }
    return array;
  }

  //
  //  工厂方法
  //

  /// 解析对象为 ReliableMessage 实例
  /// [msg] - 待解析对象（Map/JSON字符串）
  /// 返回：ReliableMessage 实例（解析失败返回null）
  static ReliableMessage? parse(Object? msg) {
    var ext = MessageExtensions();
    return ext.reliableHelper!.parseReliableMessage(msg);
  }

  /// 获取可靠消息工厂
  /// 返回：ReliableMessageFactory 实例（未设置返回null）
  static ReliableMessageFactory? getFactory() {
    var ext = MessageExtensions();
    return ext.reliableHelper!.getReliableMessageFactory();
  }
  
  /// 设置可靠消息工厂
  /// [factory] - 可靠消息工厂实例
  static void setFactory(ReliableMessageFactory factory) {
    var ext = MessageExtensions();
    ext.reliableHelper!.setReliableMessageFactory(factory);
  }
}

/// 可靠消息工厂接口
/// ~~~~~~~~~~~~~~~
/// 定义可靠消息的解析规则
abstract interface class ReliableMessageFactory {

  /// 将Map对象解析为 ReliableMessage 实例
  /// [msg] - 消息信息（Map/JSON）
  /// 返回：ReliableMessage 实例（解析失败返回null）
  ReliableMessage? parseReliableMessage(Map msg);
}