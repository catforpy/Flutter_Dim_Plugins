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

/// CPU模块 - 转发内容处理器
/// 核心作用：处理ForwardContent（转发消息），实现“嵌套可靠消息”的递归处理，
/// 采用「递归处理模式」：将转发的每条ReliableMessage拆解，复用Messenger的核心处理逻辑。
/// 核心逻辑：遍历转发消息列表，递归处理每条消息，保持响应格式与输入一致（转发消息→转发结果）。
class ForwardContentProcessor extends BaseContentProcessor{
  /// 构造方法：继承父类，关联实体管理和消息核心上下文
  ForwardContentProcessor(super.facebook, super.messenger);

  /// 处理转发内容（核心逻辑）
  /// 核心流程：
  /// 1. 解析ForwardContent中的ReliableMessage列表；
  /// 2. 调用Messenger递归处理每条转发消息；
  /// 3. 将处理结果封装为ForwardContent返回，保证响应格式统一。
  /// @param content - 待处理的ForwardContent
  /// @param rMsg - 原始可靠消息（上下文，非转发的消息）
  /// @return 处理结果列表（每条结果对应一条转发消息的处理结果）
  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    // 断言校验：确保处理的是ForwardContent类型
    assert(content is ForwardContent, 'forward command error: $content');
    List<ReliableMessage> secrets = (content as ForwardContent).secrets;
    
    // 获取消息核心实例（用于递归处理转发的消息）
    Messenger transceiver = messenger!;
    List<Content> responses = [];
    Content res;
    List<ReliableMessage> results;
    
    // 遍历每条转发的可靠消息，递归处理
    for (ReliableMessage item in secrets) {
      // 调用Messenger处理单条转发消息
      results = await transceiver.processReliableMessage(item);
      // 根据处理结果数量，封装为对应的ForwardContent
      if (results.length == 1) {
        // 单条结果 → 封装为包含单条消息的ForwardContent
        res = ForwardContent.create(forward: results.first);
      } else {
        // 多条结果 → 封装为包含多条消息的ForwardContent
        res = ForwardContent.create(secrets: results);
      }
      responses.add(res);
    }
    return responses;
  }
}

/// CPU模块 - 批量内容处理器
/// 核心作用：处理ArrayContent（批量内容），实现“批量Content”的递归处理，
/// 采用「递归处理模式」：将批量的每条Content拆解，复用Messenger的核心处理逻辑。
/// 核心逻辑：遍历批量内容列表，递归处理每条内容，保持响应格式与输入适配（单条结果→原格式，多条→ArrayContent）。
class ArrayContentProcessor extends BaseContentProcessor {
  /// 构造方法：继承父类，关联实体管理和消息核心上下文
  ArrayContentProcessor(super.facebook, super.messenger);

  /// 处理批量内容（核心逻辑）
  /// 核心流程：
  /// 1. 解析ArrayContent中的Content列表；
  /// 2. 调用Messenger递归处理每条内容；
  /// 3. 根据处理结果数量，返回对应格式（单条→原Content，多条→ArrayContent）。
  /// @param content - 待处理的ArrayContent
  /// @param rMsg - 原始可靠消息（上下文）
  /// @return 处理结果列表（每条结果对应一条批量内容的处理结果）
  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    // 断言校验：确保处理的是ArrayContent类型
    assert(content is ArrayContent, 'array command error: $content');
    List<Content> array = (content as ArrayContent).contents;
    
    // 获取消息核心实例（用于递归处理批量内容）
    Messenger transceiver = messenger!;
    List<Content> responses = [];
    Content res;
    List<Content> results;
    
    // 遍历每条批量内容，递归处理
    for (Content item in array) {
      // 调用Messenger处理单条内容
      results = await transceiver.processContent(item, rMsg);
      // 根据处理结果数量，返回对应格式
      if (results.length == 1) {
        // 单条结果 → 直接返回该结果（无需封装）
        res = results.first;
      } else {
        // 多条结果 → 封装为ArrayContent返回
        res = ArrayContent.create(results);
      }
      responses.add(res);
    }
    return responses;
  }
}