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

import 'package:dim_client/sdk.dart';    // DIM-SDK核心库
import 'package:dim_client/common.dart'; // DIM-SDK通用接口
import 'package:dim_client/cpu.dart';    // DIM-SDK内容处理器核心

import '../../common/protocol/search.dart'; // 自定义搜索命令协议
import '../../ui/translation.dart';       // 翻译相关UI工具
import '../shared.dart';                  // 全局变量

import 'any.dart';       // 通用内容处理器
import 'handshake.dart'; // 握手命令处理器
import 'search.dart';    // 搜索命令处理器
import 'translate.dart'; // 翻译内容处理器
import 'text.dart';      // 文本内容处理器

/// 共享内容处理器创建器：继承ClientContentProcessorCreator，注册自定义处理器
/// 核心作用：
/// 1. 注册自定义命令/内容处理器
/// 2. 按消息类型分发到对应处理器（工厂模式）
class SharedContentProcessorCreator extends ClientContentProcessorCreator {
  /// 构造方法：初始化创建器，传入Facebook和Messenger
  SharedContentProcessorCreator(super.facebook, super.messenger);

  /// 创建自定义内容处理器：注册翻译/服务类消息处理器
  @override
  AppCustomizedProcessor createCustomizedContentProcessor(Facebook facebook, Messenger messenger) {
    // 先创建父类的自定义处理器（保证基础功能）
    var cpu = super.createCustomizedContentProcessor(facebook, messenger);

    // ===================== 1. 注册翻译处理器 =====================
    var trans = TranslateContentHandler();
    // 注册翻译应用的处理器（正式翻译模块）
    cpu.setHandler(app: Translator.app, mod: Translator.mod, handler: trans);
    // 注册翻译测试模块的处理器
    cpu.setHandler(app: Translator.app, mod: 'test', handler: trans);

    // ===================== 2. 注册服务类消息处理器 =====================
    GlobalVariable shared = GlobalVariable();
    var service = ServiceContentHandler(shared.database);
    // 遍历所有服务应用模块，注册处理器
    ServiceContentHandler.appModules.forEach((app, modules){
      for(var mod in modules){
        cpu.setHandler(app: app, mod: mod, handler: service);
      }
    });
    return cpu;
  }

  /// 创建内容处理器：按消息类型分发（工厂模式）
  @override
  ContentProcessor? createContentProcessor(String msgType) {
    switch(msgType){
      // 自定义文本消息处理器
      case ContentType.TEXT:
      case 'text':
        return TextContentProcessor(facebook!, messenger!);

      // 通用消息处理器（兜底）
      case ContentType.ANY:
      case '*':
        return AnyContentProcessor(facebook!, messenger!);

      // 其他类型：交给父类处理
      default:
        return super.createContentProcessor(msgType);
    }
  }

  /// 创建命令处理器：按命令类型分发（工厂模式）
  @override
  ContentProcessor? createCommandProcessor(String msgType,String cmd){
    // 1. 搜索命令（在线用户/通用搜索）
    if(cmd == SearchCommand.ONLINE_USERS || cmd == SearchCommand.SEARCH){
      return SearchCommandProcessor(facebook!, messenger!);
    }
    // 2. 握手命令（用于测试）
    if(cmd == HandshakeCommand.HANDSHAKE){
      return HandshakeCommandProcessor(facebook!, messenger!);
    }
    // 其他命令：交给父类处理
    return super.createCommandProcessor(msgType, cmd);
  }
}