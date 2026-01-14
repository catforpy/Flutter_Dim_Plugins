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

import 'chat.dart';

/// 共享编辑文本管理类（单例）：用于全局存储和获取编辑中的文本
/// 主要场景：
/// 1. 会话输入框文本（按会话ID存储）
/// 2. 搜索框文本（固定key：Searching）
class SharedEditingText {
  /// 工厂构造函数，保证单例
  factory SharedEditingText() => _instance;
  /// 单例实例
  static final SharedEditingText _instance = SharedEditingText._internal();
  /// 私有构造函数
  SharedEditingText._internal();

  /// 文本存储Map(key = 标识，value = 文本内容)
  final Map<String,String> _values = {};

  /// 根据key获取文本
  /// [key] 标识（如会话ID、Searching）
  /// 返回文本内容（null表示无）
  String? getText({required String key}) => 
    _values[key];

  /// 设置指定key的文本
  /// [value] 文本内容
  /// [key] 标识
  void setText(String value,{required String key}) => 
    _values[key] = value;

  /// 获取指定会话的编辑文本
  /// [info] 会话实例
  /// 返回文本内容（null表示无）
  String? getConversationEditingText(Conversation info) =>
      getText(key: info.identifier.toString());

  /// 设置指定会话的编辑文本
  /// [text] 文本内容
  /// [info] 会话实例
  void setConversationEditingText(String text, Conversation info) =>
      setText(text, key: info.identifier.toString());

  /// 获取搜索框的编辑文本
  /// 返回文本内容（null表示无）
  String? getSearchingText() =>
      getText(key: 'Searching');

  /// 设置搜索框的编辑文本
  /// [text] 文本内容
  void setSearchingText(String text) =>
      setText(text, key: 'Searching');
}