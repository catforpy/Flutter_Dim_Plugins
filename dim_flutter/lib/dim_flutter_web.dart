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

import 'dart:html' as html show window;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'dim_flutter_platform_interface.dart';

/// DimFlutter插件的Web端实现类
/// 继承自DimFlutterPlatform，适配Web平台的接口实现
class DimFlutterWeb extends DimFlutterPlatform {
  /// 构造函数：创建Web端实现实例
  DimFlutterWeb();

  /// 注册Web端插件
  /// [registrar] - Web插件注册器
  static void registerWith(Registrar registrar) {
    // 将Web端实现设置为默认平台接口实例
    DimFlutterPlatform.instance = DimFlutterWeb();
  }

  /// 获取Web平台版本信息（实现父类抽象方法）
  /// 返回：浏览器的User-Agent字符串（包含浏览器版本、系统信息等）
  @override
  Future<String?> getPlatformVersion() async {
    // 从浏览器的navigator对象获取userAgent
    final version = html.window.navigator.userAgent;
    return version;
  }
}