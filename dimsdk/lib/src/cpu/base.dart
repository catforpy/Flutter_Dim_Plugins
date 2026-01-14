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

/// CPU模块 - 基础内容处理器父类
/// 核心作用：定义所有内容/命令处理器的通用逻辑，核心是为“不支持的内容/命令”返回统一格式的回执，
/// 采用「模板方法模式」设计：父类定义通用回执生成逻辑，子类只需重写processContent处理具体业务。
/// 核心能力：
/// 1. 通用处理逻辑：processContent 处理所有不支持的Content，返回“Content not support”回执；
/// 2. 统一回执生成：respondReceipt/createReceipt 生成包含上下文的标准回执，保证响应格式统一。
class BaseContentProcessor extends TwinsHelper implements ContentProcessor {
  /// 构造方法：关联实体管理（facebook）和消息核心（messenger）上下文
  /// @param facebook - 实体管理核心（用户/群组/身份数据）
  /// @param messenger - 消息收发核心（加密/解密/序列化）
  BaseContentProcessor(super.facebook, super.messenger);

  /// 处理不支持的Content（模板方法）
  /// 核心逻辑：对所有未实现具体处理逻辑的Content，返回标准化的“不支持”回执，
  /// 回执包含模板和替换参数，便于前端解析和展示具体的不支持原因。
  /// @param content - 待处理的内容（任意未支持的Content类型）
  /// @param rMsg - 原始可靠消息（用于获取信封上下文）
  /// @return 包含“Content not support”回执的列表
  @override
  Future<List<Content>> processContent(Content content,ReliableMessage rMsg) async{
    String text = 'Content not support.';
    return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
      'template': 'Content (type: \${type}) not support yet!',
      'replacements': {
        'type': content.type,
      },
    });
  }

  // ======================== 通用回执生成工具 ========================

  /// 生成单条回执响应（简化方法）
  /// 核心逻辑：调用createReceipt生成标准回执，封装为列表返回，适配处理器统一的返回格式。
  /// @param text - 回执文本内容
  /// @param envelope - 原始消息信封（包含发送者/接收者/时间等上下文）
  /// @param content - 原始消息内容（用于关联序列号/群组等信息）
  /// @param extra - 额外扩展字段（模板/替换参数等）
  /// @return 包含单条ReceiptCommand的列表
  // protected
  List<ReceiptCommand> respondReceipt(String text, {
    required Envelope envelope, Content? content, Map<String, Object>? extra
  }) => [
    createReceipt(text, envelope: envelope, content: content, extra: extra)
  ];

  /// 创建标准回执命令（核心工具方法）
  /// 核心逻辑：自动关联原始消息的信封、序列号、群组等上下文信息，保证回执的上下文完整性，
  /// 支持添加额外扩展字段，满足自定义回执需求。
  /// @param text - 回执文本内容（用户可见的提示信息）
  /// @param envelope - 原始消息信封（必须，关联发送者/接收者）
  /// @param content - 原始消息内容（可选，关联序列号/群组）
  /// @param extra - 额外扩展字段（可选，如模板/替换参数）
  /// @return 标准化的ReceiptCommand实例
  static ReceiptCommand createReceipt(String text, {
    required Envelope envelope, Content? content, Map<String, Object>? extra
  }) {
    // 步骤1：创建基础回执，自动关联信封、序列号、群组ID
    ReceiptCommand res = ReceiptCommand.create(text, envelope, content);
    // 步骤2：添加额外扩展字段（如模板、替换参数）
    if (extra != null) {
      res.addAll(extra);
    }
    return res;
  }
}

/// CPU模块 - 基础命令处理器父类
/// 核心作用：继承BaseContentProcessor，专门处理Command类型内容，
/// 重写processContent方法，为“不支持的命令”返回针对性的回执（包含命令名）。
class BaseCommandProcessor extends BaseContentProcessor {
  /// 构造方法：继承父类，关联实体管理和消息核心上下文
  BaseCommandProcessor(super.facebook, super.messenger);

  /// 处理不支持的Command（模板方法）
  /// 核心逻辑：断言校验内容为Command类型，返回包含命令名的“不支持”回执，
  /// 相比父类更精准，便于定位不支持的具体命令。
  /// @param content - 待处理的命令（必须为Command类型）
  /// @param rMsg - 原始可靠消息（用于获取信封上下文）
  /// @return 包含“Command not support”回执的列表
  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    // 断言校验：确保处理的是Command类型，避免类型错误
    assert(content is Command, 'command error: $content');
    Command command = content as Command;
    String text = 'Command not support.';
    return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
      'template': 'Command (name: \${command}) not support yet!',
      'replacements': {
        'command': command.cmd,
      },
    });
  }
}