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

import 'package:dimsdk/dimsdk.dart'; // DIM核心协议库（消息/命令模型）

import '../../common/protocol/groups.dart'; // 群组命令协议（QueryCommand模型）

/*  命令转换说明：
    自定义内容 → 群组查询命令的转换规则
    +===============================+===============================+
    |      自定义内容（Customized） |      群组查询命令（Query）    |
    +-------------------------------+-------------------------------+
    |   "type" : i2s(0xCC)          |   "type" : i2s(0x88)          |
    |   "sn"   : 123                |   "sn"   : 123                |
    |   "time" : 123.456            |   "time" : 123.456            |
    |   "app"  : "chat.dim.group"   |                               |
    |   "mod"  : "history"          |                               |
    |   "act"  : "query"            |                               |
    |                               |   "command"   : "query"       |
    |   "group"     : "{GROUP_ID}"  |   "group"     : "{GROUP_ID}"  |
    |   "last_time" : 0             |   "last_time" : 0             |
    +===============================+===============================+
    核心：将自定义格式的群组历史查询转换为标准的QueryCommand，复用已有逻辑
    转换逻辑：
    1. 移除自定义字段（app/mod/act）；
    2. 修改type为command类型（0x88）；
    3. 添加command字段为"query"；
    4. 保留核心业务字段（group/last_time/sn/time）；
 */

/// 群组历史处理器
/// 设计模式：适配器模式（适配自定义格式到标准命令）
/// 核心功能：
/// 1. 处理"chat.dim.group:history"类型的自定义内容（act=query）；
/// 2. 将自定义的群组历史查询转换为标准的QueryCommand；
/// 3. 复用QueryCommand的成熟处理逻辑，避免重复开发；
/// 应用场景：客户端发送的自定义格式群组历史查询命令处理
class GroupHistoryHandler extends BaseCustomizedHandler {
  /// 构造方法
  /// [facebook] - 账号系统核心实例
  /// [messenger] - 消息收发核心实例
  GroupHistoryHandler(super.facebook, super.messenger);

  /// 处理自定义内容的核心方法（按action分发处理）
  /// 核心逻辑：只处理act=query的操作，其他操作走父类默认逻辑
  /// [act] - 操作类型（如query，对应自定义内容中的act字段）
  /// [sender] - 消息发送者ID（命令发起者）
  /// [content] - 自定义内容实例（包含群组查询参数）
  /// [rMsg] - 可靠消息（已验证签名的消息载体）
  /// 返回值：需要回复的内容列表（空列表表示无需回复）
  @override
  Future<List<Content>> handleAction(
    String act,
    ID sender,
    CustomizedContent content,
    ReliableMessage rMsg,
  ) async {
    // 前置校验：群组ID不能为空（群组命令必须指定群组）
    if (content.group == null) {
      // 断言失败：开发阶段校验，确保传入参数合法
      assert(false, 'group command error: $content, sender: $sender');
      String text = 'Group command error.';
      // 返回错误回执（告知发送者命令格式错误）
      return respondReceipt(text, envelope: rMsg.envelope, content: content);
    }
    // 处理查询操作（arc = query -> 群组历史查询）
    else if (GroupHistory.ACT_QUERY == act) {
      // 断言：确保应用/模块标识正确（防止处理器挂载错误）
      assert(GroupHistory.APP == content.application);
      assert(GroupHistory.MOD == content.module);
      // 将自定义内容转换为标准QueryCommand并处理
      return await transformQueryCommand(content, rMsg);
    }
    // 未知操作 → 断言并调用父类默认处理（返回不支持的回执）
    assert(false, 'unknown action: $act, $content, sender: $sender');
    return await super.handleAction(act, sender, content, rMsg);
  }

  /// 将自定义群组查询转换为标准QueryCommand（核心转换逻辑）
  /// 设计目的：适配自定义格式到标准命令，复用已有处理逻辑
  // private（Dart通过命名规范模拟private访问修饰符）
  Future<List<Content>> transformQueryCommand(
    CustomizedContent content,
    ReliableMessage rMsg,
  ) async {
    // 获取消息收发器实例（用于处理转换后的标准命令）
    var transceiver = messenger;
    if (transceiver == null) {
      // 断言失败：messenger是核心依赖，必须存在
      assert(false, 'messenger lost');
      return [];
    }
    // 步骤1：复制自定义内容的字段（排除type/app/mod/act等自定义字段）
    // copyMap(false) → 不复制type字段（后续要修改为command类型）
    Map info = content.copyMap(false);
    // 步骤2：修改为命令类型（0x88，对应ContentType.COMMAND）
    info['type'] = ContentType.COMMAND;
    // 步骤3：设置命令名称为query（标准QueryCommand的标识）
    info['command'] = QueryCommand.QUERY;
    // 步骤4：解析为标准Content对象（自动转换为QueryCommand）
    Content? query = Content.parse(info);

    if (query is QueryCommand) {
      // 转换成功 → 复用QueryCommand的处理逻辑
      return await transceiver.processContent(query, rMsg);
    }
    // 转换失败 → 断言并返回错误回执
    assert(
      false,
      'query command error: $query, $content, sender: ${rMsg.sender}',
    );
    String text = 'Query command error.';
    return respondReceipt(text, envelope: rMsg.envelope, content: content);
  }
}

/// 客户端自定义内容处理器
/// 设计模式：策略模式（不同app:mod对应不同处理器）
/// 核心功能：
/// 1. 管理自定义内容的处理器映射表（app:mod → handler）；
/// 2. 支持动态注册/获取自定义处理器；
/// 3. 覆盖父类筛选逻辑，优先使用已注册的处理器；
/// 设计目的：实现自定义内容的模块化处理，便于扩展新的自定义命令
class AppCustomizedProcessor extends CustomizedContentProcessor {
  /// 构造方法
  AppCustomizedProcessor(super.facebook, super.messenger);

  /// 处理器映射表：key=app:mod（如chat.dim.group:history），value=对应的处理器
  /// 设计：使用Map存储，支持动态注册和快速查找
  final Map<String, CustomizedContentHandler> _handlers = {};

  /// 注册自定义处理器（对外暴露的注册接口）
  /// [app] - 应用标识（如chat.dim.group）
  /// [mod] - 模块标识（如history）
  /// [handler] - 对应的自定义处理器实例
  void setHandler({
    required String app,
    required String mod,
    required CustomizedContentHandler handler,
  }) => _handlers['$app:$mod'] = handler;

  /// 获取已注册的自定义处理器（内部使用）
  // protected（Dart通过命名规范模拟protected访问修饰符）
  CustomizedContentHandler? getHandler({
    required String app,
    required String mod,
  }) => _handlers['$app:$mod'];

  /// 筛选处理器（核心扩展点，覆盖父类方法）
  /// 核心逻辑：优先使用已注册的处理器，无注册则使用父类默认处理器
  /// [app] - 应用标识
  /// [mod] - 模块标识
  /// [content] - 自定义内容
  /// [rMsg] - 可靠消息
  /// 返回值：匹配的处理器实例
  @override
  CustomizedContentHandler filter(
    String app,
    String mod,
    CustomizedContent content,
    ReliableMessage rMsg,
  ) {
    // 尝试获取已注册的处理器
    CustomizedContentHandler? handler = getHandler(app: app, mod: mod);
    if (handler != null) {
      // 有注册的处理器 → 使用自定义处理器
      return handler;
    }
    // 无注册的处理器 → 使用父类默认处理器
    return super.filter(app, mod, content, rMsg);
  }
}
