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

import 'package:flutter/cupertino.dart';

import 'package:dim_client/ok.dart';
import 'package:dim_client/ok.dart' as lnc;
import 'package:dim_client/client.dart';

import '../common/constants.dart';
import '../client/shared.dart';
import '../network/station_speed.dart';
import '../ui/styles.dart';
import '../utils/syntax.dart';

/// 带状态的标题视图组件
/// 监听服务器连接状态变化，自动更新标题显示（包含连接状态信息）
class StatedTitleView extends StatefulWidget {
  /// 构造函数
  /// [getTitle] - 获取基础标题的回调函数
  /// [style] - 文字样式（必填）
  const StatedTitleView(this.getTitle, {required this.style, super.key});

  /// 获取基础标题的回调函数
  final String Function() getTitle;
  /// 文字样式
  final TextStyle style;

  /// 快速创建带状态的标题视图（使用默认样式）
  /// [context] - 上下文
  /// [getTitle] - 获取基础标题的回调函数
  /// 返回：StatedTitleView实例
  static StatedTitleView from(BuildContext context, String Function() getTitle) =>
      StatedTitleView(getTitle, style: Styles.titleTextStyle);

  /// 创建状态对象
  @override
  State<StatefulWidget> createState() => _TitleState();

}

/// 带状态的标题视图状态类
/// 实现Observer监听服务器状态变更通知，自动刷新标题
class _TitleState extends State<StatedTitleView> implements lnc.Observer {
  /// 构造函数：注册服务器状态变更通知监听
  _TitleState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kServerStateChanged);
  }

  /// 销毁时移除通知监听
  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kServerStateChanged);
    super.dispose();
  }

  /// 接收通知回调
  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    // 服务器状态变更通知
    if (name == NotificationNames.kServerStateChanged) {
      GlobalVariable shared = GlobalVariable();
      int state = shared.terminal.sessionStateOrder; // 获取会话状态码
      Log.info('session state: $state');              // 日志输出状态
      // 状态变更时刷新UI
      if (mounted) {
        setState(() {
        });
      }
    }
  }

  /// 重新加载状态并刷新UI
  Future<void> _reload() async {
    GlobalVariable shared = GlobalVariable();
    int state = shared.terminal.sessionStateOrder; // 获取会话状态码
    Log.info('session state: $state');              // 日志输出状态
    // 刷新UI
    if (mounted) {
      setState(() {
      });
    }
    // 会话状态为初始化时，尝试重新连接服务器
    if (state == SessionStateOrder.init.index) {
      // 进入此页面之前必须已设置当前用户，因此直接尝试重连
      // current user must be set before enter this page,
      // so just do connecting here.
      shared.terminal.reconnect();
    }
  }

  /// 初始化状态：加载初始状态
  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// 构建标题组件（包含状态信息）
  @override
  Widget build(BuildContext context) => Text(
    _titleWithState(widget.getTitle()), // 拼接状态后的标题
    style: widget.style,                // 文字样式
  );

}

/// 拼接基础标题和服务器状态信息
/// [title] - 基础标题
/// 返回：带状态的完整标题
String _titleWithState(String title) {
  GlobalVariable shared = GlobalVariable();
  String? sub = shared.terminal.sessionStateText; // 获取会话状态文本
  
  // 无状态文本：仅裁剪过长的标题
  if (sub == null) {
    // trim title（裁剪标题）
    if (VisualTextUtils.getTextWidth(title) > 25) { // 标题宽度超过25
      title = VisualTextUtils.getSubText(title, 22); // 截取前22个字符
      title = '$title...';                           // 添加省略号
    }
    return title;
  } 
  // 状态为断开连接：测试服务器速度
  else if (sub == 'Disconnected') {
    _testSpeed();
  }
  
  // 有状态文本：裁剪标题并拼接状态
  // trim title（裁剪标题）
  if (VisualTextUtils.getTextWidth(title) > 15) { // 标题宽度超过15
    title = VisualTextUtils.getSubText(title, 12); // 截取前12个字符
    title = '$title...';                           // 添加省略号
  }
  return '$title ($sub)'; // 拼接格式：标题 (状态)
}

/// 测试服务器连接速度（异步）
void _testSpeed() async {
  StationSpeeder speeder = StationSpeeder();
  await speeder.reload();  // 重新加载服务器列表
  await speeder.testAll(); // 测试所有服务器速度
}