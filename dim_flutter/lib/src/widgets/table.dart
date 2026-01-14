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
import 'package:flutter_section_list/flutter_section_list.dart';

import '../common/platform.dart';
import '../ui/styles.dart';

/// 仿iOS风格的表格单元格组件
/// 支持左侧头像、主标题、副标题、附加信息、右侧图标，以及点击/长按事件
class CupertinoTableCell extends StatelessWidget {
  /// 构造函数
  /// [leadingSize] - 左侧组件尺寸（默认60）
  /// [leading] - 左侧组件（头像/图标）
  /// [title] - 主标题组件（必填）
  /// [subtitle] - 副标题组件
  /// [additionalInfo] - 附加信息组件
  /// [trailing] - 右侧组件（箭头/勾选图标）
  /// [onTap] - 点击回调
  /// [onLongPress] - 长按回调
  const CupertinoTableCell({super.key, this.leadingSize = 60, this.leading,
    required this.title, this.subtitle,
    this.additionalInfo, this.trailing,
    this.onTap, this.onLongPress});

  /// 左侧组件尺寸
  final double leadingSize;
  /// 左侧组件（头像/图标）
  final Widget? leading;
  /// 主标题组件（必填）
  final Widget title;
  /// 副标题组件
  final Widget? subtitle;
  /// 附加信息组件
  final Widget? additionalInfo;
  /// 右侧组件（箭头/勾选图标）
  final Widget? trailing;

  /// 点击回调
  final GestureTapCallback? onTap;
  /// 长按回调
  final GestureLongPressCallback? onLongPress;

  /// 构建单元格UI
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,          // 绑定点击事件
    onLongPress: onLongPress, // 绑定长按事件
    child: Column(
      children: [
        // 单元格内容区域
        Container(
          padding: Styles.sectionItemPadding, // 单元格内边距
          color: Styles.colors.sectionItemBackgroundColor, // 单元格背景色
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // 垂直居中
            children: [
              _head(),          // 左侧组件
              Expanded(
                child: _body(context), // 主体内容（标题/副标题）
              ),
              _additional(context), // 附加信息
              _tail(),          // 右侧组件
            ],
          ),
        ),
        _divider(context),    // 分隔线
      ],
    ),
  );

  /// 构建左侧组件区域
  Widget _head() => Container(
    width: leading == null ? 16 : leadingSize, // 无左侧组件时宽度16
    alignment: Alignment.center,               // 居中对齐
    child: leading,                            // 左侧组件
  );

  /// 构建主体内容区域（标题/副标题）
  Widget _body(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center, // 垂直居中
    crossAxisAlignment: CrossAxisAlignment.start, // 水平左对齐
    children: [
      // 主标题
      DefaultTextStyle(
        maxLines: 1,                             // 单行显示
        softWrap: false,                         // 禁用自动换行
        style: Styles.sectionItemTitleTextStyle, // 主标题样式
        child: title,                            // 主标题组件
      ),
      // 副标题（可选）
      if (subtitle != null)
        Container(
          padding: const EdgeInsets.only(top: 8), // 与主标题间距8
          child: DefaultTextStyle(
            maxLines: 1,                               // 单行显示
            softWrap: false,                           // 禁用自动换行
            style: Styles.sectionItemSubtitleTextStyle, // 副标题样式
            child: subtitle!,                          // 副标题组件
          ),
        ),
    ],
  );

  /// 构建附加信息区域
  Widget _additional(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 8, 2, 8), // 内边距：左8 上下8 右2
    child: DefaultTextStyle(
      style: Styles.sectionItemAdditionalTextStyle, // 附加信息样式
      child: additionalInfo ?? Container(),          // 附加信息组件（空容器兜底）
    ),
  );

  /// 构建右侧组件区域
  Widget _tail() => Container(
    padding: const EdgeInsets.fromLTRB(2, 8, 8, 8), // 内边距：左2 上下8 右8
    child: trailing ?? Container(),                 // 右侧组件（空容器兜底）
  );

  /// 构建单元格分隔线
  Widget _divider(BuildContext context) => Container(
    color: Styles.colors.sectionItemBackgroundColor, // 分隔线背景色（与单元格一致）
    child: Container(
      // 无左侧组件时不分隔，有左侧组件时从左侧组件后开始分隔
      margin: leading == null ? null : EdgeInsetsDirectional.only(start: leadingSize),
      color: Styles.colors.sectionItemDividerColor, // 分隔线颜色
      height: 1,                                     // 分隔线高度1px
    ),
  );

}

/// 构建带分类的列表视图（SectionListView）
/// [enableScrollbar] - 是否显示滚动条（移动端默认显示）
/// [reverse] - 是否反向滚动
/// [adapter] - 列表适配器（必填）
/// 返回：带滚动条/普通的SectionListView
Widget buildSectionListView({
  bool enableScrollbar = false,
  // Axis scrollDirection = Axis.vertical, // 注释的参数：滚动方向
  bool reverse = false,
  // ScrollController? controller, // 注释的参数：滚动控制器
  // bool? primary, // 注释的参数：是否为主滚动视图
  // ScrollPhysics? physics, // 注释的参数：滚动物理特性
  // bool shrinkWrap = false, // 注释的参数：是否包裹内容
  // EdgeInsetsGeometry? padding, // 注释的参数：内边距
  required SectionAdapter adapter,
  // bool addAutomaticKeepAlives = true, // 注释的参数：是否保持状态
  // bool addRepaintBoundaries = true, // 注释的参数：是否添加重绘边界
  // bool addSemanticIndexes = true, // 注释的参数：是否添加语义索引
  // double? cacheExtent, // 注释的参数：缓存区域大小
  // DragStartBehavior dragStartBehavior = DragStartBehavior.start, // 注释的参数：拖动起始行为
  // ScrollViewKeyboardDismissBehavior keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual, // 注释的参数：键盘关闭行为
  // String? restorationId, // 注释的参数：恢复ID
  // Clip clipBehavior = Clip.hardEdge, // 注释的参数：裁剪行为
}) {
  // 创建分类列表视图
  var view = SectionListView.builder(
    reverse: reverse,
    adapter: adapter,
  );
  // 移动端启用滚动条，其他平台禁用
  if (DevicePlatform.isMobile) {
    // needs to enable scroll bar（注释：需要启用滚动条）
  } else {
    enableScrollbar = false;
  }
  // 返回带滚动条/普通的列表视图
  return enableScrollbar ? Scrollbar(child: view) : view;
}

/// 构建可滚动视图（SingleChildScrollView）
/// [enableScrollbar] - 是否显示滚动条（移动端默认显示）
/// [scrollDirection] - 滚动方向（默认垂直）
/// [child] - 子组件（必填）
/// 返回：带滚动条/普通的SingleChildScrollView
Widget buildScrollView({
  bool enableScrollbar = false,
  Axis scrollDirection = Axis.vertical,
  // bool reverse = false, // 注释的参数：是否反向滚动
  // EdgeInsetsGeometry? padding, // 注释的参数：内边距
  // bool? primary, // 注释的参数：是否为主滚动视图
  // ScrollPhysics? physics, // 注释的参数：滚动物理特性
  // ScrollController? controller, // 注释的参数：滚动控制器
  required Widget child,
  // DragStartBehavior dragStartBehavior = DragStartBehavior.start, // 注释的参数：拖动起始行为
  // Clip clipBehavior = Clip.hardEdge, // 注释的参数：裁剪行为
  // String? restorationId, // 注释的参数：恢复ID
  // ScrollViewKeyboardDismissBehavior keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual, // 注释的参数：键盘关闭行为
}) {
  // 创建可滚动视图
  var view = SingleChildScrollView(
    scrollDirection: scrollDirection,
    child: child,
  );
  // 移动端启用滚动条，其他平台禁用
  if (DevicePlatform.isMobile) {
    // needs to enable scroll bar（注释：需要启用滚动条）
  } else {
    enableScrollbar = false;
  }
  // 返回带滚动条/普通的可滚动视图
  return enableScrollbar ? Scrollbar(child: view) : view;
}