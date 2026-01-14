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

/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2024 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2024 Albert Moky
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
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_windows/webview_windows.dart';

import '../ui/styles.dart';
import 'browser.dart';
// import 'browser_deps.dart'; // 🔥 导入BrowserDeps接口

/// 浏览器状态类（Windows平台）
/// 基于webview_windows实现的内置浏览器
/// 支持：
///   1. Windows
///
/// 文档参考：
///   https://pub.dev/packages/webview_windows

class BrowserState extends State<Browser> {

  /// Windows WebView控制器
  final WebviewController _controller = WebviewController();

  /// 当前页面URL（初始为widget.url）
  Uri? _url;
  /// 当前页面标题
  String? _title;

  /// 获取当前URL（优先使用当前页面URL，否则使用初始URL）
  Uri get url => _url ?? widget.url;
  /// 获取当前页面标题（为空返回空字符串）
  String get title => _title ?? '';

  /// 获取HTML内容（仅初始加载时有效）
  String? get html => _url == null ? widget.html : null;

  /// 构建Windows平台浏览器UI
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    // 导航栏
    appBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
      // 页面标题（单行省略）
      middle: Text(title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Styles.titleTextStyle,
      ),
      // 🔥 新增关闭按钮（和其他平台保持一致）
      trailing: IconButton(
        onPressed: () => widget.deps.closePage(context),
        icon: const Icon(
          Icons.close,
          size: Styles.navigationBarIconSize,
        ),
      ),
    ),
    // 主体内容：Windows WebView
    body: Webview(
      _controller,
      // 权限请求回调
      permissionRequested: _onPermissionRequested,
    ),
  );

  /// 组件销毁时释放资源
  @override
  void dispose() {
    _controller.dispose(); // 释放WebView控制器
    super.dispose();
  }

  /// 初始化状态
  @override
  void initState() {
    super.initState();
    // 初始化平台相关状态
    initPlatformState();
  }

  /// 初始化Windows WebView环境和加载内容
  Future<void> initPlatformState() async {
    // 可选：初始化webview环境
    // 可自定义用户数据目录、浏览器可执行文件目录、Chromium命令行参数
    //await WebviewController.initializeEnvironment(
    //    additionalArguments: '--show-fps-counter');

    try {
      // 初始化WebView控制器
      await _controller.initialize();

      // 设置WebView背景透明
      await _controller.setBackgroundColor(Colors.transparent);
      // 禁止弹出窗口
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

      // 监听页面标题变化
      _controller.title.listen((title) {
        if (mounted) {
          setState(() {
            _title = title;
          });
        }
      });

      // 监听URL变化
      _controller.url.listen((url) {
        if (mounted) {
          setState(() {
            _url = Uri.tryParse(url);
          });
        }
      });

      // 加载内容：优先加载HTML字符串，否则加载URL
      var content = html;
      if (content == null) {
        await _controller.loadUrl(widget.url.toString());
      } else {
        await _controller.loadStringContent(content);
      }

      // 更新UI
      if (mounted) {
        setState(() {});
      }
    } on PlatformException catch (e) {
      // 🔥 替换GetX弹窗为接口调用
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.deps.showAlert(
          context,
          widget.deps.translate('Error'), // 多语言通过接口
          '${widget.deps.translate('Code')}: ${e.code}\n${widget.deps.translate('Message')}: ${e.message}',
        );
      });
    }
  }

  /// WebView权限请求处理
  /// [url] - 请求权限的URL
  /// [kind] - 权限类型
  /// [isUserInitiated] - 是否用户主动触发
  /// 返回：权限决策（允许/拒绝/无）
  Future<WebviewPermissionDecision> _onPermissionRequested(
      String url, WebviewPermissionKind kind, bool isUserInitiated) async {
    // 🔥 替换全局navigatorKey和GetX多语言为接口兼容方式
    final decision = await showDialog<WebviewPermissionDecision>(
      context: context, // 使用当前上下文，移除全局navigatorKey依赖
      builder: (BuildContext context) => AlertDialog(
        title: Text(widget.deps.translate('WebView permission requested')),
        content: Text(widget.deps.translate('WebView has requested permission \'$kind\'')),
        actions: <Widget>[
          // 拒绝按钮
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.deny),
            child: Text(widget.deps.translate('Deny')),
          ),
          // 允许按钮
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.allow),
            child: Text(widget.deps.translate('Allow')),
          ),
        ],
      ),
    );

    // 默认返回无决策
    return decision ?? WebviewPermissionDecision.none;
  }

}

// 🔥 移除全局navigatorKey（改为使用当前上下文）
// final navigatorKey = GlobalKey<NavigatorState>();