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
import 'package:dim_flutter/src/widgets/browser_deps.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dim_client/ok.dart';

import '../utils/html.dart';
import 'browser_service.dart';
import 'browser_deps.dart';

import 'browser_aim.dart';  // Android, iOS, macOS 平台实现
// import 'browser_win.dart';  // Windows 平台实现（注释掉，按需启用）

/// 浏览器组件（跨平台）
/// 统一封装不同平台的WebView实现，提供一致的API
class Browser extends StatefulWidget implements BrowserService {
  /// 构造函数
  /// [url] - 初始URL（必填）
  /// [html] - 可选HTML内容（优先于URL加载）
  /// [onWebShare] - 分享回调
  /// [deps] - 外部依赖（默认使用GetX实现，可切换为原生）
  const Browser({
    super.key,
    required this.url,
    this.html,
    this.onWebShare,
    this.deps = getxBrowserDeps, // 默认兼容原有GetX逻辑
  });

  /// 初始URL
  final Uri url;
  /// HTML内容（可选）
  final String? html;
  /// 分享回调
  final OnWebShare? onWebShare;
  /// 外部依赖（解耦路由/多语言/弹窗）
  final BrowserDeps deps;

  


  // ------------------- BrowserService 接口实现 -------------------
  @override
  void open(
    BuildContext context,
    String? urlString, {
    OnWebShare? onWebShare,
  }) {
    // 解析URL字符串
    Uri? url = HtmlUri.parseUri(urlString);
    Log.info('URL length: ${urlString?.length}: $url');
    // 解析失败显示错误提示
    if (url == null) {
      deps.showAlert(context, 'Error', 'Failed to open URL: $urlString');
    } else {
      // 解析成功，打开内置浏览器
      openURL(context, url, onWebShare: onWebShare);
    }
  }

  @override
  void openURL(
    BuildContext context,
    Uri url, {
    OnWebShare? onWebShare,
  }) {
    deps.showPage(
      context: context,
      builder: (context) => Browser(
        url: url,
        onWebShare: onWebShare,
        deps: deps, // 传递依赖实例
      ),
    );
  }

  @override
  void launch(
    BuildContext context,
    String? urlString, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) {
    // 解析URL字符串
    Uri? url = HtmlUri.parseUri(urlString);
    Log.info('URL length: ${urlString?.length}: $url');
    // 解析失败显示错误提示
    if (url == null) {
      deps.showAlert(
        context,
        'Error',
        deps.translate('Failed to launch "@url".', params: {
          'url': shortUrlString(urlString),
        }),
      );
    } else {
      // 解析成功，外部打开URL
      launchURL(context, url, mode: mode);
    }
  }

  @override
  void launchURL(
    BuildContext context,
    Uri url, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) {
    canLaunchUrl(url).then((can) {
      // 检查是否可以打开URL
      if (!can && context.mounted) {
        // FIXME: adding 'queries' in AndroidManifest.xml
        deps.showAlert(
          context,
          'Error',
          deps.translate('Cannot launch "@url".', params: {
            'url': shortUrlString(url.toString()),
          }),
        );
        Log.warning('cannot launch URL: $url');
      }
      // 尝试打开URL
      launchUrl(url, mode: mode).then((ok) {
        if (!context.mounted) {
          Log.warning('context unmounted: $context');
        } else if (ok) {
          // 打开成功
          Log.info('launch URL: $url');
        } else {
          // 打开失败
          deps.showAlert(
            context,
            'Error',
            deps.translate('Failed to launch "@url".', params: {
              'url': shortUrlString(url.toString()),
            }),
          );
        }
      });
    });
  }

  @override
  Widget view(
    BuildContext context,
    Uri url, {
    String? html,
  }) {
    return Browser(
      url: url,
      html: html,
      deps: deps,
    );
  }

  @override
  String shortUrlString(String? urlString) {
    if (urlString == null) {
      return '';
    } else if (urlString.length <= 64) {
      return urlString;
    }
    // 截取前50个字符 + ... + 最后12个字符
    var head = urlString.substring(0, 50);
    var tail = urlString.substring(urlString.length - 12);
    return '$head...$tail';
  }

  // ------------------- 静态工具方法（兼容原有调用方式） -------------------
  /// 静态打开方法（兼容原有调用）
  static void openStatic(
    BuildContext context,
    String? urlString, {
    OnWebShare? onWebShare,
    BrowserDeps deps = getxBrowserDeps,
  }) {
    Browser(url: Uri.parse('about:blank'), deps: deps).open(
      context,
      urlString,
      onWebShare: onWebShare,
    );
  }

  /// 静态launch方法（兼容原有调用）
  static void launchStatic(
    BuildContext context,
    String? urlString, {
    LaunchMode mode = LaunchMode.externalApplication,
    BrowserDeps deps = getxBrowserDeps,
  }) {
    Browser(url: Uri.parse('about:blank'), deps: deps).launch(
      context,
      urlString,
      mode: mode,
    );
  }

  /// 创建状态对象（根据平台选择不同的实现）
  @override
  State<Browser> createState() => BrowserState();
}