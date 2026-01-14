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

import 'package:dimp/dimp.dart';
import 'package:dimp/dkd.dart';

/// 命令消息基础接口
/// 作用：定义DIMP协议的命令类消息结构，用于节点间的控制指令（如查询Meta、回执等）
/// 数据格式：{
///      type : i2s(0x88),   // 消息类型标识（0x88=命令）
///      sn   : 123,         // 消息序列号
///
///      command : "...", // 命令名（如"meta"/"receipt"）
///      extra   : info   // 命令参数
///  }
abstract interface class Command implements Content{
  
  //-------- 内置命令名常量 --------
  /// 查询/响应Meta的命令（实体身份元数据）
  static const String META      = 'meta';
  /// 查询/响应Document的命令（实体资料）
  static const String DOCUMENTS = 'documents';
  /// 消息回执命令（已读/已收到）
  static const String RECEIPT   = 'receipt';
  //-------- 内置命令名常量结束 --------

  /// 获取命令名（核心标识，区分不同命令）
  /// @return 命令名/方法名/声明
  String get cmd;

  //-------- 工厂方法（命令解析/注册）--------

  /// 解析字典为命令实例
  /// @param content - 命令内容（字典/JSON）
  /// @return 命令实例（null=解析失败）
  static Command? parse(Object? content) {
    var ext = CommandExtensions();
    return ext.cmdHelper!.parseCommand(content);
  }

  /// 获取指定命令的工厂类
  /// @param cmd - 命令名
  /// @return 命令工厂（null=未注册）
  static CommandFactory? getFactory(String cmd) {
    var ext = CommandExtensions();
    return ext.cmdHelper!.getCommandFactory(cmd);
  }

  /// 注册指定命令的工厂类
  /// @param cmd     - 命令名
  /// @param factory - 命令工厂
  static void setFactory(String cmd, CommandFactory factory) {
    var ext = CommandExtensions();
    ext.cmdHelper!.setCommandFactory(cmd, factory);
  }
}

/// 命令工厂接口
/// 作用：定义命令的解析规则，实现“命令名→命令实例”的映射，支持扩展自定义命令
abstract interface class CommandFactory {
  /// 将字典解析为命令实例
  /// @param content - 命令内容（字典）
  /// @return 命令实例
  Command? parseCommand(Map content);
}