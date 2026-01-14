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

import 'package:mkm/type.dart';

/// 字符串增强接口
/// 补充说明：
/// 1. 该接口整合了 Dart 原生的 Comparable<String>（可比较）、Pattern（正则匹配）、CharSequence（字符序列）三大核心接口；
/// 2. 目的是定义一个统一的字符串规范，既具备字符串的基础操作能力，又支持比较和正则匹配；
/// 3. 接口内注释掉的方法是 Dart 原生 String 类的核心方法，此处仅作声明占位，由实现类具体实现。
abstract interface class Stringer implements Comparable<String>, Pattern, CharSequence {

  /*
  /// 基于字符串代码单元生成的哈希码
  /// 该哈希码与 == 运算符兼容：具有相同代码单元序列的字符串哈希码相同
  @override
  int get hashCode;

  /// 判断[other]是否是具有相同代码单元序列的字符串
  /// 逐字节比较每个代码单元，不检查 Unicode 等价性（如 é 的不同编码会判定为不相等）
  @override
  bool operator ==(Object other);

  /// 返回该对象的字符串表示形式
  /// 部分类有默认的文本表示（如 int.parse），部分类仅用于调试/日志输出
  @override
  external String toString();
   */

  /*
  /// 字符串长度（UTF-16 代码单元数量）
  int get length;

  /// 判断字符串是否为空（长度为 0）
  bool get isEmpty;

  /// 判断字符串是否非空（长度大于 0）
  bool get isNotEmpty;
   */
}

/// 不可变字符串实现类
/// 核心设计：
/// 1. 封装一个只读的原生 String 成员变量 _str，所有操作都委托给该变量执行；
/// 2. 实现 Stringer 接口，具备字符序列、可比较、正则匹配的全部能力；
/// 3. 不可变特性：一旦创建，内部的 _str 无法修改，所有字符串操作都会返回新对象。
class ConstantString implements Stringer {
  /// 核心存储：封装的原生字符串（只读，保证不可变）
  final String _str;

  /// 构造方法：将任意对象转换为字符串并封装
  /// 参数处理逻辑：
  /// 1. 若入参是 Stringer 类型 → 调用其 toString() 获取字符串；
  /// 2. 若入参是 String 类型 → 直接使用；
  /// 3. 其他类型 → 调用其 toString() 转换为字符串；
  /// 补充：通过这种方式统一所有输入类型，确保内部只存储原生 String。
  ConstantString(Object string)
      : _str = string is Stringer ? string.toString()
      : string is String ? string : string.toString();

  /// 重写 toString()：返回内部封装的原生字符串
  /// 这是所有字符串操作的核心出口，保证对外暴露的是原生字符串内容
  @override
  String toString() => _str;

  /// 重写 == 运算符：自定义相等判断逻辑
  /// 判断规则：
  /// 1. 若[other]是 Stringer 类型 → 先判断是否是同一对象，不是则取其 toString() 结果比较；
  /// 2. 若[other]是 String 类型 → 直接与内部的 _str 比较；
  /// 3. 其他类型 → 判定为不相等。
  @override
  bool operator ==(Object other) {
    if (other is Stringer) {
      if (identical(this, other)) {
        // 同一对象，直接返回 true（性能优化）
        return true;
      }
      // 非同一对象，取 Stringer 的字符串内容比较
      other = other.toString();
    }
    // 最终比较：是否是 String 类型且内容与 _str 一致
    return other is String && other == _str;
  }

  /// 重写 hashCode：直接使用内部 _str 的哈希码
  /// 保证 == 为 true 的对象，hashCode 也相同（符合 Dart 哈希规范）
  @override
  int get hashCode => _str.hashCode;

  /// 实现长度获取：委托给 _str 的 length 属性
  @override
  int get length => _str.length;

  /// 实现判空：委托给 _str 的 isEmpty 属性
  @override
  bool get isEmpty => _str.isEmpty;

  /// 实现非空判断：委托给 _str 的 isNotEmpty 属性
  @override
  bool get isNotEmpty => _str.isNotEmpty;

  /// 实现字符串比较：委托给 _str 的 compareTo 方法
  /// 返回值规则：负数（当前字符串在前）、正数（当前字符串在后）、0（相等）
  @override
  int compareTo(String other) => _str.compareTo(other);

  //
  //  实现 CharSequence 接口的所有方法（字符序列核心操作）
  //  统一逻辑：所有操作都委托给内部的 _str 执行，保证行为与原生 String 一致
  //

  /// 获取指定索引位置的字符（单 UTF-16 代码单元）
  @override
  String operator [](int index) => _str[index];

  /// 获取指定索引位置的 UTF-16 代码单元值（整数）
  @override
  int codeUnitAt(int index) => _str.codeUnitAt(index);

  /// 判断是否以指定字符串结尾
  @override
  bool endsWith(String other) => _str.endsWith(other);

  /// 判断是否以指定模式（字符串/正则）开头
  @override
  bool startsWith(Pattern pattern, [int index = 0]) =>
      _str.startsWith(pattern, index);

  /// 查找模式首次匹配的起始索引
  @override
  int indexOf(Pattern pattern, [int start = 0]) => _str.indexOf(pattern, start);

  /// 查找模式最后一次匹配的起始索引
  @override
  int lastIndexOf(Pattern pattern, [int? start]) =>
      _str.lastIndexOf(pattern, start);

  /// 字符串拼接
  @override
  String operator +(String other) => _str + other;

  /// 截取子串（从 start 到 end，包含 start，不包含 end）
  @override
  String substring(int start, [int? end]) => _str.substring(start, end);

  /// 去除首尾空白字符
  @override
  String trim() => _str.trim();

  /// 去除开头空白字符
  @override
  String trimLeft() => _str.trimLeft();

  /// 去除结尾空白字符
  @override
  String trimRight() => _str.trimRight();

  /// 字符串重复指定次数
  @override
  String operator *(int times) => _str * times;

  /// 左侧填充字符至指定宽度
  @override
  String padLeft(int width, [String padding = ' ']) =>
      _str.padLeft(width, padding);

  /// 右侧填充字符至指定宽度
  @override
  String padRight(int width, [String padding = ' ']) =>
      _str.padRight(width, padding);

  /// 判断是否包含指定模式的子串
  @override
  bool contains(Pattern other, [int startIndex = 0]) =>
      _str.contains(other, startIndex);

  /// 替换第一个匹配的子串
  @override
  String replaceFirst(Pattern from, String to, [int startIndex = 0]) =>
      _str.replaceFirst(from, to, startIndex);

  /// 替换第一个匹配的子串（支持自定义替换逻辑）
  @override
  String replaceFirstMapped(Pattern from, String Function(Match match) replace,
      [int startIndex = 0]) =>
      _str.replaceFirstMapped(from, replace, startIndex);

  /// 替换所有匹配的子串
  @override
  String replaceAll(Pattern from, String replace) =>
      _str.replaceAll(from, replace);

  /// 替换所有匹配的子串（支持自定义替换逻辑）
  @override
  String replaceAllMapped(Pattern from, String Function(Match match) replace) =>
      _str.replaceAllMapped(from, replace);

  /// 替换指定索引范围的子串
  @override
  String replaceRange(int start, int? end, String replacement) =>
      _str.replaceRange(start, end, replacement);

  /// 按指定模式分割字符串，返回子串列表
  @override
  List<String> split(Pattern pattern) => _str.split(pattern);

  /// 分割字符串并转换各部分，再拼接为新字符串
  @override
  String splitMapJoin(Pattern pattern,
      {String Function(Match)? onMatch, String Function(String)? onNonMatch}) =>
      _str.splitMapJoin(pattern, onMatch: onMatch, onNonMatch: onNonMatch);

  /// 获取字符串的 UTF-16 代码单元列表（不可修改）
  @override
  List<int> get codeUnits => _str.codeUnits;

  /// 获取字符串的 Unicode 码点可迭代对象
  @override
  Runes get runes => _str.runes;

  /// 转换为小写字符串
  @override
  String toLowerCase() => _str.toLowerCase();

  /// 转换为大写字符串
  @override
  String toUpperCase() => _str.toUpperCase();

  //
  //  实现 Pattern 接口的所有方法（正则匹配能力）
  //  统一逻辑：将当前字符串作为匹配模式，委托给 _str 执行匹配操作
  //

  /// 在指定字符串中查找所有匹配当前模式的结果（从 start 索引开始）
  @override
  Iterable<Match> allMatches(String string, [int start = 0]) =>
      _str.allMatches(string, start);

  /// 检查指定字符串从 start 索引开始是否以当前模式作为前缀匹配
  @override
  Match? matchAsPrefix(String string, [int start = 0]) =>
      _str.matchAsPrefix(string, start);
}