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

import 'package:dimp/dkd.dart';

/// 命令解析辅助接口
/// 作用：定义命令工厂的注册/获取、命令解析的核心方法，是命令解析的“核心工具”
/// 说明：该接口由SDK内部实现，对外提供命令解析的统一入口
abstract interface class CommandHelper{
  /// 注册指定命令的工厂类（实现”命令名->工厂“的映射）
  /// @param cmd      - 命令名（如”meta“/”receipt“）
  /// @param factory  - 命令工厂
  void setCommandFactory(String cmd,CommandFactory factory);

  /// 获取指定命令的工厂类
  /// @param cmd      - 命令名
  /// @param 命令工厂（null= 未注册）
  CommandFactory? getCommandFactory(String cmd);

  /// 解析任意对象为命令实例
  /// @param content  - 带解析的内容（字典/JSON/字符串）
  /// @return 命令实例（null = 解析失败）
  Command? parseCommand(Object? content);
}

/// 命令扩展类（单例）
/// 作用：提供全局的CommandHelper实例访问入口，是命令解析工具的“全局管理器”
/// 说明：采用单例模式，保证全局只有一个CommandHelper实例，统一管理命令工厂
class CommandExtensions{
  // 单例构造器（工厂构造器）
  factory CommandExtensions() => _instance;
  // 静态单例实例
  static final CommandExtensions _instance = CommandExtensions._internal();
  // 私有构造器（防止外部创建实例）
  CommandExtensions._internal();

  /// 全局命令辅助工具实例（由SDK初始化时赋值）
  CommandHelper? cmdHelper;
}