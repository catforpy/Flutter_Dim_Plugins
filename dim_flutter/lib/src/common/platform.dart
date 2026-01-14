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

import 'dart:io';

import 'package:flutter/foundation.dart';

/// 设备平台工具类
/// 提供跨平台的设备类型判断、系统信息获取和组件适配补丁
class DevicePlatform {

  /// 判断是否为桌面平台（Windows/Linux/macOS，排除Web）
  static bool get isDesktop => !isWeb && (isWindows || isLinux || isMacOS);

  /// 判断是否为移动平台（Android/iOS）
  static bool get isMobile => isAndroid || isIOS;

  /// 判断是否为Web平台
  static bool get isWeb => kIsWeb;

  /// 判断是否为Windows平台（排除Web）
  static bool get isWindows => !kIsWeb && Platform.isWindows;

  /// 判断是否为Linux平台（排除Web）
  static bool get isLinux => !kIsWeb && Platform.isLinux;

  /// 判断是否为macOS平台（排除Web）
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  /// 判断是否为Android平台（排除Web）
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// 判断是否为Fuchsia平台（排除Web）
  static bool get isFuchsia => !kIsWeb && Platform.isFuchsia;

  /// 判断是否为iOS平台（排除Web）
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// 获取系统区域名称（Web平台默认返回'en_US'）
  static String get localeName => kIsWeb ? 'en_US' : Platform.localeName;

  /// 获取操作系统名称（Web平台返回'Web Browser'）
  static String get operatingSystem => kIsWeb ? 'Web Browser' : Platform.operatingSystem;

  /// SQLite适配补丁
  /// 为不同平台配置对应的SQLite数据库工厂
  static void patchSQLite(){
    // 避免重复打补丁
    if(_sqlitePatched){
      return;
    }
    // Web平台使用Web版本的SQLite工厂
    // if (isWeb) {
    //   // Change default factory on the web
    //   databaseFactory = databaseFactoryFfiWeb;
    // } else if (isWindows || isLinux) {
    //   // Windows/Linux平台初始化FFI并使用FFI版本的SQLite工厂
    //   // Initialize FFI
    //   sqfliteFfiInit();
    //   // Change the default factory
    //   databaseFactory = databaseFactoryFfi;
    // }
    _sqlitePatched = true;
  }

  /// SQLite补丁是否已应用标记
  static bool _sqlitePatched = false;

  /// 视频播放器适配补丁
  /// 为不同平台注册对应的视频播放器实现
  static void patchVideoPlayer(){
    // 避免重复打补丁
    if (_videoPlayerPatched) {
      return;
    }
    // Android/iOS/macOS/Web平台使用官方视频播放器
    // if (isAndroid || isIOS || isMacOS || isWeb) {
    //   // Video Player support:
    //   // - Android SDK 16+
    //   // - iOS 12.0+
    //   // - macOS 10.14+
    //   // - Web Any*
    // } else {
    //   // Windows/Linux平台注册自定义视频播放器
    //   // - Windows
    //   // - Linux
    //   // ...
    //   Log.info('register video player for Windows, Linux, ...');
    //   // patch for windows
    //   registerWith();
    // }
    _videoPlayerPatched = true;
  }
  /// 视频播放器补丁是否已应用标记
  static bool _videoPlayerPatched = false;
}

/// TODO: 暗黑模式下Markdown块引用颜色适配补丁
///
///   补丁文件路径: '/Users/moky/.pub-cache/hosted/pub.flutter-io.cn/flutter_markdown-0.6.22+1/lib/src/style_sheet.dart'
///   补丁行号: 144
///
///   原代码:
///
///     class MarkdownStyleSheet {
///       ...
///       factory MarkdownStyleSheet.fromTheme(ThemeData theme) {
///         ...
///         blockquoteDecoration: BoxDecoration(
///           color: Colors.blue.shade100,  // 固定浅色背景，暗黑模式下显示异常
///           borderRadius: BorderRadius.circular(2.0),
///         ),
///
///   修正后代码:
///
///     class MarkdownStyleSheet {
///       ...
///       factory MarkdownStyleSheet.fromTheme(ThemeData theme) {
///         ...
///         blockquoteDecoration: BoxDecoration(
///           // 根据主题亮度动态设置背景色
///           color: theme.brightness == Brightness.dark
///               ? Colors.grey.shade800  // 暗黑模式使用深灰色
///               : Colors.blue.shade100, // 亮色模式保持原蓝色
///           borderRadius: BorderRadius.circular(2.0),
///         ),