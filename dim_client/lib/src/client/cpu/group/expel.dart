/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2025 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2025 Albert Moky
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

import 'package:dimsdk/dimsdk.dart';  // DIM核心协议库（定义群组命令/消息基础模型）

import '../group.dart';  // 群组相关基础类（GroupCommandProcessor父类）

/// 移出群组命令处理器
/// 核心说明：
/// 1. 该命令已**废弃**（官方明确使用'reset'命令替代expel命令）；
/// 2. 处理逻辑为空，仅做兼容性保留，不执行任何实际业务操作；
/// 设计目的：兼容旧版本客户端发送的'expel'命令，避免命令解析失败导致程序异常；
class ExpelCommandProcessor extends GroupCommandProcessor {
  /// 构造方法
  /// [facebook] - 账号系统核心实例（提供用户/群组基础信息查询能力）
  /// [messenger] - 消息收发核心实例（提供消息发送/处理基础能力）
  ExpelCommandProcessor(super.facebook, super.messenger);

  /// 处理群组命令的核心方法（覆盖父类抽象方法）
  /// [content] - 待处理的命令内容（ExpelCommand类型，废弃命令）
  /// [rMsg] - 包含该命令的可靠消息（已验证签名，确保消息来源合法）
  /// 返回值：空列表（无需回复该废弃命令）
  @override
  Future<List<Content>> processContent(Content content,ReliableMessage rMsg) async{
    // 断言：开发阶段校验，确保传入的内容是ExpelCommand类型，避免类型错误
    assert(content is ExpelCommand, 'expel command error: $content');

    // 断言提醒：明确告知开发者该命令已废弃，应使用reset命令替代
    assert(false, '"expel" group command is deprecated, use "reset" instead.');

    // 无需回复该命令（已废弃，无业务逻辑需要响应）
    return [];
  }
}