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

import 'values.dart';

/// SQL条件构建器
/// 用于构建WHERE子句中的条件表达式，支持单个条件和复合条件（AND/OR）
class SQLConditions {
  /// 构造方法（创建单个比较条件）
  /// [left]：左操作数（列名）
  /// [comparison]：比较运算符（如=、<>、>、<等）
  /// [right]：右操作数（值）
  SQLConditions({required String left, required String comparison, required dynamic right})
      : _condition = _CompareCondition(left, comparison, right);

  /// 内部条件对象
  _Condition _condition;

  /// 常量：永远为真的条件（1 <> 0）
  static final SQLConditions kTrue = SQLConditions(left: '1', comparison: '<>', right: 0);
  /// 常量：永远为假的条件（1 = 0）
  static final SQLConditions kFalse = SQLConditions(left: '1', comparison: '=', right: 0);

  /// 关系运算符常量 - 与
  static const String kAnd = ' AND ';
  /// 关系运算符常量 - 或
  static const String kOr  = ' OR ';

  /// 将条件追加到字符串缓冲区（值会自动转义）
  /// [sb]：字符串缓冲区
  void appendEscapeValue(StringBuffer sb) => _condition.appendEscapeValue(sb);

  /// 添加复合条件（AND/OR）
  /// [relation]：关系运算符（kAnd/kOr）
  /// [left]：左操作数（列名）
  /// [comparison]：比较运算符
  /// [right]：右操作数（值）
  void addCondition(String relation,
      {required String left, required String comparison, required dynamic right}) {
    _Condition cond = _CompareCondition(left, comparison, right);
    _condition = _RelatedCondition(_condition, relation, cond);
  }

  /// 重写toString方法，返回条件字符串
  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    appendEscapeValue(sb);
    return sb.toString();
  }
}

//
//  内部条件接口和实现类
//

/// 内部条件接口
abstract interface class _Condition {
  /// 将条件追加到字符串缓冲区（值会自动转义）
  void appendEscapeValue(StringBuffer sb);
}

/// 比较条件实现类（如：id = 'moky'）
class _CompareCondition implements _Condition {
  /// 构造方法
  /// [_left]：左操作数（列名）
  /// [_op]：比较运算符
  /// [_right]：右操作数（值）
  _CompareCondition(this._left, this._op, this._right);

  /// 左操作数（列名）
  final String _left;
  /// 比较运算符
  final String _op;
  /// 右操作数（值）
  final dynamic _right;

  /// 将比较条件追加到字符串缓冲区
  @override
  void appendEscapeValue(StringBuffer sb) {
    sb.write(_left);
    sb.write(_op);
    SQLValues.appendEscapeValue(sb, _right);
  }

  /// 重写toString方法
  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    appendEscapeValue(sb);
    return sb.toString();
  }
}

/// 复合条件实现类（如：(id = 'moky') AND (age > 18)）
class _RelatedCondition implements _Condition {
  /// 构造方法
  /// [_left]：左条件
  /// [_relation]：关系运算符（AND/OR）
  /// [_right]：右条件
  _RelatedCondition(this._left, this._relation, this._right);

  /// 左条件
  final _Condition _left;
  /// 关系运算符
  final String _relation;
  /// 右条件
  final _Condition _right;

  /// 追加条件到缓冲区（复合条件会添加括号）
  /// [sb]：字符串缓冲区
  /// [cond]：条件对象
  static void _appendEscapeValue(StringBuffer sb, _Condition cond) {
    if (cond is _RelatedCondition) {
      sb.write('(');
      cond.appendEscapeValue(sb);
      sb.write(')');
    } else {
      cond.appendEscapeValue(sb);
    }
  }

  /// 将复合条件追加到字符串缓冲区
  @override
  void appendEscapeValue(StringBuffer sb) {
    _appendEscapeValue(sb, _left);
    // 验证关系运算符合法性
    assert(_relation == SQLConditions.kAnd
        || _relation == SQLConditions.kOr, 'relation error: $_relation');
    sb.write(_relation);
    _appendEscapeValue(sb, _right);
  }

  /// 重写toString方法
  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    appendEscapeValue(sb);
    return sb.toString();
  }
}