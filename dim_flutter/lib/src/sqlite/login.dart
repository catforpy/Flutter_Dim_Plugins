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
import 'package:dim_client/common.dart';

import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';


///
///  存储登录命令消息
///
///     文件路径: '{sdcard}/Android/data/chat.dim.sechat/files/.dim/login.db'
///


/// 登录数据库连接器：管理login.db的创建和表结构
class LoginDatabase extends DatabaseConnector {
  /// 构造方法：初始化数据库配置
  LoginDatabase() : super(name: dbName, directory: '.dim', version: dbVersion,
      onCreate: (db, version) {
        // 创建登录命令表
        DatabaseConnector.createTable(db, tLogin, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "uid VARCHAR(64) NOT NULL",    // 用户ID
          "cmd TEXT NOT NULL",           // 登录命令（JSON字符串）
          "msg TEXT NOT NULL",           // 消息（JSON字符串）
          "token TEXT",                  // 新增：登录token（可选字段）
        ]);
        // 为uid字段创建索引
        DatabaseConnector.createIndex(db, tLogin,
            name: 'uid_index', fields: ['uid']);
      }, onUpgrade: (db, oldVersion, newVersion) {
        // TODO: 版本升级逻辑
        if(oldVersion < 2){
          db.execute('ALTER TABLE $tLogin ADD COLUMN token TEXT;');
        }
      });

  /// 数据库文件名
  static const String dbName = 'login.db';
  /// 数据库版本号
  static const int dbVersion = 1;

  /// 表名常量
  static const String tLogin         = 't_login';  // 登录命令表

}


// /// 从数据库结果集中提取登录命令和消息对
// /// [resultSet] 数据库查询结果集
// /// [index] 行索引
// /// 返回登录命令-消息对
// Pair<LoginCommand, ReliableMessage> _extractCommandMessage(ResultSet resultSet, int index) {
//   // 解析登录命令
//   Map? cmd = JSONMap.decode(resultSet.getString('cmd')!);
//   // 解析消息
//   Map? msg = JSONMap.decode(resultSet.getString('msg')!);
//   // 返回命令-消息对
//   return Pair(Command.parse(cmd) as LoginCommand, ReliableMessage.parse(msg)!);
// }

/// 自定义登录记录类（替代原有的Pair，更易扩展）
class LoginRecord {
  final LoginCommand cmd;
  final ReliableMessage msg;
  final String? token;  // 登录token

  LoginRecord(this.cmd, this.msg, this.token);
}

/// 从数据库结果集中提取登录记录（包含token）
LoginRecord _extractLoginRecord(ResultSet resultSet, int index) {
  // 解析登录命令
  Map? cmd = JSONMap.decode(resultSet.getString('cmd')!);
  // 解析消息
  Map? msg = JSONMap.decode(resultSet.getString('msg')!);
  // 解析token（新增）
  String? token = resultSet.getString('token');
  // 返回包含token的登录记录
  return LoginRecord(
    Command.parse(cmd) as LoginCommand,
    ReliableMessage.parse(msg)!,
    token,
  );
}


/// 登录命令数据表处理器：封装登录命令表的增删改查操作
class _LoginCommandTable extends DataTableHandler<LoginRecord> {
  /// 构造方法：初始化数据库连接器和结果集提取器
  _LoginCommandTable() : super(LoginDatabase(), _extractLoginRecord);

  /// 登录命令表名
  static const String _table = LoginDatabase.tLogin;
  /// 查询列名列表
  static const List<String> _selectColumns = ["cmd", "msg"];
  /// 插入列名列表
  static const List<String> _insertColumns = ["uid", "cmd", "msg"];

  // 加载指定用户的登录命令消息列表
  // [identifier] 用户ID
  // 返回登录命令-消息对列表
  Future<List<LoginRecord>> loadLoginCommandMessages(ID identifier) async {
    // 构建查询条件：用户ID匹配
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: identifier.toString());
    // 按ID降序查询
    return await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'id DESC');
  }

  // 删除指定用户的登录命令消息
  // [identifier] 用户ID
  // 返回操作是否成功
  Future<bool> deleteLoginCommandMessage(ID identifier) async {
    // 构建删除条件：用户ID匹配
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: identifier.toString());
    // 执行删除操作
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove login command: $identifier');
      return false;
    }
    return true;
  }

  // 保存登录命令消息
  // [identifier] 用户ID
  // [content] 登录命令
  // [rMsg] 可靠消息
  // 返回操作是否成功
  Future<bool> saveLoginCommandMessage(
    ID identifier, 
    LoginCommand content,
     ReliableMessage rMsg,{
      String? token,        // 可选的token参数
     }) async {
    // 序列化为JSON字符串
    String cmd = JSON.encode(content.toMap());
    String msg = JSON.encode(rMsg.toMap());
    // 构建插入值列表
    List values = [
      identifier.toString(),
      cmd,
      msg,
      token,      // token可为null，数据库会自动存null
    ];
    // 执行插入操作
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      logError('failed to save login command: $identifier -> $content');
      return false;
    }
    return true;
  }

}

/// 登录命令数据访问任务：封装带缓存的登录命令读写操作
class _LoginTask extends DbTask<ID, List<LoginRecord>> {
  /// 构造方法
  /// [mutexLock] 互斥锁
  /// [cachePool] 缓存池
  /// [_table] 登录命令表处理器
  /// [_user] 用户ID
  /// [cmd] 登录命令（可选）
  /// [msg] 可靠消息（可选）
  /// [token] 可选的token参数
  _LoginTask(super.mutexLock, super.cachePool, this._table, this._user, {
    required LoginCommand? cmd,
    required ReliableMessage? msg,
    required String? token,       // 新增token参数
  }) : _cmd = cmd, _msg = msg, _token = token;

  /// 用户ID（缓存键）
  final ID _user;

  /// 登录命令
  final LoginCommand? _cmd;
  /// 可靠消息
  final ReliableMessage? _msg;

  /// 登录命令表处理器
  final _LoginCommandTable _table;

  /// token参数
  final String? _token;

  /// 缓存键（用户ID）
  @override
  ID get cacheKey => _user;

  /// 从数据库读取登录命令消息列表
  @override
  Future<List<LoginRecord>?> readData() async {
    return await _table.loadLoginCommandMessages(_user);
  }

  /// 写入登录命令消息到数据库
  @override
  Future<bool> writeData(List<LoginRecord> records) async {
    LoginCommand? cmd = _cmd;
    ReliableMessage? msg = _msg;
    if (cmd == null || msg == null) {
      assert(false, 'should not happen: $cmd, $msg');
      return false;
    }
    ID identifier = cmd.identifier;
    // 如果已有记录，先删除
    if (records.isNotEmpty) {
      var ok = await _table.deleteLoginCommandMessage(identifier);
      if (ok) {
        records.clear();
      } else {
        assert(false, 'failed to clear login commands: $identifier');
        return false;
      }
    }
    // 保存新记录
    var ok = await _table.saveLoginCommandMessage(identifier, cmd, msg,token: _token);
    if (ok) {
      records.add(LoginRecord(cmd, msg, _token));
    }
    return ok;
  }

}

/// 登录命令缓存管理器：实现LoginDBI接口，提供登录命令的缓存操作
class LoginCommandCache extends DataCache<ID, List<LoginRecord>> implements LoginDBI {
  /// 构造方法：初始化缓存池（名称为'login_command'）
  LoginCommandCache() : super('login_command');

  /// 登录命令表处理器实例
  final _LoginCommandTable _table = _LoginCommandTable();

  /// 创建新的登录命令数据访问任务
  /// [identifier] 用户ID
  /// [cmd] 登录命令（可选）
  /// [msg] 可靠消息（可选）
  /// 返回登录命令任务实例
  _LoginTask _newTask(ID identifier, {LoginCommand? cmd, ReliableMessage? msg, String? token}) =>
      _LoginTask(mutexLock, cachePool, _table, identifier, cmd: cmd, msg: msg, token: token);

  /// 获取指定用户的登录命令消息
  /// [identifier] 用户ID
  /// 返回登录命令-消息对（null表示无）
  @override
  Future<Pair<LoginCommand?, ReliableMessage?>> getLoginCommandMessage(ID identifier) async {
    var task = _newTask(identifier);
    var array = await task.load();
    if (array == null || array.isEmpty) {
      return const Pair(null, null);
    }
    var pair = array.first;
    return Pair(pair.cmd, pair.msg);
  }

  /// 保存登录命令消息（带缓存和通知）
  /// [identifier] 用户ID
  /// [content] 登录命令
  /// [rMsg] 可靠消息
  /// 返回操作是否成功
  @override
  Future<bool> saveLoginCommandMessage(
    ID identifier, 
    LoginCommand content, 
    ReliableMessage rMsg,
    {String? token}) async {
    //
    //  1. 检查旧记录
    //
    var task = _newTask(identifier);
    var array = await task.load();
    if (array == null) {
      array = [];
    } else {
      // 检查时间：新命令时间不能早于旧命令
      DateTime? newTime = content.getDateTime('time');
      if (newTime != null) {
        DateTime? oldTime;
        for (LoginRecord item in array) {
          oldTime = item.cmd.getDateTime('time');
          if (oldTime != null && oldTime.isAfter(newTime)) {
            logWarning('ignore expired login: $content');
            return false;
          }
        }
      }
    }
    //
    //  2. 保存新记录
    //
    task = _newTask(identifier, cmd: content, msg: rMsg,token: token);
    bool ok = await task.save(array);
    if (!ok) {
      logError('failed to save login command: $identifier -> $content');
      return false;
    }
    //
    //  3. 发送登录命令更新通知
    //
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kLoginCommandUpdated, this, {
      'ID': identifier,
      'cmd': content,
      'msg': rMsg,
      'token': token,     // 通知中携带token
    });
    return true;
  }

  // ------------------------------
  // 实现 LoginDBI 新增扩展方法
  // ------------------------------
  @override
  Future<Map<String, dynamic>?> getLoginRecordMap(ID identifier) async {
    var task = _newTask(identifier);
    var array = await task.load();
    if (array == null || array.isEmpty) {
      return null;
    }
    var record = array.first;
    // 返回通用 Map，对外隐藏 LoginRecord 实现细节
    return {
      "cmd": record.cmd,
      "msg": record.msg,
      "token": record.token,
    };
  }

  @override
  Future<bool> saveLoginRecordWithToken(
    ID identifier,
    LoginCommand content,
    ReliableMessage rMsg, {
    String? token,
  }) async {
    // 复用已实现的 saveLoginCommandMessage 方法，减少重复代码
    return await saveLoginCommandMessage(identifier, content, rMsg, token: token);
  }

}