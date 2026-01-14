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

import 'package:dim_client/ok.dart' as lnc;
import 'package:dim_client/sdk.dart';

import '../common/constants.dart';
import '../models/chat.dart';
import '../models/chat_contact.dart';

/// 名称标签组件
/// 实时显示会话/联系人名称，支持数据更新通知
class NameLabel extends StatefulWidget {
  /// 构造函数
  /// [info] - 会话信息（必填）
  /// 以下为Text组件的样式参数，透传到底层Text组件
  const NameLabel(this.info, {super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  /// 会话信息（联系人/群组）
  final Conversation info;

  // Text组件样式参数（透传）
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  /// 创建状态对象
  @override
  State<StatefulWidget> createState() => _NameState();

}

/// 名称标签状态类
/// 实现Observer监听数据更新，实时刷新名称显示
class _NameState extends State<NameLabel> implements lnc.Observer {
  /// 构造函数：注册通知监听
  _NameState() {
    var nc = lnc.NotificationCenter();
    // 监听文档更新通知
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    // 监听备注更新通知
    nc.addObserver(this, NotificationNames.kRemarkUpdated);
  }

  /// 销毁时移除监听
  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kRemarkUpdated);
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    super.dispose();
  }

  /// 接收通知回调
  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;          // 通知名称
    Map? userInfo = notification.userInfo;    // 通知参数

    // 文档更新通知：检查是否是当前会话
    if (name == NotificationNames.kDocumentUpdated) {
      ID? identifier = userInfo?['ID'];
      if (identifier == widget.info.identifier) {
        await _reload(); // 重新加载数据
      }
    }
    // 备注更新通知：检查是否是当前联系人
    else if (name == NotificationNames.kRemarkUpdated) {
      ID? identifier = userInfo?['contact'];
      if (identifier == widget.info.identifier) {
        await _reload(); // 重新加载数据
      }
    }
  }

  /// 重新加载会话数据并刷新UI
  Future<void> _reload() async {
    await widget.info.reloadData(); // 重新加载数据
    // 数据加载完成后刷新UI
    if (mounted) {
      setState(() {
        // 空setState触发UI刷新
      });
    }
  }

  /// 初始化状态：加载初始数据
  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// 构建名称文本组件
  @override
  Widget build(BuildContext context) => Text(
    widget.info.title, // 显示会话标题（实时更新）
    // 透传所有Text样式参数
    style:              widget.style,
    strutStyle:         widget.strutStyle,
    textAlign:          widget.textAlign,
    textDirection:      widget.textDirection,
    locale:             widget.locale,
    softWrap:           widget.softWrap,
    overflow:           widget.overflow,
    textScaler:         widget.textScaler,
    maxLines:           widget.maxLines,
    semanticsLabel:     widget.semanticsLabel,
    textWidthBasis:     widget.textWidthBasis,
    textHeightBehavior: widget.textHeightBehavior,
    selectionColor:     widget.selectionColor,
  );

}