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

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

/// 消息模板工具类：负责模板消息的变量替换和文本生成
abstract class MessageTemplate {

  /// 从消息内容中获取模板化文本
  /// [content] 消息内容Map
  /// 返回格式化后的文本
  static String getText(Map content){
    try{
      // 提取模版和替换数量
      var template = content['template'];
      var replacements = content['replacements'];
      if(template is String && replacements is Map){
        return _getTempText(template, replacements);
      }
      // 无模板则直接获取text字段
      return Converter.getString(content['text']) ?? '';
    }catch(e,st){
      Log.error('message error: $e, $content, $st');
      return e.toString();
    }
  }

  /// 替换模板中的变量
  /// [template] 模板字符串
  /// [replacements] 替换变量Map
  /// 返回替换后的文本
  static String _getTempText(String template, Map replacements) {
    Log.info('template: $template');
    replacements.forEach((key, value) {
      // 逐个替换变量
      template = replaceTemplate(template, key: key, value: value);
    });
    return template;
  }

  /// 替换模板中的单个变量
  /// [template] 模板字符串
  /// [key] 变量名
  /// [value] 变量值
  /// 返回替换后的模板
  static String replaceTemplate(String template, {dynamic key, dynamic value}) {
    // 获取替换的键值对
    List<String>? pair = _getTempValues(template, key: key, value: value);
    if (pair == null) {
      return template;
    }
    // 替换模板中的变量
    return template.replaceAll(pair[0], pair[1]);
  }

  /// 获取模板变量的替换键值对
  /// [template] 模板字符串
  /// [key] 变量名
  /// [value] 变量值
  /// 返回 [变量标签, 替换值] 或null
  static List<String>? _getTempValues(String template, {dynamic key, dynamic value}) {
    String tag;
    String? sub;
    // 检查普通文本变量 ${key}
    tag = '\${$key}';
    if (template.contains(tag)) {
      if (value is String) {
        sub = value;
      } else {
        sub = '$value';
      }
      return [tag, sub];
    }
    // 检查Base64编码变量 ${base64_encode(key)}
    tag = '\${base64_encode($key)}';
    if (template.contains(tag)) {
      if (value is String) {
        // 对字符串进行UTF8编码后Base64编码
        sub = Base64.encode(UTF8.encode(value));
        return [tag, sub];
      } else {
        assert(false, 'base64 value error: $key -> $value');
      }
    }
    // TODO: 其他格式？
    assert(false, 'template key not found: $key');
    return null;
  }
}