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

import 'conditions.dart';
import 'values.dart';

/// SQL语句构建器
/// 提供静态方法用于构建常见的SQL语句（CREATE/ALTER/INSERT/SELECT/UPDATE/DELETE）
class SQLBuilder {
  /// 构造方法
  /// [command]：SQL命令（如SELECT/INSERT/UPDATE等）
  SQLBuilder(String command) : _sb = StringBuffer(command);

  /// 字符串缓冲区，用于拼接SQL语句
  final StringBuffer _sb;

  /// SQL命令常量 - 创建
  static const String create = "CREATE";
  /// SQL命令常量 - 修改
  static const String alter  = "ALTER";

  /// SQL命令常量 - 插入
  static const String insert = "INSERT";
  /// SQL命令常量 - 查询
  static const String select = "SELECT";
  /// SQL命令常量 - 更新
  static const String update = "UPDATE";
  /// SQL命令常量 - 删除
  static const String delete = "DELETE";

  /// 重写toString方法，返回构建的SQL语句
  @override
  String toString() => _sb.toString();

  /// 追加字符串到缓冲区
  /// [sub]：要追加的字符串
  void _append(String sub) {
    _sb.write(sub);
  }

  /// 追加字符串列表到缓冲区（用逗号分隔）
  /// [array]：字符串列表
  void _appendStringList(List<String> array) {
    SQLValues.appendStringList(_sb, array);
  }

  /// 追加转义后的值列表到缓冲区（用逗号分隔）
  /// [array]：值列表
  void _appendEscapeValueList(List array) {
    SQLValues.appendEscapeValueList(_sb, array);
  }

  /// 追加SQLValues到缓冲区
  /// [values]：SQLValues对象
  void _appendValues(SQLValues values) {
    values.appendValues(_sb);
  }

  /// 追加查询列到缓冲区
  /// 如果列列表为空则追加" *"，否则追加列列表（用逗号分隔）
  /// [columns]：列名列表
  void _appendColumns(List<String> columns) {
    if (columns.isEmpty) {
      _append(' *');
    } else {
      _append(' ');
      _appendStringList(columns);
    }
  }

  /// 追加SQL子句（如GROUP BY/HAVING/ORDER BY）
  /// [name]：子句名称（如" GROUP BY "）
  /// [clause]：子句内容
  void _appendClause(String name, String? clause) {
    if (clause == null || clause.isEmpty) {
      return;
    }
    _append(name);
    _append(clause);
  }

  /// 追加WHERE条件子句
  /// [conditions]：SQL条件对象
  void _appendWhere(SQLConditions? conditions) {
    if (conditions == null) {
      return;
    }
    _append(' WHERE ');
    conditions.appendEscapeValue(_sb);
  }

  /// 构建创建表的SQL语句
  /// 格式：CREATE TABLE IF NOT EXISTS table (field type, ...);
  /// [table]：表名
  /// [fields]：字段定义列表（如["id TEXT PRIMARY KEY", "name TEXT"]）
  /// 返回：创建表的SQL语句
  static String buildCreateTable(String table, {required List<String> fields}) {
    SQLBuilder builder = SQLBuilder(create);
    builder._append(' TABLE IF NOT EXISTS ');
    builder._append(table);
    builder._append('(');
    builder._appendStringList(fields);
    builder._append(')');
    return builder.toString();
  }

  /// 构建创建索引的SQL语句
  /// 格式：CREATE INDEX IF NOT EXISTS name ON table (fields);
  /// [table]：表名
  /// [name]：索引名
  /// [fields]：索引字段列表
  /// 返回：创建索引的SQL语句
  static String buildCreateIndex(String table,
      {required String name, required List<String> fields}) {
    SQLBuilder builder = SQLBuilder(create);
    builder._append(' INDEX IF NOT EXISTS ');
    builder._append(name);
    builder._append(' ON ');
    builder._append(table);
    builder._append('(');
    builder._appendStringList(fields);
    builder._append(')');
    return builder.toString();
  }

  /// 构建添加列的SQL语句
  /// 格式：ALTER TABLE table ADD COLUMN name type;
  /// [table]：表名
  /// [name]：列名
  /// [type]：列类型（如TEXT/INTEGER）
  /// 返回：添加列的SQL语句
  static String buildAddColumn(String table,
      {required String name, required String type}) {
    SQLBuilder builder = SQLBuilder(alter);
    builder._append(' TABLE ');
    builder._append(table);
    // builder._append(' ADD COLUMN IF NOT EXISTS ');
    builder._append(' ADD COLUMN ');
    builder._append(name);
    builder._append(' ');
    builder._append(type);
    return builder.toString();
  }

  //  DROP TABLE IF EXISTS table; （待实现）

  /// 构建插入数据的SQL语句
  /// 格式：INSERT INTO table (columns) VALUES (values);
  /// [table]：表名
  /// [columns]：列名列表
  /// [values]：值列表（会自动转义）
  /// 返回：插入数据的SQL语句
  static String buildInsert(String table,
      {required List<String> columns, required List values}) {
    SQLBuilder builder = SQLBuilder(insert);
    builder._append(' INTO ');
    builder._append(table);
    builder._append('(');
    builder._appendStringList(columns);
    builder._append(') VALUES (');
    builder._appendEscapeValueList(values);
    builder._append(')');
    return builder.toString();
  }

  /// 构建查询数据的SQL语句
  /// 格式：SELECT DISTINCT columns FROM tables WHERE conditions
  ///          GROUP BY ... HAVING ... ORDER BY ... LIMIT count OFFSET start;
  /// [table]：表名
  /// [distinct]：是否去重
  /// [columns]：查询列列表（空则查询所有列）
  /// [conditions]：查询条件
  /// [groupBy]：GROUP BY子句
  /// [having]：HAVING子句
  /// [orderBy]：ORDER BY子句
  /// [offset]：偏移量
  /// [limit]：限制行数
  /// 返回：查询数据的SQL语句
  static String buildSelect(String table,
      {bool distinct = false,
        required List<String> columns, required SQLConditions conditions,
        String? groupBy, String? having, String? orderBy,
        int offset = 0, int? limit}) {
    SQLBuilder builder = SQLBuilder(select);
    if (distinct) {
      builder._append(' DISTINCT');
    }
    builder._appendColumns(columns);
    builder._append(' FROM ');
    builder._append(table);
    builder._appendWhere(conditions);
    builder._appendClause(' GROUP BY ', groupBy);
    builder._appendClause(' HAVING ', having);
    builder._appendClause(' ORDER BY ', orderBy);
    if (limit != null) {
      builder._append(' LIMIT $limit OFFSET $offset');
    }
    return builder.toString();
  }

  /// 构建更新数据的SQL语句
  /// 格式：UPDATE table SET name=value WHERE conditions
  /// [table]：表名
  /// [values]：更新的键值对（列名-值）
  /// [conditions]：更新条件
  /// 返回：更新数据的SQL语句
  static String buildUpdate(String table,
      {required Map<String, dynamic> values, required SQLConditions conditions}) {
    SQLBuilder builder = SQLBuilder(update);
    builder._append(' ');
    builder._append(table);
    builder._append(' SET ');
    builder._appendValues(SQLValues.from(values));
    builder._appendWhere(conditions);
    return builder.toString();
  }

  /// 构建删除数据的SQL语句
  /// 格式：DELETE FROM table WHERE conditions
  /// [table]：表名
  /// [conditions]：删除条件
  /// 返回：删除数据的SQL语句
  static String buildDelete(String table, {required SQLConditions conditions}) {
    SQLBuilder builder = SQLBuilder(delete);
    builder._append(' FROM ');
    builder._append(table);
    builder._appendWhere(conditions);
    return builder.toString();
  }
}