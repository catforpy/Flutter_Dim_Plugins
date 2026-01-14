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

import 'package:dimsdk/core.dart';
import 'package:dimsdk/cpu.dart';
import 'package:dimsdk/dimp.dart';

/// CPU模块 - 内容处理器工厂基类
/// 核心作用：根据消息类型（Content Type）或命令名（Command Name）创建对应的处理器实例，
/// 是“处理器路由”的核心，采用「工厂模式」设计，集中管理处理器创建逻辑，降低业务层耦合。
/// 核心能力：
/// 1. 类型路由：createContentProcessor 根据Content类型创建对应处理器；
/// 2. 命令路由：createCommandProcessor 根据Command名称创建精准处理器；
/// 3. 扩展性：预留自定义处理器扩展位，支持业务层添加自定义实现。
class BaseContentProcessorCreator extends TwinsHelper implements ContentProcessorCreator {
  /// 构造方法：关联实体管理和消息核心上下文，传递给创建的处理器
  BaseContentProcessorCreator(super.facebook, super.messenger);

  /// 根据消息类型创建内容处理器（第一层路由）
  /// 核心逻辑：按Content类型匹配处理器，未匹配则返回null（由上层处理），
  /// 保证每个类型都有对应的处理器，且默认类型返回基础处理器。
  /// @param msgType - 消息类型字符串（如'forward'/'command'/'*'）
  /// @return 对应类型的处理器实例；未匹配返回null
  @override
  ContentProcessor? createContentProcessor(String msgType) {
    switch (msgType) {
      // // 预留：自定义应用内容处理器（业务层扩展）
      // case ContentType.APPLICATION:
      // case 'application':
      // case ContentType.CUSTOMIZED:
      // case 'customized':
      //   return CustomizedContentProcessor(facebook!, messenger!);

      // 转发内容 → 创建转发内容处理器
      case ContentType.FORWARD:
      case 'forward':
        return ForwardContentProcessor(facebook!, messenger!);

      // 批量内容 → 创建批量内容处理器
      case ContentType.ARRAY:
      case 'array':
        return ArrayContentProcessor(facebook!, messenger!);

      // 命令类型 → 创建基础命令处理器
      case ContentType.COMMAND:
      case 'command':
        return BaseCommandProcessor(facebook!, messenger!);

      // 任意类型（type=0）→ 创建基础内容处理器（默认）
      case ContentType.ANY:
      case '*':
        return BaseContentProcessor(facebook!, messenger!);
    }
    // 未匹配的类型 → 返回null（上层可处理为“不支持”）
    // assert(false, 'unsupported content: $msgType');
    return null;
  }

  /// 根据命令名创建命令处理器（第二层精准路由）
  /// 核心逻辑：在Content类型为Command的基础上，按命令名匹配精准处理器，
  /// 未匹配则返回null（使用基础命令处理器）。
  /// @param msgType - 消息类型（固定为'command'）
  /// @param cmd - 命令名（如'meta'/'documents'）
  /// @return 对应命令的处理器实例；未匹配返回null
  @override
  ContentProcessor? createCommandProcessor(String msgType, String cmd) {
    switch (cmd) {
      // Meta命令 → 创建Meta命令处理器
      case Command.META:
        return MetaCommandProcessor(facebook!, messenger!);

      // Document命令 → 创建Document命令处理器
      case Command.DOCUMENTS:
        return DocumentCommandProcessor(facebook!, messenger!);
    }
    // 未匹配的命令 → 返回null（使用基础命令处理器）
    // assert(false, 'unsupported command: $cmd');
    return null;
  }
}