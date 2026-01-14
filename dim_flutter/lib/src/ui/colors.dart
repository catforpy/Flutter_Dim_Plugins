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

import 'brightness.dart';

/// Logo背景色常量
const Color tarsierLogoBackgroundColor = Color(0xFF33C0F3);

/// 主题颜色抽象类
/// 定义应用所有UI元素的颜色接口，分亮色/暗色两种实现
abstract class ThemeColors{

  /// Logo背景色（默认使用tarsierLogoBackgroundColor）
  Color get logoBackgroundColor => tarsierLogoBackgroundColor;

  /// 头像主色（默认使用logoBackgroundColor）
  Color get avatarColor => tarsierLogoBackgroundColor;
  /// 头像默认色（未设置头像时的占位色）
  Color get avatarDefaultColor => CupertinoColors.inactiveGray;

  // Color get tabColor => CupertinoColors.black;
  /// 激活的Tab文字/图标颜色
  Color get activeTabColor => CupertinoColors.systemBlue;

  /// 页面背景色
  Color get scaffoldBackgroundColor;
  /// 导航栏背景色
  Color get appBardBackgroundColor;

  /// 输入框托盘背景色
  Color get inputTrayBackgroundColor;

  /// 分区头部背景色
  Color get sectionHeaderBackgroundColor;
  /// 分区尾部背景色
  Color get sectionFooterBackgroundColor;
  /// 分区条目背景色
  Color get sectionItemBackgroundColor;
  /// 分区条目分割线颜色
  Color get sectionItemDividerColor;

  /// 按钮文字颜色（默认白色）
  Color get buttonTextColor => CupertinoColors.white;
  /// 普通按钮背景色（蓝色）
  Color get normalButtonColor => CupertinoColors.systemBlue;
  /// 重要按钮背景色（橙色）
  Color get importantButtonColor => CupertinoColors.systemOrange;
  /// 关键/危险按钮背景色（红色）
  Color get criticalButtonColor => CupertinoColors.systemRed;

  /// 主要文字颜色（标题/正文）
  Color get primaryTextColor;
  /// 次要文字颜色（副标题/次要内容）
  Color get secondaryTextColor;
  /// 三级文字颜色（提示/辅助文字）
  Color get tertiaryTextColor;

  //
  //  Mnemonic Codes - 助记词相关颜色
  //
  /// 助记词卡片背景色
  Color get tileBackgroundColor;
  /// 助记词卡片不可见状态颜色
  Color get tileInvisibleColor;
  /// 助记词文字颜色
  Color get tileColor;
  /// 助记词徽章背景色
  Color get tileBadgeColor;
  /// 助记词序号颜色
  Color get tileOrderColor;

  //
  //  Audio Recorder - 录音组件相关颜色
  //
  /// 录音组件文字颜色
  Color get recorderTextColor;
  /// 录音组件背景色
  Color get recorderBackgroundColor;
  /// 录音中背景色
  Color get recordingBackgroundColor;
  /// 取消录音背景色
  Color get cancelRecordingBackgroundColor;

  //
  //  Text Message - 文本消息相关颜色
  //
  /// 文本消息文字颜色
  Color get textMessageColor;
  /// 文本消息背景色
  Color get textMessageBackgroundColor;

  //
  //  Web Page Message - 网页消息相关颜色
  //
  /// 网页消息文字颜色
  Color get pageMessageColor;
  /// 网页消息背景色
  Color get pageMessageBackgroundColor;

  //
  //  Common - 通用颜色
  //
  /// 命令消息背景色
  Color get commandBackgroundColor;
  /// 自己发送的消息背景色
  Color get messageIsMineBackgroundColor;

  //
  //  Text Style - 文字样式相关颜色
  //
  /// 标题文字颜色
  Color get titleTextColor;

  /// 分区头部文字颜色（默认灰色）
  Color get sectionHeaderTextColor => CupertinoColors.systemGrey;
  /// 分区尾部文字颜色（默认灰色）
  Color get sectionFooterTextColor => CupertinoColors.systemGrey;
  /// 分区条目标题文字颜色
  Color get sectionItemTitleTextColor;
  /// 分区条目副标题文字颜色（默认灰色）
  Color get sectionItemSubtitleTextColor => CupertinoColors.systemGrey;
  /// 分区条目附加文字颜色（默认灰色）
  Color get sectionItemAdditionalTextColor => CupertinoColors.systemGrey;

  /// 标识符文字颜色（青色）
  Color get identifierTextColor => Colors.teal;
  /// 消息发送者名称文字颜色（默认灰色）
  Color get messageSenderNameTextColor => CupertinoColors.systemGrey;
  /// 消息时间文字颜色（默认灰色）
  Color get messageTimeTextColor => CupertinoColors.systemGrey;
  /// 命令文字颜色（默认灰色）
  Color get commandTextColor => CupertinoColors.systemGrey;
  /// 网页标题文字颜色
  Color get pageTitleTextColor;
  /// 网页描述文字颜色
  Color get pageDescTextColor;

  //
  //  Text Field Style - 输入框样式相关颜色
  //
  /// 输入框文字颜色
  Color get textFieldColor;
  /// 输入框装饰背景色
  Color get textFieldDecorationColor;
  /// 输入框装饰边框颜色
  Color get textFieldDecorationBorderColor;

  //
  //  Colors based on Brightness - 根据亮度模式获取当前主题颜色
  //

  /// 获取当前亮度模式对应的主题颜色实例
  static ThemeColors get current =>
      BrightnessDataSource().isDarkMode ? _dark : _light;

  /// 亮色主题颜色实例
  static final ThemeColors _light = _LightThemeColors();
  /// 暗色主题颜色实例
  static final ThemeColors _dark = _DarkThemeColors();

}

/// 亮色主题颜色实现类
class _LightThemeColors extends ThemeColors {

  @override
  Color get scaffoldBackgroundColor => CupertinoColors.extraLightBackgroundGray;

  @override
  Color get appBardBackgroundColor => CupertinoColors.extraLightBackgroundGray;

  @override
  Color get inputTrayBackgroundColor => CupertinoColors.white;

  @override
  Color get sectionHeaderBackgroundColor => Colors.white70;

  @override
  Color get sectionFooterBackgroundColor => Colors.white70;

  @override
  Color get sectionItemBackgroundColor => CupertinoColors.systemBackground;

  @override
  Color get sectionItemDividerColor => const Color(0xFFEEEEEE);

  @override
  Color get primaryTextColor => CupertinoColors.black;

  @override
  Color get secondaryTextColor => CupertinoColors.darkBackgroundGray;

  @override
  Color get tertiaryTextColor => CupertinoColors.systemGrey;

  //
  //  Mnemonic Codes
  //
  @override
  Color get tileBackgroundColor => CupertinoColors.lightBackgroundGray;

  @override
  Color get tileInvisibleColor => CupertinoColors.systemGrey;

  @override
  Color get tileColor => CupertinoColors.black;

  @override
  Color get tileBadgeColor => CupertinoColors.white;

  @override
  Color get tileOrderColor => CupertinoColors.systemGrey;

  //
  //  Audio Recorder
  //
  @override
  Color get recorderTextColor => CupertinoColors.black;

  @override
  Color get recorderBackgroundColor => CupertinoColors.extraLightBackgroundGray;

  @override
  Color get recordingBackgroundColor => Colors.green.shade100;

  @override
  Color get cancelRecordingBackgroundColor => Colors.yellow.shade100;

  //
  //  Text Message
  //
  @override
  Color get textMessageBackgroundColor => CupertinoColors.white;

  @override
  Color get textMessageColor => CupertinoColors.black;

  //
  //  Common
  //
  @override
  Color get commandBackgroundColor => CupertinoColors.lightBackgroundGray;

  @override
  Color get messageIsMineBackgroundColor => const Color(0xFFA9E879);

  //
  //  Web Page Message
  //
  @override
  Color get pageMessageBackgroundColor => CupertinoColors.white;

  @override
  Color get pageMessageColor => CupertinoColors.black;

  //
  //  Text Style
  //
  @override
  Color get titleTextColor => CupertinoColors.black;

  @override
  Color get sectionItemTitleTextColor => CupertinoColors.black;

  @override
  Color get pageTitleTextColor => CupertinoColors.black;

  @override
  Color get pageDescTextColor => CupertinoColors.systemGrey;

  //
  //  Text Field Style
  //
  @override
  Color get textFieldColor => CupertinoColors.black;

  @override
  Color get textFieldDecorationColor => CupertinoColors.white;

  @override
  Color get textFieldDecorationBorderColor => CupertinoColors.lightBackgroundGray;

}

/// 暗色主题颜色实现类
class _DarkThemeColors extends ThemeColors {

  @override
  Color get scaffoldBackgroundColor => CupertinoColors.darkBackgroundGray;

  @override
  Color get appBardBackgroundColor => CupertinoColors.darkBackgroundGray;

  @override
  Color get inputTrayBackgroundColor => CupertinoColors.systemFill;

  @override
  Color get sectionHeaderBackgroundColor => CupertinoColors.systemFill;

  @override
  Color get sectionFooterBackgroundColor => CupertinoColors.systemFill;

  @override
  Color get sectionItemBackgroundColor => CupertinoColors.darkBackgroundGray;

  @override
  Color get sectionItemDividerColor => const Color(0xFF222222);

  @override
  Color get primaryTextColor => CupertinoColors.white;

  @override
  Color get secondaryTextColor => CupertinoColors.lightBackgroundGray;

  @override
  Color get tertiaryTextColor => CupertinoColors.systemGrey;

  //
  //  Mnemonic Codes
  //
  @override
  Color get tileBackgroundColor => CupertinoColors.systemFill;

  @override
  Color get tileInvisibleColor => CupertinoColors.systemGrey;

  @override
  Color get tileColor => CupertinoColors.white;

  @override
  Color get tileBadgeColor => CupertinoColors.darkBackgroundGray;

  @override
  Color get tileOrderColor => CupertinoColors.systemGrey;

  //
  //  Audio Recorder
  //
  @override
  Color get recorderTextColor => CupertinoColors.white;

  @override
  Color get recorderBackgroundColor => CupertinoColors.systemFill;

  @override
  Color get recordingBackgroundColor => CupertinoColors.systemGrey;

  @override
  Color get cancelRecordingBackgroundColor => CupertinoColors.darkBackgroundGray;

  //
  //  Text Message
  //
  @override
  Color get textMessageBackgroundColor => const Color(0xFF303030);

  @override
  Color get textMessageColor => CupertinoColors.white;

  //
  //  Web Page Message
  //
  @override
  Color get pageMessageBackgroundColor => CupertinoColors.systemFill;

  @override
  Color get pageMessageColor => CupertinoColors.white;

  //
  //  Common
  //
  @override
  Color get commandBackgroundColor => CupertinoColors.systemFill;

  @override
  Color get messageIsMineBackgroundColor => const Color(0xFF58B169);

  //
  //  Text Style
  //
  @override
  Color get titleTextColor => CupertinoColors.white;

  @override
  Color get sectionItemTitleTextColor => CupertinoColors.white;

  @override
  Color get pageTitleTextColor => CupertinoColors.white;

  @override
  Color get pageDescTextColor => CupertinoColors.systemGrey;

  //
  //  Text Field Style
  //
  @override
  Color get textFieldColor => CupertinoColors.white;

  @override
  Color get textFieldDecorationColor => CupertinoColors.darkBackgroundGray;

  @override
  Color get textFieldDecorationBorderColor => CupertinoColors.systemGrey;

}