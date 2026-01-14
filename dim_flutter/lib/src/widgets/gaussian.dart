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

import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../ui/styles.dart';

/// 高斯模糊弹窗页面组件
/// 提供带背景模糊效果的弹窗，支持可关闭/锁定两种模式
class GaussianPage extends StatelessWidget {
  /// 构造函数
  /// [child] - 弹窗内容组件（必填）
  /// [locked] - 是否锁定（true：点击背景不关闭，false：点击背景关闭）
  const GaussianPage({super.key, required this.child, this.locked = false});

  /// 弹窗内容
  final Widget child;
  /// 是否锁定弹窗（禁止点击背景关闭）
  final bool locked;

  /// 显示可关闭的高斯模糊弹窗
  /// [context] - 上下文
  /// [child] - 弹窗内容
  static void show(BuildContext context, Widget child) => showCupertinoDialog(
    context: context,
    builder: (context) => GaussianPage(child: child),
  );

  /// 显示锁定的高斯模糊弹窗（点击背景不关闭）
  /// [context] - 上下文
  /// [child] - 弹窗内容
  static void lock(BuildContext context, Widget child) => showCupertinoDialog(
    context: context,
    builder: (context) => GaussianPage(locked: true, child: child,),
  );

  /// 构建高斯模糊弹窗UI
  @override
  Widget build(BuildContext context) {
    // 居中显示的内容主体
    Widget view = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _body(), // 包装后的内容组件
          ],
        ),
      ],
    );
    
    // 非锁定模式：添加点击背景关闭的手势监听
    if (!locked) {
      view = Stack(
        children: [
          // 点击空白区域关闭弹窗
          GestureDetector(onTap: () => Navigator.pop(context)),
          view, // 内容主体在上层
        ],
      );
    }
    
    // 添加背景高斯模糊滤镜
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaY: 8.0, sigmaX: 8.0), // 模糊程度：X/Y轴各8
      child: view,
    );
  }

  /// 包装内容组件：添加圆角、内边距和背景色
  Widget _body() => ClipRect(
    child: Container(
      padding: const EdgeInsets.all(12), // 内边距12
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8), // 8dp圆角
        // color: CupertinoColors.systemFill, // 系统填充色（注释备用）
        color: Styles.colors.pageMessageBackgroundColor, // 消息弹窗背景色
      ),
      child: child, // 传入的内容组件
    ),
  );

}

/// 毛玻璃效果弹窗内容组件
/// 提供标题、内容、尾部的分段布局，配合GaussianPage使用
class FrostedGlassPage extends StatelessWidget {
  /// 构造函数
  /// [head] - 头部组件（标题）
  /// [body] - 主体组件（内容）
  /// [tail] - 尾部组件（操作按钮）
  /// [width] - 弹窗宽度（默认256）
  const FrostedGlassPage({super.key, this.head, this.body, this.tail, this.width});

  /// 头部组件（标题）
  final Widget? head;
  /// 主体组件（内容）
  final Widget? body;
  /// 尾部组件（操作按钮）
  final Widget? tail;
  /// 弹窗宽度
  final double? width;

  /// 显示可关闭的毛玻璃弹窗
  /// [context] - 上下文
  /// [title] - 标题文字（优先使用head组件）
  /// [message] - 内容文字（优先使用body组件）
  /// [head] - 头部组件
  /// [body] - 主体组件
  /// [tail] - 尾部组件
  /// [width] - 弹窗宽度
  static void show(BuildContext context,
      {String? title, String? message, Widget? head, Widget? body, Widget? tail, double? width}) {
    // 无head组件但有title时，创建默认标题组件
    if (head == null && title != null) {
      head = buildHead(title);
    }
    // 无body组件但有message时，创建默认内容组件
    if (body == null && message != null) {
      body = buildBody(message);
    }
    // 显示高斯模糊弹窗
    return GaussianPage.show(context, FrostedGlassPage(head: head, body: body, tail: tail, width: width,));
  }

  /// 显示锁定的毛玻璃弹窗（点击背景不关闭）
  /// 参数同show方法
  static void lock(BuildContext context,
      {String? title, String? message, Widget? head, Widget? body, Widget? tail, double? width}) {
    if (head == null && title != null) {
      head = buildHead(title);
    }
    if (body == null && message != null) {
      body = buildBody(message);
    }
    return GaussianPage.lock(context, FrostedGlassPage(head: head, body: body, tail: tail, width: width,));
  }

  /// 构建默认标题组件
  /// [title] - 标题文字
  static Widget buildHead(String title) => Text(title,
    style: const TextStyle(
      fontSize: 18,          // 字体大小18
      color: CupertinoColors.systemBlue, // 系统蓝色
      decoration: TextDecoration.none,   // 无文字装饰
    ),
  );
  
  /// 构建默认内容组件
  /// [message] - 内容文字
  static Widget buildBody(String message) => Text(message,
    style: const TextStyle(
      fontSize: 12,             // 字体大小12
      fontWeight: FontWeight.normal, // 常规字重
      color: CupertinoColors.systemGrey, // 系统灰色
      decoration: TextDecoration.none,    // 无文字装饰
    ),
  );

  /// 构建分段布局
  @override
  Widget build(BuildContext context) => Column(
    children: [
      // 头部组件（标题）
      if (head != null)
      Container(
        width: width ?? 256,    // 默认宽度256
        padding: const EdgeInsets.all(8), // 内边距8
        alignment: Alignment.center,      // 居中对齐
        child: head,
      ),
      // 主体组件（内容）
      if (body != null)
      Container(
        width: width ?? 256,    // 默认宽度256
        padding: const EdgeInsets.all(8), // 内边距8
        alignment: Alignment.topLeft,     // 左上对齐
        child: body,
      ),
      // 尾部组件（操作按钮）
      if (tail != null)
      Container(
        width: width ?? 256,    // 默认宽度256
        // padding: const EdgeInsets.all(2), // 注释的内边距
        alignment: Alignment.center,      // 居中对齐
        child: tail,
      ),
    ],
  );

}