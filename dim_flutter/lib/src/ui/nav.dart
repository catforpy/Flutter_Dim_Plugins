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

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_flutter/src/dim_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Flutter国际化支持
import 'package:get/get.dart';

import '../dim_widgets.dart';
import 'app_tool_interface.dart'; // 导入抽象接口
import 'brightness.dart';
import 'burn_after_reading.dart';
import 'language.dart';
import 'settings.dart';

/// GetX实现的应用工具类
/// 实现AppToolInterface接口，封装所有GetX相关操作
class GetXAppTool implements 
  AppToolInterface, 
  ThemeBuilderInterface      // 主题能力
  { 
  // 单例模式（保证全局唯一）
  static final GetXAppTool _instance = GetXAppTool._internal();
  factory GetXAppTool() => _instance;
  GetXAppTool._internal();

  /// 主题构建器实现
  @override
  ThemeData buildLightTheme() => ThemeData.light(useMaterial3: true);

  @override
  ThemeData buildDarkTheme() => ThemeData.dark(useMaterial3: true);

  /// 启动应用（GetX实现）
  @override
  void launchApp(Widget home, {bool debug = true}) {
    runApp(GetMaterialApp(
      debugShowCheckedModeBanner: debug,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: BrightnessDataSource().themeMode,
      home: home,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
      ],
      translations: LanguageDataSource.translations,
      fallbackLocale: const Locale('en', 'US'),
    ));
  }

  /// 强制更新应用主题（GetX实现）
  @override
  Future<void> forceAppUpdate() async {
    if (BrightnessDataSource().isDarkMode) {
      Get.changeThemeMode(ThemeMode.dark);
      Get.changeTheme(buildDarkTheme());
    } else {
      Get.changeThemeMode(ThemeMode.light);
      Get.changeTheme(buildLightTheme());
    }
    await Get.forceAppUpdate();
  }

  /// 显示新页面（GetX路由实现）
  @override
  Future<void> showPage({required BuildContext context, required WidgetBuilder builder}) async {
    Get.to(builder(context));
  }

  /// 关闭当前页面（GetX路由实现）
  @override
  void closePage<T extends Object?>(BuildContext context, [T? result]) {
    Get.back();
  }

  /// 初始化应用核心配置（GetX环境下的初始化）
  @override
  Future<void> initFacade() async {
    // 0. 加载应用设置
    AppSettings settings = AppSettings();
    await settings.load();
    // 1. 初始化亮度配置
    var bright = BrightnessDataSource();
    await bright.init(settings);
    // 2. 初始化多语言配置
    var language = LanguageDataSource();
    await language.init(settings);
    // 3. 初始化阅后即焚配置
    var burn = BurnAfterReadingDataSource();
    await burn.init(settings);
  }

  @override
  bool get isSystemDarkMode {
    // 封装 Get.isPlatformDarkMode，对外隐藏 Get 依赖
    return Get.isPlatformDarkMode;
  }

  @override
  ThemeMode get currentThemeMode {
    // 可选：也可以把 BrightnessDataSource 的 themeMode 逻辑移到这里
    return BrightnessDataSource().themeMode;
  }

  // ============================== 屏幕尺寸接口 ==============================
  @override
  Size get windowSize {
    // 封装 Get.size，对外隐藏GetX依赖
    if (Get.context == null) {
      Log.error('Get.context is null, return default size');
      return const Size(375, 812); // 默认手机尺寸（兜底）
    }
    return Get.size;
  }

  @override
  List<DeviceOrientation> get deviceOrientationsAfterFullScreen {
    Size size = windowSize;
    if (size.width <= 0 || size.height <= 0) {
      Log.error('window size error: $size');
      return DeviceOrientation.values; // 兜底：支持所有方向
    } else if (size.width < 640 || size.height < 640) {
      Log.info('window size: $size, this is a phone');
      return [DeviceOrientation.portraitUp]; // 手机仅竖屏
    } else {
      Log.info('window size: $size, this is a tablet?');
      return DeviceOrientation.values; // 平板/桌面支持所有方向
    }
  }

}

/// GetX版翻译实现（完全复用GetX的.tr，功能和原来一致）
class GetXTranslator implements I18nTranslatorInterface {
  factory GetXTranslator() => _instance;
  static final GetXTranslator _instance = GetXTranslator._internal();
  GetXTranslator._internal();

  @override
  String translate(String key, {Map<String, String>? params}) {
    return params == null ? key.tr : key.trParams(params);
  }
}

/// 全局翻译入口（GetX架构下直接用这个）
final I18nTranslatorInterface i18nTranslator = GetXTranslator();
/// 全局工具入口（对外只暴露接口，隐藏具体实现）
/// 未来切换BLoC时，只需修改这里的实例化对象
final AppToolInterface appTool = GetXAppTool();