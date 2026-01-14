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

import 'package:dim_flutter/src/widgets/browser_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:dim_client/ok.dart';

import '../ui/icons.dart';
import '../ui/nav.dart';
import '../ui/styles.dart';
import '../utils/html.dart';

import 'browser.dart';

/// 浏览器状态类（Android/iOS/macOS平台）
/// 基于flutter_inappwebview实现的内置浏览器
/// 支持：
///   1. Android
///   2. iOS
///   3. macOS
///
/// 文档参考：
///   https://inappwebview.dev/docs/intro/

class BrowserState extends State<Browser> {

  /// WebView 控制器
  InAppWebViewController? _controller;

  /// 页面加载进度（0-100）
  int _progress = 0;

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

  /// 构建浏览器页面UI
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
      // 右侧操作按钮（加载进度/分享/关闭）
      trailing: _naviItems(context),
    ),
    // 主体内容
    body: Stack(
      alignment: AlignmentDirectional.bottomStart,
      children: [
        // 处理返回键（优先返回上一页，否则关闭页面）
        WillPopScope(
          child: _webView(context), 
          onWillPop: () async {
            var controller = _controller;
            // 如果可以返回上一页，则执行返回
            if(controller != null && await controller.canGoBack()){
              await controller.goBack();
              return false;   // 组织默认返回行为
            }
            return true;
          },
        ),
        // 加载进度 < 100  时显示进度条
        if(_progress < 100)
          _statusBar(),    
      ],
    ),
  );

  /// 构建导航栏右侧操作项
  /// 加载中：显示进度指示器
  /// 加载完成：显示分享按钮 + 关闭按钮
  Widget? _naviItems(BuildContext context) {
    // 第一个按钮：加载中显示进度指示器，完成显示分享按钮
    Widget? one = _progress <= 99 ? _indicator() : _shareButton();
    // 第二个按钮：WebView初始化完成后显示关闭按钮
    Widget? two = _controller == null ? null : IconButton(
      onPressed: () => widget.deps.closePage(context), 
      icon: const Icon(
        AppIcons.closeIcon,
        size: Styles.navigationBarIconSize,
      )
    );
    // 组合按钮：根据按钮存在情况返回
    return one == null ? two : two == null ? one : Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        one,
        two,
      ],
    );
  }

  /// 构建加载进度指示器
  Widget _indicator() => const SizedBox(
    width: Styles.navigationBarIconSize, height: Styles.navigationBarIconSize,
    child: CircularProgressIndicator(strokeWidth: 2.0), // 细圆环进度条
  );

  ///构建分享按钮
  Widget? _shareButton(){
    OnWebShare? onShare = widget.onWebShare;
    // 物分享回调时不显示
    if(onShare == null){
      return null;
    }
    // 确定分享的目标URL(避免about:blank)
    Uri target = url;
    if(target.toString() == 'about:blank'){
      target = widget.url;
    }
    return IconButton(
      icon: const Icon(
        AppIcons.shareIcon,
        size: Styles.navigationBarIconSize,
      ),
      // 点击出发分享回调
      onPressed: () => onShare(target,title:title,desc:null,icon:null),
    );
  }

  /// 构建WebView组件
  Widget _webView(BuildContext ctx) => InAppWebView(
    // 初始URL请求
    initialUrlRequest: _BrowserUtils.getURLRequest(url),
    // 初始HTML内容（优先于URL）
    initialData: _BrowserUtils.getWebViewData(url, html),
    // WebView配置项
    initialOptions: _BrowserUtils.getWebViewOptions(),
    // 加载进度变化回调
    onProgressChanged: (controller, progress) => setState(() {
      _progress = progress;
    }),
    // 页面开始加载回调
    onLoadStart: (controller, url) => setState(() {
      _controller = controller; // 保存控制器
      _url = url; // 更新当前URL
    }),
    // 页面标题变化回调
    onTitleChanged: (controller, title) => setState(() {
      _title = title; // 更新页面标题
    }),
    // URL加载拦截处理
    shouldOverrideUrlLoading: (controller, action) {
      var url = action.request.url;
      // 系统支持的URL协议，允许内部加载
      if (url == null || systemSchemes.contains(url.scheme)) {
        Log.info('loading URL: $url');
        return Future.value(NavigationActionPolicy.ALLOW);
      }
      // 非系统协议，外部打开
      // Browser.launchURL(ctx, url);
      widget.deps.launchURL(ctx, url);
      // 取消内部加载
      return Future.value(NavigationActionPolicy.CANCEL);
    },
  );

  /// 系统支持的URL协议列表（允许内部WebView加载）
  static final List<String> systemSchemes = [
    "http", "https",    // 网页
    "file",             // 文件
    "chrome",           // Chrome扩展
    "data",             // 数据URL
    "javascript",       // JS脚本
    "about",            // 关于页面
  ];

  /// 构建加载状态条（底部显示进度和URL）
  Widget _statusBar() => Container(
    color: Colors.black54, // 半透明黑色背景
    padding: const EdgeInsets.fromLTRB(20, 4, 8, 16),
    child: Text('$_progress% | $url ...',
      style: const TextStyle(
        fontSize: 10,
        color: Colors.white,
        overflow: TextOverflow.ellipsis,
        decoration: TextDecoration.none,
      ),
    ),
  );
}

/// 浏览器工具类（内部使用）
abstract class _BrowserUtils {

  //
  //  InAppWebView 辅助方法
  //

  /// 创建URL请求对象
  /// [url] - 目标URL
  /// 返回：普通URL返回URLRequest，dataURL返回null
  static URLRequest? getURLRequest(Uri url) {
    String? html = HtmlUri.getHtmlString(url);
    if (html == null) {
      // http/https等普通URL
      return URLRequest(
        url: WebUri.uri(url),
      );
    } else {
      // data:text/html 类型URL，使用initialData加载
      return null;
    }
  }

  /// 创建初始HTML数据对象
  /// [url] - 目标URL
  /// [html] - HTML内容
  /// 返回：有HTML内容返回InAppWebViewInitialData，否则返回null
  static InAppWebViewInitialData? getWebViewData(Uri url, String? html) {
    html ??= HtmlUri.getHtmlString(url);
    if (html == null) {
      // 无HTML内容，使用URL加载
      return null;
    } else {
      // 有HTML内容，直接加载字符串
      return InAppWebViewInitialData(
        data: html,
        // TODO: baseUrl  // 待实现：设置基础URL
      );
    }
  }

  /// 获取WebView配置项
  static InAppWebViewGroupOptions getWebViewOptions() => InAppWebViewGroupOptions(
      // 跨平台配置
      crossPlatform: InAppWebViewOptions(
        useShouldOverrideUrlLoading: true, // 启用URL加载拦截
        mediaPlaybackRequiresUserGesture: false, // 自动播放媒体
      ),
      // Android特有配置
      android: AndroidInAppWebViewOptions(
        useHybridComposition: true, // 使用混合合成模式（性能更好）
        forceDark: AndroidForceDark.FORCE_DARK_AUTO, // 自动深色模式
      ),
      // iOS特有配置
      ios: IOSInAppWebViewOptions(
        allowsInlineMediaPlayback: true, // 允许内联媒体播放
      )
  );

}
