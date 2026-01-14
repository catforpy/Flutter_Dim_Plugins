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

import 'package:dim_client/ok.dart';    // DIM-SDK基础工具
import 'package:dim_client/sdk.dart';   // DIM-SDK核心库

import '../../common/constants.dart';   // 项目常量（通知名）
import '../../ui/translation.dart';     // 翻译相关UI工具

/// 翻译内容处理器：处理翻译类自定义内容
/// 混合Logging：提供日志能力
/// 实现CustomizedContentHandler：适配DIM-SDK自定义内容处理接口
class TranslateContentHandler with Logging implements CustomizedContentHandler {
  /// 核心处理方法：解析翻译内容，更新缓存并发送通知
  @override
  Future<List<Content>> handleAction(String act, ID sender, CustomizedContent content, ReliableMessage rMsg) async {
    // 解析翻译内容
    TranslateContent tr = TranslateContent(content.toMap());
    
    // 非响应类翻译内容：忽略
    if (tr.action != 'respond') {
      logError('translate content error: $content, $sender');
      return [];
    }

    // 更新翻译缓存
    bool ok = Translator().update(tr);
    if (!ok) {
      logWarning('failed to update translate content: $content, $sender');
      return [];
    }

    // 发送翻译更新通知
    var nc = NotificationCenter();
    if (tr.module == Translator.mod) {
      // 正式翻译模块：发送翻译更新通知
      nc.postNotification(NotificationNames.kTranslateUpdated, this, {
        'content': tr,
      });
    } else if (tr.module == 'test') {
      // 测试模块：发送翻译警告通知
      nc.postNotification(NotificationNames.kTranslatorWarning, this, {
        'content': tr,
        'sender': sender,
      });
    } else {
      // 未知模块：记录错误
      logError('translate content error: $content, $sender');
    }

    // 无需回复翻译内容
    return [];
  }
}