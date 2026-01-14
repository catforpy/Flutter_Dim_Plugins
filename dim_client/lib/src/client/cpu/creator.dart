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

import 'package:dimsdk/dimsdk.dart';  // DIM核心协议库（定义基础消息/命令模型）

import '../../common/protocol/ans.dart';        // ANS命令协议（地址命名系统命令模型）
import '../../common/protocol/groups.dart';    // 群组命令协议（邀请/移出/重置等群组操作）
import '../../common/protocol/handshake.dart'; // 握手命令协议（客户端-服务器连接验证）
import '../../common/protocol/login.dart';     // 登录命令协议（用户登录状态管理）

import 'commands.dart';               // 基础命令处理器（ANS/Login/Receipt等基础命令）
import 'group.dart';                  // 群组命令基础处理器（所有群组子命令的父类）
import 'group/expel.dart';            // 移出群组命令处理器（处理expel命令）
import 'group/invite.dart';           // 邀请入群命令处理器（处理invite命令）
import 'group/join.dart';             // 加入群组命令处理器（处理join命令）
import 'group/query.dart';            // 查询群成员命令处理器（处理query命令）
import 'group/quit.dart';             // 退出群组命令处理器（处理quit命令）
import 'group/reset.dart';            // 重置群成员命令处理器（处理reset命令）
import 'group/resign.dart';           // 管理员辞职命令处理器（处理resign命令）
import 'handshake.dart';              // 握手命令处理器（处理handshake命令）
import 'customized.dart';             // 自定义内容处理器（处理application/customized类型消息）

/// 客户端内容处理器创建器
/// 设计模式：工厂模式 + 责任链模式
/// 核心功能：
/// 1. 作为“工厂类”，根据消息类型/命令类型创建对应的处理器实例；
/// 2. 注册所有内置的命令处理器（基础命令/群组命令/自定义命令）；
/// 3. 实现命令的分发处理，不同类型的命令路由到对应处理器；
/// 核心价值：统一命令分发入口，便于扩展新的命令处理器
class ClientContentProcessorCreator extends BaseContentProcessorCreator {
  /// 构造方法
  /// [facebook] - 账号系统核心实例（用户/群组信息管理）
  /// [messenger] - 消息收发核心实例（消息发送/接收/处理）
  ClientContentProcessorCreator(super.facebook, super.messenger);

  /// 创建自定义内容处理器（核心扩展点）
  /// 核心逻辑：为"chat.dim.group:history"应用模块注册专用处理器
  /// 设计目的：支持自定义格式的群组历史查询命令处理
  // protected（Dart通过命名规范模拟protected访问修饰符）
  AppCustomizedProcessor createCustomizedContentProcessor(Facebook facebook, Messenger messenger){
    // 创建客户端自定义内容处理器实例（基础自定义内容处理能力）
    var cpu = AppCustomizedProcessor(facebook, messenger);

    // 注册群组历史处理器（处理"chat.dim.group:history"类型的自定义内容）
    // 'chat.dim.group:history' → 群组历史查询的自定义命令标识
    cpu.setHandler(
      app: GroupHistory.APP,       // 应用标识：chat.dim.group（群组相关应用）
      mod: GroupHistory.MOD,       // 模块标识：history（历史记录模块）
      handler: GroupHistoryHandler(facebook, messenger), // 具体的处理器实例
    );

    return cpu;
  }

  /// 根据消息类型创建对应的内容处理器（覆盖父类方法）
  /// 核心逻辑：按消息类型分发到不同处理器
  /// [msgType] - 消息类型（如application/customized/history/command等）
  /// 返回值：对应类型的处理器实例（null表示无对应处理器）
  @override
  ContentProcessor? createContentProcessor(String msgType) { 
    switch (msgType) {
      // 应用自定义内容（兼容不同的类型字符串写法）
      case ContentType.APPLICATION:  // 枚举值：0xCC（十六进制）
      case 'application':            // 字符串值：application
      case ContentType.CUSTOMIZED:   // 枚举值：0xCC（别名）
      case 'customized':             // 字符串值：customized
        // 创建自定义内容处理器（已注册群组历史处理器）
        return createCustomizedContentProcessor(facebook!, messenger!);

      // 历史命令（未实现具体业务逻辑，返回基础处理器）
      case ContentType.HISTORY:      // 枚举值：0x89
      case 'history':                // 字符串值：history
        return HistoryCommandProcessor(facebook!, messenger!);

      // 其他类型 → 调用父类方法创建默认处理器（如command类型）
      default:
        return super.createContentProcessor(msgType);
    }
  }

  /// 根据命令类型创建对应的命令处理器（覆盖父类方法）
  /// 核心逻辑：按命令名称分发到不同处理器
  /// [msgType] - 消息类型（固定为command/0x88）
  /// [cmd] - 命令名称（如receipt/handshake/login/invite等）
  /// 返回值：对应命令的处理器实例（null表示无对应处理器）
  @override
  ContentProcessor? createCommandProcessor(String msgType, String cmd) {
    switch (cmd) {
      // ========== 基础命令 ==========
      case Command.RECEIPT:          // 回执命令（已读/送达/失败回执）
        return ReceiptCommandProcessor(facebook!, messenger!);
      case HandshakeCommand.HANDSHAKE: // 握手命令（客户端-服务器连接验证）
        return HandshakeCommandProcessor(facebook!, messenger!);
      case LoginCommand.LOGIN:       // 登录命令（用户登录状态保存）
        return LoginCommandProcessor(facebook!, messenger!);
      case AnsCommand.ANS:           // ANS命令（地址命名系统查询/更新）
        return AnsCommandProcessor(facebook!, messenger!);

      // ========== 群组命令 ==========
      case 'group':                  // 通用群组命令（未指定具体子命令）
        return GroupCommandProcessor(facebook!, messenger!);
      case GroupCommand.INVITE:      // 邀请入群命令
        return InviteCommandProcessor(facebook!, messenger!);
      case GroupCommand.EXPEL:       // 移出群组命令（已废弃，建议使用reset）
        /// Deprecated (use 'reset' instead) - 标注废弃说明
        return ExpelCommandProcessor(facebook!, messenger!);
      case GroupCommand.JOIN:        // 加入群组命令
        return JoinCommandProcessor(facebook!, messenger!);
      case GroupCommand.QUIT:        // 退出群组命令
        return QuitCommandProcessor(facebook!, messenger!);
      case QueryCommand.QUERY:       // 查询群成员命令
        return QueryCommandProcessor(facebook!, messenger!);
      case GroupCommand.RESET:       // 重置群成员命令（替代expel）
        return ResetCommandProcessor(facebook!, messenger!);
      case GroupCommand.RESIGN:      // 管理员辞职命令
        return ResignCommandProcessor(facebook!, messenger!);

      // 其他命令 → 调用父类方法创建默认处理器
      default:
        return super.createCommandProcessor(msgType, cmd);
    }
  }
}