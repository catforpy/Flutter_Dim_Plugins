import 'package:dim_client/ok.dart';
import 'package:dim_flutter/src/widgets/alert.dart';
// import 'package:dim_flutter/src/widgets/browser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import '../ui/nav.dart'; // 你的 appTool 所在文件
// import '../ui/language.dart'; // 你的多语言接口

/// 浏览器依赖的外部能力接口（适配 BrowserState + Browser）
abstract class BrowserDeps {
  /// 路由服务：打开新页面（对应 showPage）
  Future<void> showPage({required BuildContext context, required WidgetBuilder builder});

  /// 路由服务：关闭当前页面（对应 appTool.closePage）
  void closePage(BuildContext context);

  /// 多语言翻译（对应 .trParams）
  String translate(String key, {Map<String, String>? params});

  /// 显示弹窗提示（对应 Alert.show）
  void showAlert(BuildContext context, String title, String content);

  /// 外部打开URL（对应 Browser.launchURL）
  void launchURL(BuildContext context, Uri url, {LaunchMode mode = LaunchMode.externalApplication});
}

/// GetX依赖实现（完全适配你的原有逻辑）
class GetxBrowserDeps implements BrowserDeps {
  const GetxBrowserDeps();

  @override
  Future<void> showPage({required BuildContext context, required WidgetBuilder builder}) {
    return showPage(context: context, builder: builder); // 复用你的 showPage
  }

  @override
  void closePage(BuildContext context) {
    appTool.closePage(context); // 复用你的 appTool.closePage
  }

  @override
  String translate(String key, {Map<String, String>? params}) {
    if (params == null) return i18nTranslator.translate(key);
    return i18nTranslator.translate(key,params: params); // 复用 GetX 多语言
  }

  @override
  void showAlert(BuildContext context, String title, String content) {
    Alert.show(context, title, content); // 复用你的 Alert.show
  }

  @override
  void launchURL(BuildContext context, Uri url, {LaunchMode mode = LaunchMode.externalApplication}) {
    canLaunchUrl(url).then((can) {
      if (!can && context.mounted) {
        Alert.show(context, i18nTranslator.translate('Error'), 
        i18nTranslator.translate('Cannot launch "@url".',
        params: {
          'url': _shortUrlString(url.toString()),
        }));
        Log.warning('cannot launch URL: $url');
      }
      launchUrl(url, mode: mode).then((ok) {
        if (!context.mounted) {
          Log.warning('context unmounted: $context');
        } else if (ok) {
          Log.info('launch URL: $url');
        } else {
          Alert.show(context, i18nTranslator.translate('Error'), 
          i18nTranslator.translate('Failed to launch "@url".',
          params: {
            'url': _shortUrlString(url.toString()),
          }));
        }
      });
    });
  }

  /// 复用原有缩短URL逻辑
  String _shortUrlString(String? urlString) {
    if (urlString == null) return '';
    if (urlString.length <= 64) return urlString;
    var head = urlString.substring(0, 50);
    var tail = urlString.substring(urlString.length - 12);
    return '$head...$tail';
  }

}

/// 原生依赖实现（无GetX，适配BLoC）
class DefaultBrowserDeps implements BrowserDeps {
  const DefaultBrowserDeps();

  @override
  Future<void> showPage({required BuildContext context, required WidgetBuilder builder}) {
    // 原生路由打开页面
    return Navigator.push(context, MaterialPageRoute(builder: builder));
  }

  @override
  void closePage(BuildContext context) {
    // 原生路由关闭页面
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  String translate(String key, {Map<String, String>? params}) {
    // 原生字符串替换（替代 GetX trParams）
    if (params == null) return key;
    String result = key;
    params.forEach((k, v) => result = result.replaceAll('@$k', v));
    return result;
  }

  @override
  void showAlert(BuildContext context, String title, String content) {
    // 原生弹窗（替代 Alert.show）
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(title: Text(title), content: Text(content)),
    );
  }

  @override
  void launchURL(BuildContext context, Uri url, {LaunchMode mode = LaunchMode.externalApplication}) {
    // 原生 url_launcher 打开URL
    canLaunchUrl(url).then((can) {
      if (can) launchUrl(url, mode: mode);
    });
  }
}

// 全局实例
const BrowserDeps getxBrowserDeps = const GetxBrowserDeps();
const BrowserDeps defaultBrowserDeps = const DefaultBrowserDeps();