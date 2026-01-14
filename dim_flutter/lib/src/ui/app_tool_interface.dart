import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 应用核心工具抽象接口
/// 隔离路由、主题、初始化等能力的具体实现（GetX/BLoC/原生）
abstract class AppToolInterface {
  /// 启动应用
  void launchApp(Widget home, {bool debug = true});

  /// 强制更新应用主题和状态
  Future<void> forceAppUpdate();

  /// 显示新页面（路由跳转）
  Future<void> showPage({required BuildContext context, required WidgetBuilder builder});

  /// 关闭当前页面
  void closePage<T extends Object?>(BuildContext context, [T? result]);

  /// 初始化应用核心配置
  Future<void> initFacade();

  //================================系统主题相关接口==================================
  /// 判断当前系统是否为暗黑模式（替代 Get.isPlatformDarkMode）
  bool get isSystemDarkMode;

  /// 获取当前主题模式（封装 ThemeMode 相关逻辑）
  ThemeMode get currentThemeMode;

  //================================屏幕尺寸相关接口==================================
  /// 获取应用窗口的逻辑尺寸（替代 Get.size）
  Size get windowSize;

  /// 根据窗口尺寸获取退出全屏后的屏幕方向（复用视频播放器的逻辑）
  List<DeviceOrientation> get deviceOrientationsAfterFullScreen;
}

/// 主题构建器抽象接口
abstract class ThemeBuilderInterface {
  /// 构建浅色主题
  ThemeData buildLightTheme();

  /// 构建深色主题
  ThemeData buildDarkTheme();
}

// 3. 本地化接口（独立拆分，仅解耦.tr）
abstract class I18nTranslatorInterface {
  String translate(String key, {Map<String, String>? params});
}



