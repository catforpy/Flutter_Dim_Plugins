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

/// 通用命令辅助接口
/// 核心职责：定义从命令消息字典中提取「命令名称」的通用能力
/// 设计定位：
/// 1. 作为所有命令辅助类的顶层接口，统一命令名称解析的标准
/// 2. 注释中标注的 "implements CommandHelper" 是预留扩展（当前未实现，仅占位）
/// 术语说明：
/// - CMD：Command（命令）、Method（方法）、Declaration（声明）的统称，指代命令名称
abstract interface class GeneralCommandHelper{
  //
  //  CMD - 统一指代命令名称（如群组命令的"invite"/"expel"、回执命令的"receipt"等）
  //

  /// 从命令消息字典中提取命令名称
  /// 核心作用：标准化命令名称的解析逻辑，避免不同命令解析方式不一致
  /// @param content      命令消息的原始字典（如{ "cmd": "invite", "group": "...", ... }）
  /// @param defaultValue 解析失败时的默认返回值（可选，避免返回null）
  /// @return 解析到的命令名称（如"invite"/"receipt"），解析失败则返回defaultValue
  String? getCmd(Map content, [String? defaultValue]);
}

/// 命令扩展的单例管理类
/// 核心职责：
/// 1. 全局管理命令辅助类（CommandHelper）的实例，提供统一的访问入口
/// 2. 管理通用命令辅助类（GeneralCommandHelper）的全局实例
/// 设计模式：单例模式（保证全局唯一的扩展管理器）
class SharedCommandExtensions {
  /// 工厂构造方法：对外提供单例实例（隐藏内部初始化逻辑）
  factory SharedCommandExtensions() => _instance;
  
  /// 静态私有单例对象（全局唯一）
  static final SharedCommandExtensions _instance = SharedCommandExtensions._internal();
  
  /// 私有构造方法：禁止外部通过new创建实例（保证单例）
  SharedCommandExtensions._internal();

  /// 获取全局命令辅助类实例
  /// 底层逻辑：委托给CommandExtensions类的cmdHelper属性（分层解耦）
  /// 用途：所有模块通过此入口获取命令辅助类，保证全局使用同一套解析规则
  CommandHelper? get cmdHelper =>
      CommandExtensions().cmdHelper;

  /// 设置全局命令辅助类实例
  /// 用途：支持运行时替换命令辅助类（如自定义命令解析逻辑）
  set cmdHelper(CommandHelper? helper) =>
      CommandExtensions().cmdHelper = helper;

  /// 通用命令辅助类的全局实例
  /// 用途：存储GeneralCommandHelper的实现类，供全局解析命令名称使用
  GeneralCommandHelper? helper;

}