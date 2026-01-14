/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
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

import 'package:dim_client/ok.dart';     // DIM-SDK基础工具
import 'package:dim_client/sdk.dart';    // DIM-SDK核心库
import 'package:dim_client/client.dart'; // DIM-SDK客户端基类

import '../models/amanuensis.dart'; // 消息记录员模型
import 'cpu/creator.dart';          // 内容处理器创建器

/// 共享消息处理器：继承ClientMessageProcessor，扩展消息处理逻辑
/// 核心扩展：
/// 1. 使用自定义内容处理器创建器
/// 2. 消息处理异常捕获（避免崩溃）
/// 3. 处理完成后自动保存即时消息
class SharedProcessor extends ClientMessageProcessor with Logging {
  /// 构造方法：初始化消息处理器
  /// [facebook] - 身份管理核心
  /// [messenger] - 消息收发器
  SharedProcessor(super.facebook, super.messenger);

  // ===================== 内容处理器创建 =====================
  /// 创建内容处理器创建器（重写父类）
  /// 返回：自定义的内容处理器创建器
  @override
  ContentProcessorCreator createCreator(Facebook facebook, Messenger messenger) {
    return SharedContentProcessorCreator(facebook, messenger);
  }

  // ===================== 安全消息处理增强 =====================
  /// 处理安全消息（重写父类）
  /// 扩展：异常捕获，避免单个消息处理失败导致整体崩溃
  @override
  Future<List<SecureMessage>> processSecureMessage(SecureMessage sMsg, ReliableMessage rMsg) async {
    try {
      // 执行父类处理逻辑
      return await super.processSecureMessage(sMsg, rMsg);
    } catch (e, st) {
      // 记录异常日志（包含消息签名用于调试）
      logInfo('error message signature: ${rMsg['debug-sig']}');
      logError('failed to process message: ${rMsg.sender} -> ${rMsg.receiver}: $e, $st');
      // assert(false, 'failed to process message: ${rMsg.sender} -> ${rMsg.receiver}: $e');
      return []; // 返回空列表表示处理失败
    }
  }

  // ===================== 即时消息处理增强 =====================
  /// 处理即时消息（重写父类）
  /// 扩展：处理完成后自动保存消息到数据库
  @override
  Future<List<InstantMessage>> processInstantMessage(InstantMessage iMsg, ReliableMessage rMsg) async {
    // 执行父类处理逻辑
    List<InstantMessage> responses = await super.processInstantMessage(iMsg, rMsg);
    
    // 保存处理后的消息
    Amanuensis clerk = Amanuensis();
    if (await clerk.saveInstantMessage(iMsg)) {
      // 保存成功：无操作
    } else {
      // 保存失败：记录错误日志
      logError('failed to save instant message: ${iMsg.sender} -> ${iMsg.receiver}');
      return []; // 返回空列表表示处理失败
    }
    
    return responses;
  }
}

