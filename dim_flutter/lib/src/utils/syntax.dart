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

import 'dart:ui'; // Flutter底层UI库（Brightness等）

import 'package:flutter/painting.dart'; // Flutter绘制库（TextSpan等）
import 'package:flutter_markdown/flutter_markdown.dart'; // Markdown渲染
import 'package:syntax_highlight/syntax_highlight.dart'; // 语法高亮库

import 'package:dim_client/ok.dart'; // DIM客户端基础库

import '../ui/brightness.dart'; // 亮度/主题管理


/// 语法高亮管理器 - 单例模式，管理语法高亮器的初始化和获取
class SyntaxManager {
  // 单例实现
  factory SyntaxManager() => _instance;
  static final SyntaxManager _instance = SyntaxManager._internal();
  SyntaxManager._internal();

  bool _loaded = false; // 语法规则是否已加载
  _DefaultSyntaxHighlighter? _dark; // 深色主题语法高亮器
  _DefaultSyntaxHighlighter? _light; // 浅色主题语法高亮器

  /// 获取指定亮度的语法高亮主题
  /// [brightness] 亮度模式（dark/light）
  /// 返回：HighlighterTheme对象
  Future<HighlighterTheme> getTheme(Brightness brightness) async {
    // 1. 加载语法规则（仅首次调用时加载）
    if (!_loaded) {
      _loaded = true;
      // 初始化语法高亮器，加载指定语言的语法规则
      await Highlighter.initialize([
        'dart', // Dart语言
        // 'json', // JSON格式
        // 'sql',  // SQL语句
        // 'yaml', // YAML格式
      ]);
    }
    // 2. 根据亮度加载对应的主题
    return await HighlighterTheme.loadForBrightness(brightness);
  }

  /// 获取当前主题的语法高亮器
  /// 根据当前亮度模式返回对应的高亮器实例（单例）
  SyntaxHighlighter getHighlighter() {
    // 获取当前亮度模式
    Brightness brightness = BrightnessDataSource().current;
    // 根据亮度选择对应的高亮器
    var pipe = brightness == Brightness.dark ? _dark : _light;
    if (pipe != null) {
      // 返回已创建的高亮器实例
      return pipe;
    } else if (brightness == Brightness.dark) {
      // 创建深色主题高亮器
      return _dark = _DefaultSyntaxHighlighter(brightness);
    } else {
      // 创建浅色主题高亮器
      return _light = _DefaultSyntaxHighlighter(brightness);
    }
  }

}

/// 默认语法高亮器 - 实现SyntaxHighlighter接口，封装语法高亮逻辑
class _DefaultSyntaxHighlighter with Logging implements SyntaxHighlighter {
  /// 构造函数 - 初始化语法高亮器
  _DefaultSyntaxHighlighter(Brightness brightness) {
    _initialize(brightness);
  }

  Highlighter? _inner; // 内部语法高亮器实例

  /// 初始化语法高亮器
  /// [brightness] 亮度模式（dark/light）
  void _initialize(Brightness brightness) async {
    // 获取对应亮度的主题
    HighlighterTheme theme = await SyntaxManager().getTheme(brightness);
    // 创建语法高亮器实例（默认Dart语言）
    _inner = Highlighter(language: 'dart', theme: theme);
  }

  /// 格式化代码，生成带语法高亮的TextSpan
  /// [source] 源代码字符串
  /// 返回：带高亮样式的TextSpan（失败返回普通TextSpan）
  @override
  TextSpan format(String source) {
    TextSpan? res;
    try {
      // 使用语法高亮器格式化代码
      res = _inner?.highlight(source);
      // 记录日志：高亮器状态和源代码长度
      logInfo('syntax highlighter: $_inner, source size: ${source.length}');
    } catch (e, st) {
      // 格式化失败，记录错误日志
      logError('syntax error: $source\n error: $e, $st');
    }
    // 高亮失败时返回普通TextSpan
    return res ?? TextSpan(text: source);
  }

}


/// 视觉文本工具类 - 提供文本宽度计算和截断功能
abstract class VisualTextUtils {

  /// 计算文本的视觉宽度
  /// 规则：ASCII字符宽度1，CJK等宽字符宽度2
  static int getTextWidth(String text) {
    int width = 0;
    int index;
    int code;
    for (index = 0; index < text.length; ++index) {
      // 获取字符的Unicode编码
      code = text.codeUnitAt(index);
      if (0x0000 <= code && code <= 0x007F) {
        // Basic Latin (ASCII) - 宽度1
        width += 1;
      } else if (0x0080 <= code && code <= 0x07FF) {
        // Latin-1 Supplement - 宽度1（西欧语言字符）
        width += 1;
      } else {
        // 其他字符（如CJK）- 宽度2
        width += 2;
      }
    }
    return width;
  }

  /// 根据最大视觉宽度截断文本
  /// [text] 原文本 [maxWidth] 最大视觉宽度
  /// 返回：截断后的文本（不超过最大宽度）
  static String getSubText(String text, int maxWidth) {
    int width = 0;
    int index;
    int code;
    for (index = 0; index < text.length; ++index) {
      // 获取字符的Unicode编码
      code = text.codeUnitAt(index);
      // 累加字符宽度
      if (0x0000 <= code && code <= 0x007F) {
        width += 1;
      } else if (0x0080 <= code && code <= 0x07FF) {
        width += 1;
      } else {
        width += 2;
      }
      // 超过最大宽度时停止
      if (width > maxWidth) {
        break;
      }
    }
    if (index == 0) {
      // 第一个字符就超过宽度，返回空字符串
      return '';
    }
    // 返回截断后的文本
    return text.substring(0, index);
  }

}