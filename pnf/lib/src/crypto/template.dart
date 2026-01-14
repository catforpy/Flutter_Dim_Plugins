/* license: https://mit-license.org
 *
 *  ObjectKey : Object & Key kits
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


/// URL模板处理工具类
/// 核心作用：
/// 1. 替换URL中的占位符（如{key}）；
/// 2. 解析/修改URL的查询参数（如?key=value）；
/// 3. 支持处理URL的锚点（#fragment）
abstract class Template {

  /// 替换模板中的占位符
  /// [template] - 含{key}占位符的字符串（如URL模板）
  /// [key] - 占位符名称（不含{}）
  /// [value] - 替换的值
  /// 返回值：替换后的字符串
  static String replace(String template, String key, String value) =>
      template.replaceAll(RegExp('\\{$key\\}'), value);

  //
  //  URL 专用方法
  //

  /// 提取URL中的查询字符串（?后、#前的部分）
  /// [url] - 完整URL
  /// 返回值：查询字符串（无则返回空字符串）
  static String getQueryString(String url) {
    String text = url;
    int pos;
    // 截取?后的部分（去掉协议/域名/路径）
    pos = text.indexOf('?');
    if (pos > 0) {
      text = text.substring(pos + 1);
    }
    // 截取#前的部分（去掉锚点）
    pos = text.indexOf('#');
    if (pos > 0) {
      text = text.substring(0, pos);
    }
    return text;
  }

  /// 从URL中提取指定查询参数的值
  /// [url] - 完整URL
  /// [key] - 参数名
  /// 返回值：参数值（解码后），无则返回null
  static String? getQueryParam(String url, String key) {
    // 提取查询字符串
    String text = getQueryString(url);
    // 分割参数对（&分隔）
    List<String> pairs = text.split('&');
    int pos;
    for (String item in pairs) {
      pos = item.indexOf('=');
      // 检查参数名是否匹配
      if (pos > 0 && item.substring(0, pos) == key) {
        // 解码参数值（处理URL编码）
        return Uri.decodeComponent(item.substring(pos + 1));
      }
    }
    return null;
  }

  /// 提取URL中的所有查询参数（键值对）
  /// [url] - 完整URL
  /// 返回值：参数名→参数值的映射（值已解码）
  static Map<String, String> getQueryParams(String url) {
    Map<String, String> params = {};
    // 提取查询字符串
    String text = getQueryString(url);
    // 分割参数对
    List<String> pairs = text.split('&');
    int pos;
    String key, value;
    for (String item in pairs) {
      pos = item.indexOf('=');
      if (pos > 0) {
        key = item.substring(0, pos);
        value = item.substring(pos + 1);
        // 解码值并存入映射
        params[key] = Uri.decodeComponent(value);
      }
    }
    return params;
  }

  /// 替换/新增URL中的查询参数
  /// [url] - 完整URL
  /// [key] - 要替换/新增的参数名
  /// [value] - 参数值（无需提前URL编码）
  /// 返回值：处理后的URL
  static String replaceQueryParam(String url, String key, String value) {
    // 先尝试查找?key= 或 &key=
    int pos = url.indexOf('?$key=');
    if (pos < 0) {
      pos = url.indexOf('&$key=');
    }
    if (pos > 0) {
      // 找到参数，更新其值
      return _updateValue(url, pos + 2 + key.length, value);
    }
    // 未找到参数，新增到URL末尾
    String param = url.contains('?') ? '&$key=$value' : '?$key=$value';
    pos = url.indexOf('#');
    if (pos < 0) {
      // 无锚点，直接拼接
      return '$url$param';
    }
    // 有锚点，插入到锚点前
    String prefix = url.substring(0, pos);
    String suffix = url.substring(pos);
    return '$prefix$param$suffix';
  }

  /// 内部方法：更新URL中指定位置的参数值
  /// [url] - 完整URL
  /// [start] - 参数值的起始位置
  /// [value] - 新的参数值
  /// 返回值：更新后的URL
  static String _updateValue(String url, int start, String value) {
    String prefix, suffix;
    int end;
    // 确定前缀
    if (start < url.length) {
      prefix = url.substring(0, start);
      // 查找参数值的结束位置（&或#）
      end = url.indexOf('&', start);
      if (end < 0) {
        end = url.indexOf('#', start);
      }
    } else {
      prefix = url;
      end = -1;
    }
    // 拼接新值
    if (end < 0) {
      return '$prefix$value';
    }
    suffix = url.substring(end);
    return '$prefix$value$suffix';
  }
}