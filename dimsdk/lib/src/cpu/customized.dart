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

/// 自定义内容处理器接口
/// 核心作用：为业务层提供可扩展的自定义内容处理能力，定义“动作-发送者-内容-消息”的处理契约，
/// 采用「策略模式」设计：业务层只需实现该接口，即可自定义不同app/mod/act的处理逻辑。
abstract interface class CustomizedContentHandler {

  /// 处理自定义动作（核心业务接口）
  /// 业务层需实现该方法，处理指定app/mod下的具体动作，返回自定义响应。
  /// @param act - 自定义动作名（如'login'/'send_message'）
  /// @param sender - 消息发送者ID（用于权限校验等）
  /// @param content - 自定义内容（包含app/mod/act和业务数据）
  /// @param rMsg - 原始可靠消息（上下文信息）
  /// @return 处理结果列表（自定义响应内容）
  Future<List<Content>> handleAction(String act, ID sender, CustomizedContent content,
      ReliableMessage rMsg);
}

/// 默认自定义内容处理器
/// 核心作用：实现CustomizedContentHandler接口，为“不支持的自定义内容”返回统一格式的回执，
/// 包含app/mod/act信息，便于调试和前端解析。
class BaseCustomizedHandler extends TwinsHelper implements CustomizedContentHandler {
  /// 构造方法：关联实体管理和消息核心上下文
  BaseCustomizedHandler(super.facebook, super.messenger);

  /// 处理不支持的自定义动作（默认实现）
  /// 核心逻辑：返回包含app/mod/act的“不支持”回执，保证响应格式统一。
  /// @param act - 自定义动作名
  /// @param sender - 消息发送者ID
  /// @param content - 自定义内容
  /// @param rMsg - 原始可靠消息（用于获取信封上下文）
  /// @return 包含“不支持”回执的列表
  @override
  Future<List<Content>> handleAction(String act, ID sender, CustomizedContent content,
      ReliableMessage rMsg) async {
    String app = content.application;
    String mod = content.module;
    String text = 'Content not support.';
    return respondReceipt(text, content: content, envelope: rMsg.envelope, extra: {
      'template': 'Customized content (app: \${app}, mod: \${mod}, act: \${act}) not support yet!',
      'replacements': {
        'app': app,
        'mod': mod,
        'act': act,
      }
    });
  }

  // ======================== 通用回执生成工具 ========================

  /// 生成单条回执响应（复用父类工具方法）
  /// 核心逻辑：调用BaseContentProcessor的createReceipt生成标准回执，封装为列表返回。
  /// @param text - 回执文本内容
  /// @param envelope - 原始消息信封
  /// @param content - 原始自定义内容
  /// @param extra - 额外扩展字段
  /// @return 包含单条ReceiptCommand的列表
  // protected
  List<ReceiptCommand> respondReceipt(String text, {
    required Envelope envelope, Content? content, Map<String, Object>? extra
  }) => [
    BaseContentProcessor.createReceipt(text, envelope: envelope, content: content, extra: extra)
  ];
}

/// CPU模块 - 自定义内容处理器
/// 核心作用：处理CustomizedContent（自定义应用内容），支持按“app/mod/act”分层处理，
/// 采用「策略模式+模板方法」设计：
/// 1. Processor定义处理流程（解析app/mod/act，筛选Handler）；
/// 2. Handler定义处理策略（业务层实现具体动作逻辑）。
class CustomizedContentProcessor extends BaseContentProcessor {
  /// 构造方法：关联实体管理和消息核心上下文，初始化默认Handler
  /// @param facebook - 实体管理核心
  /// @param messenger - 消息收发核心
  CustomizedContentProcessor(Facebook facebook, Messenger messenger) : super(facebook, messenger) {
    defaultHandler = createDefaultHandler(facebook, messenger);
  }

  /// 创建默认自定义Handler（可重写扩展）
  /// 核心逻辑：默认返回BaseCustomizedHandler，业务层可重写返回自定义Handler。
  /// @param facebook - 实体管理核心
  /// @param messenger - 消息收发核心
  /// @return 默认自定义Handler实例
  // protected
  CustomizedContentHandler createDefaultHandler(Facebook facebook, Messenger messenger) =>
      BaseCustomizedHandler(facebook, messenger);

  /// 默认自定义Handler（处理所有未匹配的app/mod）
  // protected
  late final CustomizedContentHandler defaultHandler;

  /// 处理自定义内容（核心流程）
  /// 核心步骤：
  /// 1. 解析自定义内容的app/mod/act；
  /// 2. 筛选对应app/mod的Handler；
  /// 3. 调用Handler处理具体动作；
  /// @param content - 待处理的CustomizedContent
  /// @param rMsg - 原始可靠消息（上下文）
  /// @return 处理结果列表（自定义响应/默认回执）
  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    // 断言校验：确保处理的是CustomizedContent类型
    assert(content is CustomizedContent, 'customized content error: $content');
    CustomizedContent customized = content as CustomizedContent;
    
    // 步骤1：解析自定义内容的app/mod
    String app = customized.application;
    String mod = customized.module;
    // 步骤2：筛选对应app/mod的Handler（默认返回defaultHandler）
    CustomizedContentHandler handler = filter(app, mod, customized, rMsg);
    // 步骤3：解析动作名，调用Handler处理
    String act = customized.action;
    ID sender = rMsg.sender;
    return await handler.handleAction(act, sender, customized, rMsg);
  }

  /// 筛选对应app/mod的Handler（扩展点）
  /// 核心逻辑：默认返回defaultHandler，业务层可重写该方法，
  /// 为不同app/mod分配不同的Handler，避免单个Handler逻辑臃肿。
  /// @param app - 应用名（如'chat'/'payment'）
  /// @param mod - 模块名（如'group'/'personal'）
  /// @param content - 自定义内容
  /// @param rMsg - 原始可靠消息
  /// @return 对应app/mod的Handler实例
  // protected
  CustomizedContentHandler filter(String app, String mod, CustomizedContent content, ReliableMessage rMsg) {
    // 扩展建议：若应用包含多个模块，可为每个模块分配独立的Handler
    // if the application has too many modules, I suggest you to
    // use different handler to do the jobs for each module.
    return defaultHandler;
  }
}