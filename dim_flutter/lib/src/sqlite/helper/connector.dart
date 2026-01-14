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

import 'package:sqflite/sqflite.dart';

import 'package:dim_client/ok.dart';
import 'package:dim_client/sqlite.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/pnf.dart';

import '../../common/platform.dart';
import '../../filesys/local.dart';


///
///  SQLite数据库连接器：管理数据库连接的创建、销毁，提供SQL操作工具方法
///

class DatabaseConnector {
  /// 构造方法
  /// [name] 数据库文件名（如'user.db'）
  /// [directory] 数据库文件所在子目录（可选）
  /// [version] 数据库版本号（可选）
  /// [onConfigure/onCreate/onUpgrade/onDowngrade/onOpen] 数据库生命周期回调
  DatabaseConnector({required this.name, this.directory, this.version,
    this.onConfigure,
    this.onCreate, this.onUpgrade, this.onDowngrade,
    this.onOpen});

  /// 数据库文件名（如'user.db'）
  final String name;
  /// 数据库文件所在子目录（可选）
  final String? directory;
  /// 数据库版本号
  final int? version;

  /// 数据库配置回调
  final OnDatabaseConfigureFn? onConfigure;
  /// 数据库创建回调
  final OnDatabaseCreateFn? onCreate;
  /// 数据库升级回调
  final OnDatabaseVersionChangeFn? onUpgrade;
  /// 数据库降级回调
  final OnDatabaseVersionChangeFn? onDowngrade;
  /// 数据库打开回调
  final OnDatabaseOpenFn? onOpen;

  /// 数据库连接缓存
  DBConnection? _connection;

  /// 获取数据库文件的完整路径
  Future<String?> get path async => await DBPath.getDatabasePath(this);

  /// 打开指定路径的数据库
  /// [path] 数据库文件路径
  /// 返回数据库实例
  Future<Database> _open(String path) async => 
      await openDatabase(path,version: version,
          onConfigure: onConfigure,
          onCreate: onCreate,onUpgrade: onUpgrade,onDowngrade: onDowngrade,
          onOpen: onOpen);
  
  /// 获取数据库连接（懒加载，缓存连接实例）
  /// 返回数据库连接实例（null表示打开失败）
  Future<DBConnection?> get connection async{
    DBConnection? conn = _connection;
    if(conn == null){
      String? filepath = await path;
      if(filepath != null){
        Log.debug('opening database: $filepath');
        try{
          // 打开数据库并创建连接封装对象
          Database db = await _open(filepath);
          conn = _Connection(db);
          _connection = conn;
        }on DatabaseException catch(e){
          // 打开失败，记录错误日志
          Log.error('failed to open database: $e');
        }
      }
    }
    return conn;
  }

  /// 销毁数据库连接（关闭连接并清空缓存）
  void destroy() {
    DBConnection? conn = _connection;
    if (conn != null) {
      _connection = null;
      conn.close();
    }
  }

  /// 创建数据表
  /// [db] 数据库实例
  /// [table] 表名
  /// [fields] 字段定义列表（如['id INTEGER PRIMARY KEY', 'name TEXT']）
  static void createTable(Database db, String table,
      {required List<String> fields}) {
    String sql = SQLBuilder.buildCreateTable(table, fields: fields);
    DBLogger.output('createTable: $sql');
    db.execute(sql);
  }

  /// 创建索引
  /// [db] 数据库实例
  /// [table] 表名
  /// [name] 索引名
  /// [fields] 索引字段列表
  static void createIndex(Database db, String table,
      {required String name, required List<String> fields}){
    String sql = SQLBuilder.buildCreateIndex(table, name: name, fields: fields);
    DBLogger.output('createIndex: $sql');
    db.execute(sql);
  }

  /// 新增表列
  /// [db] 数据库实例
  /// [table] 表名
  /// [name] 列名
  /// [type] 列类型（如'TEXT'、'INTEGER'）
  static void addColumn(Database db, String table,
      {required String name, required String type}) {
    String sql = SQLBuilder.buildAddColumn(table, name: name, type: type);
    DBLogger.output('alterTable: $sql');
    db.execute(sql);
  }
}

/// 数据库路径工具类：提供跨平台的数据库文件路径计算逻辑
abstract class DBPath{

  /// Android:
  ///       '/data/user/0/chat.dim.tarsier/databases/*.db'
  ///       '/sdcard/Android/data/chat.dim.tarsier/files/.dkd/msg.db'
  /// iOS:
  ///       '/var/mobile/Containers/Data/Application/{XXX}/Documents/*.db'
  ///       '/var/mobile/Containers/Data/Application/{XXX}/Library/Caches/.dkd/msg.db'
  /// Windows:
  ///       'C:\Users\moky\AppData\Roaming\chat.dim.tarsier\databases\*.db'
  ///       'C:\Users\moky\AppData\Roaming\chat.dim.tarsier\databases\.dkd\msg.db'
  /// 获取数据库文件的完整路径（适配不同平台）
  /// [connector] 数据库连接器
  /// 返回数据库文件路径（null表示创建目录失败）
  static Future<String?> getDatabasePath(DatabaseConnector connector) async {
    String name = connector.name;
    String? sub = connector.directory;
    String root = await LocalStorage().cachesDirectory;
    DevicePlatform.patchSQLite();
    // 检查平台类型
    if(DevicePlatform.isMobile){
      // iOS 或 Android 平台
      if (sub == null) {
        // 无子目录，使用系统默认数据库目录
        String root = await getDatabasesPath();
        Log.info('internal database: $name in $root');
        return Paths.append(root, name);
      }
      // 有子目录，拼接目录
      root = Paths.append(root,sub);
      Log.info('external database: $name in $root');
    }else{
      // MacOS、Windows、Linux、Web 等平台
      root = Paths.append(root, 'databases');
      if (sub != null) {
        root = Paths.append(root, sub);
      }
      Log.info('common database: $name in $root');
    }
    // 确保父目录存在
    if(await Paths.mkdirs(root)) {} else{
      Log.error('failed to create directory: $root');
      return null;
    }
    // 拼接最终的数据库文件路径
    return Paths.append(root,name);
  }

  /// 获取数据库目录路径（适配不同平台）
  /// [sub] 子目录（可选）
  /// 返回数据库目录路径
  static Future<String> getDatabaseDirectory(String? sub) async {
    String root = await LocalStorage().cachesDirectory;
    DevicePlatform.patchSQLite();
    // 检查平台类型
    if (DevicePlatform.isMobile) {
      // iOS 或 Android 平台
      if (sub == null) {
        return await getDatabasesPath();
      }
      root = Paths.append(root, sub);
    } else {
      // MacOS、Windows、Linux、Web 等平台
      root = Paths.append(root, 'databases');
      if (sub != null) {
        root = Paths.append(root, sub);
      }
    }
    return root;
  }
}

/// 数据库日志工具类：统一管理SQL操作的日志输出
abstract class DBLogger {

  /// SQL日志标签
  static const String kSqlTag    = '- SQL -';
  /// SQL日志颜色（ANSI转义码，蓝色）
  static const String kSqlColor  = '\x1B[94m';

  /// 默认日志器实例
  static final DefaultLogger logger = DefaultLogger();

  /// 输出SQL日志
  /// [msg] 日志内容
  static void output(String msg) =>
      logger.output(msg, tag: kSqlTag, color: kSqlColor);
}

/// 数据库连接实现类：封装sqflite的Database，实现DBConnection接口
class _Connection implements DBConnection {
  /// 构造方法
  /// [database] sqflite的Database实例
  _Connection(this.database);

  /// sqflite的Database实例
  final Database database;

  /// 关闭数据库连接
  @override
  void close(){
    if(database.isOpen){
      database.close();
    }
  }

  /// 创建SQL语句执行对象
  @override
  Statement createStatement() => _Statement(database);
}

/// SQL语句实现类：封装sqflite的Database，实现Statement接口
class _Statement implements Statement {
  /// 构造方法
  /// [database] sqflite的Database实例
  _Statement(this.database);

  /// sqflite的Database实例
  final Database database;

  /// 关闭语句（空实现，sqflite无需显式关闭语句）
  @override
  void close() {
  }

  /// 执行查询语句（SELECT）
  /// [sql] 查询SQL
  /// 返回结果集
  @override
  Future<ResultSet> executeQuery(String sql) async {
    // DBLogger.output('executeQuery: $sql');
    return _ResultSet(await database.rawQuery(sql));
  }

  /// 执行插入语句（INSERT）
  /// [sql] 插入SQL
  /// 返回插入的行ID
  @override
  Future<int> executeInsert(String sql) async {
    DBLogger.output('executeInsert: $sql');
    return await database.rawInsert(sql);
  }

  /// 执行更新语句（UPDATE）
  /// [sql] 更新SQL
  /// 返回受影响的行数
  @override
  Future<int> executeUpdate(String sql) async {
    DBLogger.output('executeUpdate: $sql');
    return await database.rawUpdate(sql);
  }

  /// 执行删除语句（DELETE）
  /// [sql] 删除SQL
  /// 返回受影响的行数
  @override
  Future<int> executeDelete(String sql) async {
    DBLogger.output('executeDelete: $sql');
    return await database.rawDelete(sql);
  }
}

/// 结果集实现类：封装sqflite的查询结果，实现ResultSet接口
class _ResultSet implements ResultSet {
  /// 构造方法
  /// [_results] sqflite的查询结果（List<Map>）
  _ResultSet(this._results) : _cursor = 0;

  /// sqflite的查询结果
  List<Map> _results;
  /// 结果集游标（当前行索引，从1开始）
  int _cursor;

  /// 获取当前行号（游标位置）
  @override
  int get row{
    if(_cursor < 0){
      throw Exception('ResultSet closed');
    }else if (_cursor == 0 && _results.isNotEmpty) {
      throw Exception('Call next() first');
    }
    return _cursor;
  }

  /// 移动到下一行
  /// 返回是否有下一行
  @override
  bool next() {
    if (_cursor < 0) {
      throw Exception('ResultSet closed');
    } else if (_cursor > _results.length) {
      throw Exception('Out of range: $_cursor, length: ${_results.length}');
    } else if (_cursor == _results.length) {
      return false;
    }
    ++_cursor;
    return true;
  }

  /// 获取指定列的值
  /// [columnLabel] 列名
  /// 返回列值
  @override
  dynamic getValue(String columnLabel) => 
    _results[_cursor - 1][columnLabel];

  /// 获取字符串类型的列值
  /// [column] 列名
  /// 返回字符串值（null表示无值或类型不匹配）
  @override
  String? getString(String column) => 
    Converter.getString(getValue(column));

  /// 获取布尔类型的列值
  /// [column] 列名
  /// 返回布尔值（null表示无值或类型不匹配）
  @override
  bool? getBool(String column) => Converter.getBool(getValue(column));

  /// 获取整数类型的列值
  /// [column] 列名
  /// 返回整数值（null表示无值或类型不匹配）
  @override
  int? getInt(String column) => Converter.getInt(getValue(column));

  /// 获取浮点类型的列值
  /// [column] 列名
  /// 返回浮点值（null表示无值或类型不匹配）
  @override
  double? getDouble(String column) => Converter.getDouble(getValue(column));

  /// 获取日期时间类型的列值
  /// [column] 列名
  /// 返回日期时间值（null表示无值或类型不匹配）
  @override
  DateTime? getDateTime(String column) => Converter.getDateTime(getValue(column));

  /// 关闭结果集（清空数据，标记游标为-1）
  @override
  void close() {
    _cursor = -1;
    // _results.clear();
    _results = [];
  }
}