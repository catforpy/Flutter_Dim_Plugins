import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// Web页面分享回调函数类型（和原代码保持一致）
typedef OnWebShare = void Function(Uri url, {
  required String title, required String? desc, required String? icon,
});

/// 浏览器核心服务接口
/// 封装所有浏览器相关能力，解耦具体实现（GetX/BLoC/原生）
abstract class BrowserService {
  /// 打开内置浏览器（字符串URL）
  void open(
    BuildContext context,
    String? urlString, {
    OnWebShare? onWebShare,
  });

  /// 打开内置浏览器（Uri对象）
  void openURL(
    BuildContext context,
    Uri url, {
    OnWebShare? onWebShare,
  });

  /// 外部打开URL（使用系统浏览器，字符串URL）
  void launch(
    BuildContext context,
    String? urlString, {
    LaunchMode mode = LaunchMode.externalApplication,
  });

  /// 外部打开URL（使用系统浏览器，Uri对象）
  void launchURL(
    BuildContext context,
    Uri url, {
    LaunchMode mode = LaunchMode.externalApplication,
  });

  /// 创建WebView组件（用于嵌入其他页面）
  Widget view(
    BuildContext context,
    Uri url, {
    String? html,
  });

  /// 缩短URL字符串（超长时省略中间部分）
  String shortUrlString(String? urlString);
}