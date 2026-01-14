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

import 'package:dkd/dkd.dart';

/// 即时消息接口
/// ~~~~~~~~~~~~~~~
/// 未加密的原始消息，包含完整的信封和内容（明文）
///
/// 数据格式(JSON)：
/// {
///     //-- 信封字段
///     sender   : "moki@xxx",
///     receiver : "hulk@yyy",
///     time     : 123,
///     //-- 内容字段
///     content  : {...}
/// }
abstract interface class InstantMessage implements Message {
  
  /// 【只读】消息内容（明文）
  Content get content;
  // // 仅用于重建内容时修改
  // set content(Content body);

  //
  //  便捷方法
  //

  /// 将对象数组转换为 InstantMessage 列表
  /// [array] - 待转换的对象数组（每个元素为Map/JSON）
  /// 返回：InstantMessage 列表（过滤掉转换失败的元素）
  static List<InstantMessage> convert(Iterable array){
    List<InstantMessage> messages = [];
    InstantMessage? msg;
    for(var item in array){
      msg = parse(item);
      if(msg == null) continue;
      messages.add(msg);
    }
    return messages;
  }

  /// 将 InstantMessage 列表转换为 Map 数组
  /// [messages] - InstantMessage 列表
  /// 返回：Map 数组（每个元素为InstantMessage的JSON映射）
  static List<Map> revert(Iterable<InstantMessage> messages){
    List<Map> array = [];
    for(InstantMessage msg in messages){
      array.add(msg.toMap());
    }
    return array;
  }

  //
  //  工厂方法
  //

  /// 创建即时消息
  /// [head] - 消息信封
  /// [body] - 消息内容
  /// 返回：InstantMessage 实例
  static InstantMessage create(Envelope head, Content body) {
    var ext = MessageExtensions();
    return ext.instantHelper!.createInstantMessage(head, body);
  }

  /// 解析对象为 InstantMessage 实例
  /// [msg] - 待解析对象（Map/JSON字符串）
  /// 返回：InstantMessage 实例（解析失败返回null）
  static InstantMessage? parse(Object? msg) {
    var ext = MessageExtensions();
    return ext.instantHelper!.parseInstantMessage(msg);
  }

  /// 生成消息序列号（SN）
  /// [msgType] - 消息类型（可选）
  /// [now] - 消息时间（可选，默认当前时间）
  /// 返回：uint64 类型的序列号（作为消息ID）
  static int generateSerialNumber([String? msgType, DateTime? now]) {
    var ext = MessageExtensions();
    return ext.instantHelper!.generateSerialNumber(msgType, now);
  }

  /// 获取即时消息工厂
  /// 返回：InstantMessageFactory 实例（未设置返回null）
  static InstantMessageFactory? getFactory() {
    var ext = MessageExtensions();
    return ext.instantHelper!.getInstantMessageFactory();
  }
  
  /// 设置即时消息工厂
  /// [factory] - 即时消息工厂实例
  static void setFactory(InstantMessageFactory factory) {
    var ext = MessageExtensions();
    ext.instantHelper!.setInstantMessageFactory(factory);
  }
}

/// 即时消息工厂接口
/// ~~~~~~~~~~~~~~~
/// 定义即时消息的创建/解析、序列号生成规则
abstract interface class InstantMessageFactory {

  /// 为消息内容生成序列号（SN）
  /// [msgType] - 内容类型
  /// [now] - 消息时间
  /// 返回：uint64 类型的序列号（作为消息ID）
  int generateSerialNumber(String? msgType, DateTime? now);

  /// 创建即时消息
  /// [head] - 消息信封
  /// [body] - 消息内容
  /// 返回：InstantMessage 实例
  InstantMessage createInstantMessage(Envelope head, Content body);

  /// 将Map对象解析为 InstantMessage 实例
  /// [msg] - 消息信息（Map/JSON）
  /// 返回：InstantMessage 实例（解析失败返回null）
  InstantMessage? parseInstantMessage(Map msg);
}