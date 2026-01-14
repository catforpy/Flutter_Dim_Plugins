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

///  CPU: Content Processing Unit
///  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
///  内容处理器核心接口，定义所有内容处理器必须实现的处理逻辑
abstract interface class ContentProcessor{
  ///  处理接收到的消息内容
  ///
  /// @param content - 接收到的内容对象
  /// @param rMsg    - 对应的可信消息（包含完整上下文：发送者/接收者/时间等）
  /// @return 要返回给发送者的响应内容列表
  Future<List<Content>> processContent(Content content,ReliableMessage rMsg);
}

///  CPU Creator
///  ~~~~~~~~~~~
///  处理器创建者接口，定义处理器的创建规范，将创建逻辑与使用逻辑解耦
abstract interface class ContentProcessorCreator{

  ///  根据内容类型创建普通内容处理器
  ///
  /// @param msgType - 内容类型（Content.type）
  /// @return 对应的内容处理器，无匹配则返回null
  ContentProcessor? createContentProcessor(String msgType);

  ///  根据内容类型+指令名创建指令处理器
  ///
  /// @param msgType - 内容类型（Content.type，指令类型固定为"command"）
  /// @param cmdName - 指令名（Command.cmd）
  /// @return 对应的指令处理器，无匹配则返回null
  ContentProcessor? createCommandProcessor(String msgType, String cmdName);
}

///  CPU Factory
///  ~~~~~~~~~~~
///  处理器工厂接口，定义处理器的获取/路由规范，是处理器的统一入口
abstract interface class ContentProcessorFactory{
  ///  根据Content对象自动匹配对应的处理器
  ///  （自动识别普通内容/指令内容，指令内容会优先匹配指令处理器）
  ///
  /// @param content - 内容对象（普通内容/指令内容）
  /// @return 匹配的处理器，无匹配则返回null
  ContentProcessor? getContentProcessor(Content content);

  ///  直接根据内容类型获取普通内容处理器
  ///
  /// @param msgType - 内容类型（Content.type）
  /// @return 匹配的普通内容处理器，无匹配则返回null
  ContentProcessor? getContentProcessorForType(String msgType);
}