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

import 'package:flutter/services.dart'; // Flutter原生通信核心库

import 'package:dim_client/ok.dart';    // DIM-SDK基础工具库
import 'package:dim_client/sdk.dart';   // DIM-SDK核心库（消息/命令相关）
import 'package:dim_client/common.dart';// DIM-SDK通用工具

import '../widgets/permissions.dart';   // 权限检查（通知权限）
import '../client/client.dart';         // 客户端核心逻辑
import '../client/messenger.dart';      // 消息发送器
import '../client/shared.dart';         // 全局变量
import 'manager.dart';                  // 通道管理相关

/// 会话通道：封装Flutter与原生的消息发送交互
/// 核心功能：接收原生的消息发送指令，转发到DIM客户端核心逻辑
class SessionChannel extends SafeChannel{
  /// 构造方法：初始化会话通道，绑定通道名称并设置方法回调
  /// [name] - 原生通道名称（对应ChannelNames.session）
  SessionChannel(super.name) {
    setMethodCallHandler(_handle); // 监听原生→Flutter的方法调用
  }

  /// 原生→Flutter方法调用处理器：处理消息发送相关指令
  /// [call] - 原生传递的方法调用
  Future<void> _handle(MethodCall call) async {
    String method = call.method;       // 原生调用的方法名
    var arguments = call.arguments;    // 原生传递的参数

    // 场景1：发送普通消息内容（原生触发Flutter发送消息）
    if (method == ChannelMethods.sendContent) {
      Content? content = Content.parse(arguments['content']); // 解析消息内容
      ID? receiver = ID.parse(arguments['receiver']);         // 解析接收者ID
      if (content == null || receiver == null) {
        assert(false, 'failed to send content: $arguments'); // 开发期断言：参数错误
      } else {
        _sendContent(content, receiver: receiver); // 转发到消息发送逻辑
      }
    }
    // 场景2：发送命令消息（如握手/上报/群组操作）
    else if (method == ChannelMethods.sendCommand) {
      Command? content = Command.parse(arguments['content']); // 解析命令内容
      ID? receiver = ID.parse(arguments['receiver']);         // 解析接收者ID
      if (content == null) {
        assert(false, 'failed to send command: $arguments'); // 开发期断言：参数错误
      } else {
        _sendCommand(content, receiver: receiver); // 转发到命令发送逻辑
      }
    }
  }

  /// 发送命令消息：封装命令的特殊处理逻辑
  /// [content] - 命令内容（如握手/上报）
  /// [sender] - 发送者ID（可选，默认当前用户）
  /// [receiver] - 接收者ID（可选，默认当前服务器）
  /// [priority] - 消息优先级（0为默认）
  void _sendCommand(Command content, {ID? sender, ID? receiver, int priority = 0}) {
    // 处理接收者为空的情况：默认发送到当前连接的服务器（如握手命令）
    if (receiver == null) {
      GlobalVariable shared = GlobalVariable();
      SharedMessenger? messenger = shared.messenger;
      receiver = messenger?.session.station.identifier; // 获取当前服务器ID
      if (receiver == null) {
        assert(false, 'failed to get current station'); // 开发期断言：未连接服务器
        return;
      }
    }

    // 特殊处理：上报命令（如c2dm推送）需检查通知权限
    if (content is ReportCommand) {
      String? title = content.title;
      if (title == 'c2dm') { // C2DM是Android推送协议
        Log.info('checking notification permissions for command: $content');
        PermissionChecker().setNeedsNotificationPermissions(); // 检查/请求通知权限
      }
    }

    // 转发到通用消息发送逻辑
    _sendContent(content, sender: sender, receiver: receiver, priority: priority);
  }

  /// 通用消息发送逻辑：将消息加入客户端待发送队列
  /// [content] - 消息/命令内容
  /// [sender] - 发送者ID（可选，默认当前用户）
  /// [receiver] - 接收者ID（必填）
  /// [priority] - 消息优先级（高优先级优先发送）
  void _sendContent(Content content, {ID? sender, required ID receiver, int priority = 0}) {
    GlobalVariable shared = GlobalVariable(); // 获取全局变量
    Client client = shared.terminal;          // 获取客户端核心实例
    // 日志：记录消息发送（便于调试）
    Log.info('[safe channel] sending content: $sender => $receiver: $content');
    // 将消息加入待发送队列（客户端会处理登录状态检查/加密/发送逻辑）
    client.addWaitingContent(content, receiver: receiver, priority: priority);
  }
}