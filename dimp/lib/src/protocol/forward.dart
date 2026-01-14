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

import 'package:dimp/dkd.dart';

/// 密件转发消息接口
/// 作用：定义加密转发的消息结构，用于传递保密消息/批量秘密消息
/// 数据格式：{
///      type : i2s(0xFF),  // 消息类型标识（0xFF=密件）
///      sn   : 456,        // 消息序列号
///
///      forward : {...}  // 单条可靠消息（已加密+签名）
///      secrets : [...]  // 多条可靠消息列表
///  }
abstract interface class ForwardContent implements Content{
  /// 获取单条转发的可靠消息
  ReliableMessage? get forward;

  /// 获取批量转发的秘密消息列表
  List<ReliableMessage> get secrets;

  //-------- 工厂方法 --------
  /// 创建密件转发消息
  /// @param forward - 单条转发消息（二选一）
  /// @param secrets - 批量转发消息列表（二选一）
  /// @return 密件转发消息实例
  static ForwardContent create({ReliableMessage? forward,List<ReliableMessage>? secrets}){
    if(forward != null){
      assert(secrets == null, '参数错误：forward和secrets不能同时传');
      return SecretContent.fromMessage(forward);
    }else{
      assert(secrets != null, '参数错误：必须传forward或secrets');
      return SecretContent.fromMessages(secrets!);
    }
  }
}

/// 组合转发消息接口
/// 作用：定义聊天记录转发的消息结构，支持批量转发历史消息
/// 数据格式：{
///      type : i2s(0xCF),  // 消息类型标识（0xCF=组合转发）
///      sn   : 123,        // 消息序列号
///
///      title    : "...",  // 聊天标题（如“和XX的聊天记录”）
///      messages : [...]   // 明文消息列表（聊天历史）
///  }
abstract interface class CombineContent implements Content{
  /// 获取聊天标题
  String get title;

  /// 获取转发的消息列表
  List<InstantMessage> get messages;
  //-------- 工厂方法 --------
  /// 创建组合转发消息
  /// @param title    - 聊天标题
  /// @param messages - 明文消息列表
  /// @return 组合转发消息实例
  static CombineContent create(String title, List<InstantMessage> messages) =>
      CombineForwardContent.from(title, messages);
}

/// 内容数组消息接口
/// 作用：定义多内容组合的消息结构，支持一条消息包含多个不同类型的内容
/// 数据格式：{
///      type : i2s(0xCA),  // 消息类型标识（0xCA=内容数组）
///      sn   : 123,        // 消息序列号
///
///      contents : [...]  // 内容列表（可包含文本/图片/文件等）
///  }
abstract interface class ArrayContent implements Content{
  /// 获取内容列表
  List<Content> get contents;

  //-------- 工厂方法 --------
  /// 创建内容数组消息
  /// @param contents - 内容列表
  /// @return 内容数组消息实例
  static ArrayContent create(List<Content> contents) =>
      ListContent.fromContents(contents);
}