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

import 'package:flutter/material.dart'; // Flutter Material设计库

import 'colors.dart'; // 应用颜色配置

/// 应用样式常量类 - 统一管理文本样式、间距、装饰等UI样式
abstract class Styles {
  /// 获取当前主题的颜色配置
  static ThemeColors get colors => ThemeColors.current;

  /// 按钮文本样式
  static TextStyle get buttonTextStyle => TextStyle(
    color: colors.buttonTextColor, // 按钮文本颜色
    fontWeight: FontWeight.bold, // 粗体
    decoration: TextDecoration.none, // 无文本装饰
  );

  //
  //  文本样式
  //

  /// 标题文本样式
  static TextStyle get titleTextStyle => TextStyle(
    color: colors.titleTextColor, // 标题文本颜色
    decoration: TextDecoration.none, // 无文本装饰
  );

  /// 分区头部文本样式
  static TextStyle get sectionHeaderTextStyle => TextStyle(
    fontSize: 12, // 字体大小
    color: colors.sectionHeaderTextColor, // 分区头部文本颜色
    decoration: TextDecoration.none, // 无文本装饰
  );

  /// 分区底部文本样式
  static TextStyle get sectionFooterTextStyle => TextStyle(
    fontSize: 10, // 字体大小
    color: colors.sectionFooterTextColor, // 分区底部文本颜色
    decoration: TextDecoration.none, // 无文本装饰
  );

  /// 分区项标题文本样式
  static TextStyle get sectionItemTitleTextStyle => TextStyle(
    fontSize: 16, // 字体大小
    color: colors.sectionItemTitleTextColor, // 分区项标题颜色
    overflow: TextOverflow.ellipsis, // 文本溢出时显示省略号
    decoration: TextDecoration.none, // 无文本装饰
  );

  /// 分区项副标题文本样式
  static TextStyle get sectionItemSubtitleTextStyle => TextStyle(
    fontSize: 10, // 字体大小
    color: colors.sectionItemSubtitleTextColor, // 分区项副标题颜色
    overflow: TextOverflow.fade, // 文本溢出时渐隐
    decoration: TextDecoration.none, // 无文本装饰
  );

  /// 分区项附加文本样式
  static TextStyle get sectionItemAdditionalTextStyle => TextStyle(
    fontSize: 12, // 字体大小
    color: colors.sectionItemAdditionalTextColor, // 分区项附加文本颜色
    decoration: TextDecoration.none, // 无文本装饰
  );

  /// 标识符文本样式（如ID、编码等）
  static TextStyle get identifierTextStyle => TextStyle(
    fontSize: 12, // 字体大小
    color: colors.identifierTextColor, // 标识符文本颜色
    decoration: TextDecoration.none, // 无文本装饰
  );

  /// 消息发送者名称文本样式
  static TextStyle get messageSenderNameTextStyle => TextStyle(
    fontSize: 12, // 字体大小
    color: colors.messageSenderNameTextColor, // 消息发送者名称颜色
    overflow: TextOverflow.ellipsis, // 文本溢出时显示省略号
    decoration: TextDecoration.none, // 无文本装饰
  );

  /// 消息时间文本样式
  static TextStyle get messageTimeTextStyle => TextStyle(
    fontSize: 10, // 字体大小
    color: colors.messageTimeTextColor, // 消息时间文本颜色
    decoration: TextDecoration.none, // 无文本装饰
  );

  /// 命令文本样式（如系统提示、操作指令）
  static TextStyle get commandTextStyle => TextStyle(
    fontSize: 10, // 字体大小
    color: colors.commandTextColor, // 命令文本颜色
    decoration: TextDecoration.none, // 无文本装饰
  );

  /// 页面标题文本样式
  static TextStyle get pageTitleTextStyle => TextStyle(
    fontSize: 14, // 字体大小
    color: colors.pageTitleTextColor, // 页面标题颜色
    overflow: TextOverflow.ellipsis, // 文本溢出时显示省略号
    decoration: TextDecoration.none, // 无文本装饰
  );

  /// 页面描述文本样式
  static TextStyle get pageDescTextStyle => TextStyle(
    fontSize: 10, // 字体大小
    color: colors.pageDescTextColor, // 页面描述颜色
    overflow: TextOverflow.ellipsis, // 文本溢出时显示省略号
    decoration: TextDecoration.none, // 无文本装饰
  );

  /// 翻译文本样式
  static TextStyle get translatorTextStyle => TextStyle(
    fontSize: 10, // 字体大小
    color: colors.commandTextColor, // 翻译文本颜色（复用命令文本颜色）
    decoration: TextDecoration.none, // 无文本装饰
  );

  //
  //  文本框样式
  //
  /// 文本框输入文本样式
  static TextStyle get textFieldStyle => TextStyle(
    height: 1.6, // 行高
    color: colors.textFieldColor, // 文本框文本颜色
    decoration: TextDecoration.none, // 无文本装饰
  );

  /// 文本框装饰样式
  static BoxDecoration get textFieldDecoration => BoxDecoration(
    color: colors.textFieldDecorationColor, // 文本框背景色
    border: Border.all(
      color: colors.textFieldDecorationBorderColor, // 文本框边框颜色
      style: BorderStyle.solid, // 实线边框
      width: 1, // 边框宽度
    ),
    borderRadius: BorderRadius.circular(8), // 圆角半径
  );

  //
  //  导航栏样式
  //
  /// 导航栏图标大小
  static const double navigationBarIconSize = 16;

  //
  //  分区间距
  //
  /// 分区头部内边距
  static const EdgeInsets sectionHeaderPadding = EdgeInsets.fromLTRB(16, 4, 16, 4);
  /// 分区底部内边距
  static const EdgeInsets sectionFooterPadding = EdgeInsets.fromLTRB(16, 4, 16, 4);

  /// 分区项内边距
  static const EdgeInsets sectionItemPadding = EdgeInsets.fromLTRB(0, 8, 0, 8);

  /// 设置页面分区项内边距
  static const EdgeInsets settingsSectionItemPadding = EdgeInsets.all(16);

  //
  //  聊天框样式
  //
  /// 消息项外边距
  static const EdgeInsets messageItemMargin = EdgeInsets.fromLTRB(8, 4, 8, 4);

  /// 消息发送者头像内边距
  static const EdgeInsets messageSenderAvatarPadding = EdgeInsets.fromLTRB(8, 4, 8, 4);

  /// 消息发送者名称外边距
  static const EdgeInsets messageSenderNameMargin = EdgeInsets.all(2);

  /// 消息内容外边距
  static const EdgeInsets messageContentMargin = EdgeInsets.fromLTRB(2, 2, 2, 2);

  /// 文本消息内边距
  static const EdgeInsets textMessagePadding = EdgeInsets.fromLTRB(16, 12, 16, 12);
  /// 语音消息内边距
  static const EdgeInsets audioMessagePadding = EdgeInsets.fromLTRB(16, 12, 16, 12);

  /// 页面消息内边距
  static const EdgeInsets pageMessagePadding = EdgeInsets.fromLTRB(12, 8, 8, 8);

  /// 命令文本内边距
  static const EdgeInsets commandPadding = EdgeInsets.fromLTRB(8, 4, 8, 4);

  /// 翻译按钮样式
  static ButtonStyle translateButtonStyle = TextButton.styleFrom(
    foregroundColor: Colors.blue, // 按钮前景色
    textStyle: const TextStyle(
      color: Colors.blue, // 按钮文本颜色
      fontSize: 10, // 字体大小
      decoration: TextDecoration.none, // 无文本装饰
    ),
    minimumSize: Size.zero, // 最小尺寸为0（移除默认最小尺寸）
    padding: EdgeInsets.zero, // 内边距为0
    tapTargetSize: MaterialTapTargetSize.shrinkWrap, // 点击区域自适应
  );

  //
  //  直播样式
  //
  /// 直播群组文本样式
  static const TextStyle liveGroupStyle = TextStyle(
    color: Colors.yellow, // 黄色文本
    fontSize: 24, // 字体大小
    decoration: TextDecoration.none, // 无文本装饰
  );

  /// 直播频道文本样式
  static const TextStyle liveChannelStyle = TextStyle(
    color: Colors.white, // 白色文本
    fontSize: 16, // 字体大小
    decoration: TextDecoration.none, // 无文本装饰
  );

  /// 直播播放状态文本样式
  static const TextStyle livePlayingStyle = TextStyle(
    color: Colors.blue, // 蓝色文本
    fontSize: 16, // 字体大小
    decoration: TextDecoration.none, // 无文本装饰
  );
}