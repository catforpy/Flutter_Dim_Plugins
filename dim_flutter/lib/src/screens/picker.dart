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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// import 'package:get/get.dart';

import '../ui/nav.dart';
import '../ui/styles.dart';
import '../widgets/table.dart';

import 'device.dart';


/// 投屏设备选择器：展示可投屏设备列表，支持选择设备播放指定URL
class AirPlayPicker extends StatefulWidget {
  /// 构造方法
  /// [url] 要投屏播放的媒体URL
  /// [key] Widget标识
  const AirPlayPicker({super.key, required this.url});

  /// 要投屏播放的媒体URL
  final Uri url;

  /// 打开投屏设备选择器页面
  /// [context] 上下文
  /// [url] 要投屏播放的媒体URL
  static void open(BuildContext context, Uri url) => appTool.showPage(
    context: context,
    builder: (context) => AirPlayPicker(url: url),
  );

  @override
  State<StatefulWidget> createState() => _AirPlayState();

}

/// 投屏设备选择器状态类：处理设备列表刷新和UI渲染
class _AirPlayState extends State<AirPlayPicker> {

  /// 初始化：页面创建时立即刷新设备列表
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// 刷新投屏设备列表
  void _refresh() {
    // 获取设备管理器实例
    var man = ScreenManager();
    // 强制刷新设备列表，刷新完成后更新UI
    man.getDevices(true).then((_) {
      if (mounted) {
        setState(() {
        });
      }
    });
    // 立即更新UI（显示加载状态）
    setState(() {});
  }

  /// 构建UI界面
  @override
  Widget build(BuildContext context) => Scaffold(
    // 页面背景色
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    // 顶部导航栏
    appBar: AppBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
      title: Text(i18nTranslator.translate('Select TV')), // 标题：选择电视（支持多语言）
    ),
    // 页面主体：居中显示可滚动的设备列表
    body: Center(
      child: buildScrollView(
        enableScrollbar: true, // 显示滚动条
        child: Column(
          children: _deviceList(context), // 构建设备列表Widget
        ),
      ),
    ),
  );

  /// 构建设备列表Widget
  /// [context] 上下文
  /// 返回设备列表Widget数组
  List<Widget> _deviceList(BuildContext context) {
    List<Widget> buttons = [];
    // 获取设备管理器和在线设备列表
    var man = ScreenManager();
    var devices = man.devices;
    // 为每个在线设备创建选择按钮
    for (var tv in devices) {
      buttons.add(TextButton(
        // 点击按钮：投屏播放指定URL，完成后关闭页面
        onPressed: () => tv.castURL(widget.url).then((_) {
          if (context.mounted) {
            appTool.closePage(context);
          }
        }),
        // 按钮文本：设备友好名称
        child: Text(tv.friendlyName),
      ));
    }
    // 处理不同状态的UI展示
    if (man.scanning) {
      // 正在扫描：显示加载动画
      buttons.add(const CupertinoActivityIndicator());
    } else if (devices.isEmpty) {
      // 无设备：显示"未找到电视"和"重新搜索"按钮
      buttons.add(Text(i18nTranslator.translate('TV not found')));
      buttons.add(TextButton(
        onPressed: () => _refresh(),
        child: Text(i18nTranslator.translate('Search again')),
      ));
    } else {
      // 有设备：显示"刷新"按钮
      buttons.add(TextButton(
        onPressed: () => _refresh(),
        child: Text(i18nTranslator.translate('Refresh')),
      ));
    }
    return buttons;
  }

}