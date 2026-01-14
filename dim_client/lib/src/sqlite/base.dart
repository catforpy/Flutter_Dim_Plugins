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

import 'package:dimsdk/dimsdk.dart';

/// 结果集接口（模仿JDBC的ResultSet）
/// 用于遍历数据库查询结果，提供多种数据类型的获取方法
abstract class ResultSet {
  /// 将游标从当前位置向前移动一行
  /// ResultSet游标初始位置在第一行之前；第一次调用next()使第一行成为当前行；
  /// 第二次调用使第二行成为当前行，依此类推。
  /// 当next()返回false时，游标位于最后一行之后。
  /// 如果输入流为当前行打开，调用next()将隐式关闭它。
  /// ResultSet的警告链在读取新行时被清除。
  /// 
  /// @return true - 新的当前行有效；false - 没有更多行
  /// @exception SQLException - 数据库访问错误或在关闭的结果集上调用此方法
  bool next();

  /// 获取当前行号（第一行是1，第二行是2，依此类推）
  /// 注意：对于TYPE_FORWARD_ONLY类型的ResultSet，getRow方法是可选支持的
  /// 
  /// @return 当前行号；如果没有当前行则返回0
  /// @exception SQLException - 数据库访问错误或在关闭的结果集上调用此方法
  /// @exception SQLFeatureNotSupportedException - JDBC驱动不支持此方法
  /// @since 1.2
  int get row;

  /// 根据列名获取列值（原始类型）
  /// [column]：列名
  /// 返回：列的原始值
  dynamic getValue(String column);

  /// 根据列名获取字符串类型的值
  /// [column]：列名
  /// 返回：字符串值（null表示转换失败或值为null）
  String? getString(String column) => Converter.getString(getValue(column));

  /// 根据列名获取布尔类型的值
  /// [column]：列名
  /// 返回：布尔值（null表示转换失败或值为null）
  bool? getBool(String column) => Converter.getBool(getValue(column));

  /// 根据列名获取整数类型的值
  /// [column]：列名
  /// 返回：整数值（null表示转换失败或值为null）
  int? getInt(String column) => Converter.getInt(getValue(column));

  /// 根据列名获取浮点类型的值
  /// [column]：列名
  /// 返回：浮点值（null表示转换失败或值为null）
  double? getDouble(String column) => Converter.getDouble(getValue(column));

  /// 根据列名获取日期时间类型的值
  /// [column]：列名
  /// 返回：日期时间值（null表示转换失败或值为null）
  DateTime? getDateTime(String column) => Converter.getDateTime(getValue(column));

  /// 关闭结果集，释放相关资源
  void close();
}

/// 数据库语句接口（模仿JDBC的Statement）
/// 用于执行SQL语句，支持增删改查操作
abstract interface class Statement{
  /// 执行INSERT语句
  /// 示例：'INSERT INTO t_user(id, name) VALUES("moky@anywhere", "Moky")'
  /// [sql]：INSERT SQL语句
  /// 返回：受影响的行数
  Future<int> executeInsert(String sql);

  /// 执行SELECT查询语句
  /// 示例：'SELECT id, name FROM t_user'
  /// [sql]：SELECT SQL语句
  /// 返回：查询结果集
  Future<ResultSet> executeQuery(String sql);

  /// 执行UPDATE更新语句
  /// 示例：'UPDATE t_user SET name = "Albert Moky" WHERE id = "moky@anywhere"'
  /// [sql]：UPDATE SQL语句
  /// 返回：受影响的行数
  Future<int> executeUpdate(String sql);

  /// 执行DELETE删除语句
  /// 示例：'DELETE FROM t_user WHERE id = "moky@anywhere"'
  /// [sql]：DELETE SQL语句
  /// 返回：受影响的行数
  Future<int> executeDelete(String sql);

  /// 关闭语句，释放相关资源
  void close();
}

/// 数据库连接接口（模仿JDBC的Connection）
/// 用于创建Statement对象，管理数据库连接
abstract interface class DBConnection {

  /// 创建Statement对象
  /// 返回：新的Statement实例
  Statement createStatement();

  /// 关闭数据库连接，释放相关资源
  void close();

}

/// 数据行提取器类型定义
/// [T]：提取的目标类型
/// [resultSet]：结果集
/// [index]：行索引
/// 返回：提取后的对象
typedef OnDataRowExtractFn<T> = T Function(ResultSet resultSet, int index);