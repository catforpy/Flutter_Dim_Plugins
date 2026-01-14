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

import 'package:mutex/mutex.dart';

import 'package:dim_client/ok.dart';
import 'package:dim_client/sqlite.dart';

import 'connector.dart';

///
///  SQLite数据库操作工具类：封装通用的数据库操作方法
///


/// 基础数据库处理器：封装通用的SQL执行方法（查询/插入/更新/删除）
/// [T] 结果集映射的实体类型
class DatabaseHandler<T> with Logging {
  /// 构造方法
  /// [connector] 数据库连接器
  DatabaseHandler(this.connector) : _statement = null;

  /// 数据库连接器
  final DatabaseConnector connector;

  /// SQL语句执行对象缓存
  Statement? _statement;

  /// 设置SQL语句执行对象（自动关闭旧对象）
  /// [newSta] 新的语句对象
  void _setStatement(Statement? newSta) {
    var oldSta = _statement;
    if(oldSta == null){
      _statement = newSta;
    }else if(identical(oldSta, newSta)){
      // 对象未变化，无需处理
    }else{
      // 关闭旧对象，替换为新对象
      oldSta.close();
      _statement = newSta;
    }
  }

  // void destroy() {
  //   _setStatement(null);
  // }

  /// 建立数据库连接并创建语句执行对象
  /// 返回语句执行对象（null表示连接失败）
  Future<Statement?> _connect() async {
    var conn = await connector.connection;
    if(conn == null){
      return null;
    }
    var sta = conn.createStatement();
    _setStatement(sta);
    return sta;
  }

  ///  执行查询操作（SELECT）
  ///
  /// @param sql       - 查询SQL语句
  /// @param extractor - 结果集行提取器（将ResultSet映射为实体T）
  /// @return 实体列表
  /// @throws SQLException 数据库操作异常
  Future<List<T>> executeQuery(String sql, OnDataRowExtractFn<T> extractRow) async {
    Statement? sta = await _connect();
    if(sta == null){
      logError('failed to get statement for "$sql"');
      return [];
    }
    List<T> rows = [];
    // 执行查询
    ResultSet res = await sta.executeQuery(sql);
    // 遍历结果集，映射为实体
    while(res.next()){
      rows.add(extractRow(res,res.row-1));
    }
    // 关闭结果集
    res.close();
    return rows;
  }

  ///  执行插入操作（INSERT）
  ///
  /// @param sql - 插入SQL语句
  /// @return 插入的行ID（-1表示失败）
  /// @throws SQLException 数据库操作异常
  Future<int> executeInsert(String sql) async {
    Statement? sta = await _connect();
    if(sta == null){
      logError('failed to get statement for "$sql"');
      return -1;
    }
    return await sta.executeInsert(sql);
  }

  ///  执行更新操作（UPDATE）
  ///
  /// @param sql - 更新SQL语句
  /// @return 受影响的行数（-1表示失败）
  /// @throws SQLException 数据库操作异常
  Future<int> executeUpdate(String sql) async {
    Statement? sta = await _connect();
    if(sta == null){
      logError('failed to get statement for "$sql"');
      return -1;
    }
    return await sta.executeUpdate(sql);
  }

  ///  执行删除操作（DELETE）
  ///
  /// @param sql - 删除SQL语句
  /// @return 受影响的行数（-1表示失败）
  /// @throws SQLException 数据库操作异常
  Future<int> executeDelete(String sql) async {
    Statement? sta = await _connect();
    if (sta == null) {
      logError('failed to get statement for "$sql"');
      return -1;
    }
    return await sta.executeDelete(sql);
  }
}

/// 数据表处理器：抽象类，封装标准化的增删改查操作（基于SQLBuilder）
/// [T] 表行映射的实体类型
abstract class DataTableHandler<T> extends DatabaseHandler<T>{
  /// 构造方法
  /// [connector] 数据库连接器
  /// [onExtract] 结果集行提取器
  DataTableHandler(super.connector, this.onExtract);

  /// 互斥锁：保证并发操作的线程安全
  final Mutex _lock = Mutex();

  // 加锁（子类可调用）
  Future lock() async => await _lock.acquire();
  // 解锁（子类可调用）
  unlock() => _lock.release();

  // 结果集行提取器（子类需传入）
  final OnDataRowExtractFn<T> onExtract;

  /// 插入数据（INSERT）
  /// [table] 表名
  /// [columns] 列名列表
  /// [values] 值列表
  /// 返回插入的行ID
  Future<int> insert(String table,
      {required List<String> columns, required List values}) async{
    // 构建插入SQL
    String sql = SQLBuilder.buildInsert(table, columns: columns, values: values);
    return await executeInsert(sql);
  }

  /// 查询数据（SELECT）
  /// [table] 表名
  /// [distinct] 是否去重
  /// [columns] 查询列名列表
  /// [conditions] 查询条件
  /// [groupBy] 分组字段
  /// [having] 分组条件
  /// [orderBy] 排序字段
  /// [offset] 偏移量
  /// [limit] 限制行数
  /// 返回查询结果列表
  Future<List<T>> select(String table,
      {bool distinct = false,
        required List<String> columns, required SQLConditions conditions,
        String? groupBy, String? having, String? orderBy,
        int offset = 0, int? limit}) async {
    // 构建查询SQL
    String sql = SQLBuilder.buildSelect(table, distinct: distinct,
     columns: columns, conditions: conditions,
     groupBy: groupBy,having: having,orderBy: orderBy,
     offset: offset,limit: limit);
    return await executeQuery(sql, onExtract);
  }

  /// 更新数据（UPDATE）
  /// [table] 表名
  /// [values] 列值映射
  /// [conditions] 更新条件
  /// 返回受影响的行数
  Future<int> update(String table,
      {required Map<String, dynamic> values,
        required SQLConditions conditions}) async{
    // 构建更新SQL
    String sql = SQLBuilder.buildUpdate(table,
     values: values, conditions: conditions);
    return await executeUpdate(sql);
  }

  /// 删除数据（DELETE）
  /// [table] 表名
  /// [conditions] 删除条件
  /// 返回受影响的行数
  Future<int> delete(String table, {required SQLConditions conditions}) async {
    // 构建删除SQL
    String sql = SQLBuilder.buildDelete(table, conditions: conditions);
    return await executeDelete(sql);
  }
}