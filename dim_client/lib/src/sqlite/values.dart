/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2025 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2025 Albert Moky
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

import 'package:object_key/object_key.dart';

/// SQL值处理工具类
/// 用于处理SQL语句中的值，包括值转义、值列表拼接等
class SQLValues {
  /// 从Map创建SQLValues对象
  /// [values]：键值对（列名-值）
  SQLValues.from(Map<String, dynamic> values) {
    for (String key in values.keys) {
      setValue(key, values[key]);
    }
  }

  /// 存储键值对的列表（用于UPDATE语句的SET子句）
  final List<Pair<String, dynamic>> _values = [];

  /// 设置键值对（存在则更新，不存在则添加）
  /// [name]：列名
  /// [value]：值
  void setValue(String name, dynamic value) {
    Pair<String,dynamic> pair;
    int index;
    // 查找已存在的键
    for(index = _values.length -1;index >= 0;--index){
      pair = _values[index];
      if(name == pair.first){
        break;
      }
    }
    // 创建新的键值对
    pair = Pair(name, value);
    if(index < 0){
      // 不存在，添加新键值对
      _values.add(pair);
    }else{
      // 存在，更新键值对
      _values[index] = pair;
    }
  }

  /// 将键值对追加到字符串缓冲区（格式：name1=value1,name2=value2）
  /// [sb]：字符串缓冲区
  void appendValues(StringBuffer sb){
    StringBuffer tmp = StringBuffer();
    for(Pair<String,dynamic> pair in _values){
      tmp.write(pair.first);
      tmp.write('=');
      appendEscapeValue(tmp, pair.second);
      tmp.write(',');
    }
    if(tmp.isNotEmpty){
      String str = tmp.toString();
      // 移除最后一个逗号
      sb.write(str.substring(0, str.length - 1));
    }
  }

  /// 重写toString方法，返回键值对字符串
  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    appendValues(sb);
    return sb.toString();
  }

  //
  //  静态工具方法
  //

  /// 将字符串列表追加到缓冲区（用逗号分隔）
  /// [sb]：字符串缓冲区
  /// [array]：字符串列表
  static void appendStringList(StringBuffer sb, List<String> array){
    StringBuffer tmp = StringBuffer();
    for(dynamic item in array){
      tmp.write(item);
      tmp.write(',');
    }
    if(tmp.isNotEmpty){
      String str = tmp.toString();
      // 移除最后一个逗号
      sb.write(str.substring(0, str.length - 1));
    }
  }

  /// 将值列表转义后追加到缓冲区（用逗号分隔）
  /// [sb]：字符串缓冲区
  /// [array]：值列表
  static void appendEscapeValueList(StringBuffer sb, List array){
    StringBuffer tmp = StringBuffer();
    for(dynamic item in array){
      appendEscapeValue(tmp, item);
      tmp.write(',');
    }
    if (tmp.isNotEmpty) {
      String str = tmp.toString();
      // 移除最后一个逗号
      sb.write(str.substring(0, str.length - 1));
    }
  }

  /// 将单个值转义后追加到缓冲区
  /// 支持null、数字、字符串类型，其他类型转为字符串后转义
  /// [sb]：字符串缓冲区
  /// [value]：要转义的值
  static void appendEscapeValue(StringBuffer sb, dynamic value) {
    // TODO: 支持更多类型？
    if(value == null){
      // null值转为NULL
      sb.write('NULL');
    }else if (value is num) {
      // 数字直接写入
      sb.write(value);
    } else if (value is String) {
      // 字符串需要转义
      _appendEscapeString(sb, value);
    } else {
      // 其他类型转为字符串后转义
      _appendEscapeString(sb, '$value');
    }
  }

  /// 转义字符串（处理单引号）
  /// [sb]：字符串缓冲区
  /// [str]：要转义的字符串
  static void _appendEscapeString(StringBuffer sb, String str) {
    sb.write('\'');
    if (str.contains('\'')) {
      // 包含单引号，需要转义（将'替换为''）
      int ch;
      for (int index = 0; index < str.length; ++index) {
        ch = str.codeUnitAt(index);
        if (ch == _sq) {  // '\''
          // 追加额外的单引号
          sb.write('\'');
        }
        sb.writeCharCode(ch);
      }
    } else {
      // 不包含单引号，直接写入
      sb.write(str);
    }
    sb.write('\'');
  }

  /// 单引号的ASCII码值
  static final int _sq = '\''.codeUnitAt(0);
}