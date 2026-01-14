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

import 'package:dim_client/plugins.dart';

/// 状态上报命令接口
/// 用于客户端向服务器上报在线/离线状态
/// 数据结构规范：
/// {
///     type : 0x88,        // 命令类型
///     sn   : 123,         // 序列号
///     command : "report", // 命令名称
///     title   : "online", // 状态标题（online/offline）
///     //---- 扩展信息
///     time    : 1234567890, // 时间戳
/// }
abstract interface class ReportCommand implements Command {
  
  // ignore_for_file: constant_identifier_names
  static const String REPORT  = 'report';   // 命令名称常量
  static const String ONLINE  = 'online';   // 在线状态
  static const String OFFLINE = 'offline';  // 离线状态

  /// 获取/设置状态标题（online/offline）
  String get title;
  set title(String text);

  //
  //  工厂方法
  //

  /// 创建状态上报命令
  /// [text] 状态标题（ONLINE/OFFLINE）
  /// 返回：状态上报命令实例
  static ReportCommand fromTitle(String text) => BaseReportCommand.fromTitle(text);
}

/// 状态上报命令实现类
/// 继承BaseCommand，实现ReportCommand接口
class BaseReportCommand extends BaseCommand implements ReportCommand {
  /// 从字典初始化状态上报命令
  /// [dict] 包含上报命令字段的字典
  BaseReportCommand(super.dict);

  /// 构造方法：从状态标题创建命令
  /// [text] 状态标题（ONLINE/OFFLINE）
  BaseReportCommand.fromTitle(String text) : super.fromName(ReportCommand.REPORT) {
    title = text;  // 设置状态标题
  }

  /// 实现title获取逻辑：从字典中获取标题字符串
  @override
  String get title => getString('title') ?? '';

  /// 实现title设置逻辑：将标题存入字典
  @override
  set title(String text) => this['title'] = text;

}