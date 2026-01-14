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

import 'package:flutter/material.dart';

import 'nav.dart';
import 'settings.dart';

/// 亮度选项实体类
/// 用于封装亮度选项的排序序号和显示名称
class BrightnessItem {
  /// 构造函数
  /// [order]: 排序序号（对应系统/亮色/暗色模式）
  /// [name]: 显示名称（如"System"/"Light"/"Dark"）
  BrightnessItem(this.order, this.name);

  /// 排序序号（0=系统，1=亮色，2=暗色）
  final int order;

  /// 亮度模式显示名称
  final String name;
}

/// 亮度数据源管理类（单例模式）
/// 负责管理应用亮度模式的配置、读取和更新
class BrightnessDataSource {
  /// 工厂构造函数：返回单例实例
  factory BrightnessDataSource() => _instance;

  /// 静态单例实例
  static final BrightnessDataSource _instance =
      BrightnessDataSource._internal();

  /// 私有构造函数：防止外部实例化
  BrightnessDataSource._internal();

  /// 应用设置实例（用于读写本地配置）
  AppSettings? _settings;

  /// 亮度模式常量 - 跟随系统
  static const int kSystem = 0;

  /// 亮度模式常量 - 亮色模式
  static const int kLight = 1;

  /// 亮度模式常量 - 暗色模式
  static const int kDark = 2;

  /// 亮度模式名称列表（与常量序号对应）
  final List<String> _names = ['System', 'Light', 'Dark'];

  /// 初始化方法
  /// [settings]: 应用设置实例，用于读写配置
  Future<void> init(AppSettings settings) async {
    _settings = settings;
  }

  /// 获取当前亮度模式（Brightness枚举类型）
  Brightness get current => isDarkMode ? Brightness.dark : Brightness.light;

  /// 设置亮度模式
  /// [order]: 亮度模式序号（kSystem/kLight/kDark）
  /// 返回值: 是否设置成功
  Future<bool> setBrightness(int order) async {
    // 更新本地设置
    bool ok = await _settings!.setValue('brightness', order);
    // 断言：设置失败时触发断言错误（调试模式下）
    assert(ok, 'failed to set brightness: $order');
    // 强制刷新应用（应用主题）
    // await forceAppUpdate();
    await appTool.forceAppUpdate();
    return ok;
  }

  /// 判断当前是否为暗色模式
  bool get isDarkMode {
    // 获取当前亮度模式序号
    int order = getCurrentBrightnessOrder();
    // 亮色模式： 返回false
    if (order == kLight) {
      return false;
    } 
    // 暗色模式：返回true
    else if (order == kDark) {
      return true;
    } 
    // 跟随系统：返回系统当前的暗色模式状态
    else {
      // return Get.isPlatformDarkMode;
      return appTool.isSystemDarkMode;
    }
  }

  /// 获取当前主题模式（ThemeMode枚举类型）
  ThemeMode get themeMode {
    // 获取当前亮度模式序号
    int order = getCurrentBrightnessOrder();
    // 亮色模式
    if (order == kLight) {
      return ThemeMode.light;
    } 
    // 暗色模式
    else if (order == kDark) {
      return ThemeMode.dark;
    } 
    // 跟随系统
    else {
      return ThemeMode.system;
    }
  }

  /// 获取当前亮度模式序号
  /// 返回值: 默认为kSystem（跟随系统）
  int getCurrentBrightnessOrder() => _settings?.getValue('brightness') ?? kSystem;

  /// 获取当前亮度模式的显示名称
  String getCurrentBrightnessName() => _names[getCurrentBrightnessOrder()];

  //
  //  Sections - 适配列表视图的分区数据方法
  //

  /// 获取分区数量（固定为1个分区）
  int getSectionCount() => 1;

  /// 获取指定分区的条目数量（返回亮度模式选项总数）
  int getItemCount(int section) => _names.length;

  /// 获取指定分区和位置的亮度选项
  /// [sec]: 分区索引（固定为0）
  /// [item]: 条目索引
  /// 返回值: BrightnessItem实例
  BrightnessItem getItem(int sec, int item) => BrightnessItem(item, _names[item]);
}
