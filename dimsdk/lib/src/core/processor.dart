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

/// DIM 协议消息处理接口
/// 核心作用：定义消息从“网络字节数组→业务内容”的全链路处理流程，以及响应消息的生成逻辑，
/// 是消息接收后的「业务处理入口」，按层级逐步解析，最终触发业务逻辑（如聊天展示、命令执行）。
/// 处理层级（从下到上）：
/// 字节数组 → 可靠消息 → 安全消息 → 明文消息 → 业务内容 → 响应生成。
abstract interface class Processor {

  /// 处理网络字节数组
  /// 核心逻辑：先反序列化为可靠消息，再逐层处理，最终生成响应的字节数组，
  /// 是消息处理的最顶层入口。
  /// @param data - 网络接收的字节数组
  /// @return 响应的字节数组列表（如回执、自动回复）
  Future<List<Uint8List>> processPackage(Uint8List data);

  /// 处理可靠消息
  /// 核心逻辑：验证消息签名，还原为安全消息，再调用 processSecureMessage 处理，
  /// 生成响应的可靠消息。
  /// @param rMsg - 反序列化后的可靠消息
  /// @return 响应的可靠消息列表
  Future<List<ReliableMessage>> processReliableMessage(ReliableMessage rMsg);

  /// 处理安全消息
  /// 核心逻辑：解密消息内容，还原为明文消息，再调用 processInstantMessage 处理，
  /// 生成响应的安全消息。
  /// @param sMsg - 验签后的安全消息
  /// @param rMsg - 原始接收的可靠消息（用于关联上下文）
  /// @return 响应的安全消息列表
  Future<List<SecureMessage>> processSecureMessage(SecureMessage sMsg, ReliableMessage rMsg);

  /// 处理明文消息
  /// 核心逻辑：解析消息内容，调用 processContent 处理业务逻辑，生成响应的明文消息。
  /// @param iMsg - 解密后的明文消息
  /// @param rMsg - 原始接收的可靠消息（用于关联上下文）
  /// @return 响应的明文消息列表
  Future<List<InstantMessage>> processInstantMessage(InstantMessage iMsg, ReliableMessage rMsg);

  /// 处理消息内容（业务层核心）
  /// 核心逻辑：解析 Content 类型（文本/图片/命令），执行对应的业务逻辑（如展示聊天、执行命令），
  /// 生成响应的内容（如回执、自动回复）。
  /// @param content - 明文消息的业务内容
  /// @param rMsg - 原始接收的可靠消息（用于关联上下文）
  /// @return 响应的内容列表
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg);
}