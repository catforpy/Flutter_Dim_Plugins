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
import 'package:dim_flutter/src/common/dbi/app.dart';

import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';


///
///  存储应用自定义信息
///
///     文件路径: '{sdcard}/Android/data/chat.dim.sechat/files/.dkd/app.db'
///


/// 应用自定义信息数据库连接器：管理app.db的创建和升级
class AppCustomizedDatabase extends DatabaseConnector{
  /// 构造方法：初始化数据库配置
  AppCustomizedDatabase() : super(name: dbName,version: dbVersion,
  directory: '.dkd',onCreate: (db, version) {
    // 创建自定义信息表
    DatabaseConnector.createTable(db, tCustomizedInfo, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "key VARCHAR(64) NOT NULL UNIQUE",
      "content TEXT NOT NULL",
      "time INTEGER NOT NULL",     // 消息时间（秒）
      "expired INTEGER NOT NULL",  // 过期时间（秒）
      "mod VARCHAR(32)",           // 模块名
    ]);
    // 为key字段创建索引
    DatabaseConnector.createIndex(db, tCustomizedInfo, 
    name: 'key_index', fields: ['key']);
  },
  onUpgrade: (db, oldVersion, newVersion) {
    //TODO:数据库升级逻辑
  });
  /// 数据库文件名
  static const String dbName = 'app.db';
  /// 数据库版本号
  static const int dbVersion = 1;

  /// 自定义信息表名
  static const String tCustomizedInfo = 't_info';
}

/// 从结果集中提取自定义信息（JSON转Mapper）
/// [resultSet] 数据库查询结果集
/// [index] 行索引
/// 返回自定义信息Mapper对象
Mapper _extractCustomizedInfo(ResultSet resultSet, int index) {
  String json = resultSet.getString('content') ?? '';
  Mapper? content;
  try{
    // 解析JSON字符串为Map
    Map? info = JSONMap.decode(json);
    if(info != null){
      content = Dictionary(info);
    }
  }catch(e,st){
    Log.error('failed to extract message: $json');
    Log.error('failed to extract message: $e, $st');
  }
  if(content == null){
    // 解析失败，构建错误信息
    content = Dictionary({
      'text' : json,
      'error' : 'failed to extract message',
    });
    // 补充时间和模块信息
    DateTime? time = resultSet.getDateTime('time');
    if(time != null){
      content.setDateTime('time', time);
    }
    String? mod = resultSet.getString('mod');
    if (mod != null) {
      content['mod'] = mod;
    }
  }
  return content;
}

/// 自定义信息数据表处理器：封装自定义信息表的增删改查操作
class _CustomizedInfoTable extends DataTableHandler<Mapper>{
  /// 构造方法：初始化数据库连接器和结果集提取器
  _CustomizedInfoTable() : super(AppCustomizedDatabase(), _extractCustomizedInfo);

  /// 自定义信息表名
  static const String _table = AppCustomizedDatabase.tCustomizedInfo;
  /// 查询列名列表
  static const List<String> _selectColumns = ["content","time","mod"];
  /// 插入列名列表
  static const List<String> _insertColumns = ["key","content","time","expired","mod"]; 

  /// 默认过期时间（7天）
  static const Duration kExpires = Duration(days: 7);

  /// 将DateTime转换成时间戳(秒)
  static int timestamp(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;

  // 清理过期的自定义信息
  // 返回操作是否成功
  Future<bool> clearExpiredContents() async {
    DateTime now = DateTime.now();
    // 构建删除条件：过期时间 < 当前时间
    SQLConditions cond;
    cond = SQLConditions(left: 'expired', comparison: '<', right: timestamp(now));
    // 执行删除操作
    if(await delete(_table,conditions:cond) < 0){
      logError('failed to clear expired contents: $now');
      return false;
    }
    return true;
  }

  // 清理指定key的自定义信息
  // [key] 自定义信息键
  // 返回操作是否成功
  Future<bool> clearContents(String key) async {
    // 构建删除条件： key匹配
    SQLConditions cond;
    cond = SQLConditions(left: 'key', comparison: '=', right: key);
    // 执行删除操作
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove contents: $key');
      return false;
    }
    return true;
  }

  // 添加新的自定义信息
  // [content] 自定义信息内容
  // [key] 自定义信息键
  // [expires] 过期时间（可选，默认7天）
  // 返回操作是否成功
  Future<bool> addContent(Mapper content, String key, {Duration? expires}) async {
    DateTime? now = DateTime.now();
    // 确定时间字段（使用content中的time或当前时间）
    DateTime? time = content.getDateTime('time');
    if(time == null || time.isAfter(now)){
      time = now;
    }
    // 计算过期时间
    DateTime? expired = now.add(expires ?? kExpires);
    // 获取模块名
    String? mod = content.getString('mod');
    // 构建插入值列表
    List values = [key,
      JSON.encode(content.toMap()),
      timestamp(time),
      timestamp(expired),
      mod,
    ];
    // 执行插入操作
    if(await insert(_table, columns: _insertColumns, values: values) <= 0){
      logError('failed to save customized content: $key -> $content');
      return false;
    }
    return true;
  }

  // 更新自定义信息
  // [content] 新的自定义信息内容
  // [key] 自定义信息键
  // [expires] 过期时间（可选，默认7天）
  // 返回操作是否成功
  Future<bool> updateContent(Mapper content, String key, {Duration? expires}) async {
    DateTime? now = DateTime.now();
    // 确定时间字段（使用content中的time或当前时间）
    DateTime? time = content.getDateTime('time');
    if(time == null || time.isAfter(now)){
      time = now;
    }
    // 计算过期时间
    DateTime? expired = now.add(expires ?? kExpires);
    // 获取模块名
    String? mod = content.getString('mod');
    // 构建更新值映射
    Map<String,dynamic> values = {
      'content': JSON.encode(content.toMap()),
      'time': timestamp(time),
      'expired': timestamp(expired),
      'mod': mod,
    };
    // 构建更新条件： key匹配
    SQLConditions cond;
    cond = SQLConditions(left: 'key', comparison: '=', right: key);
    // 执行更新操作
    if(await update(_table, values: values, conditions: cond) <= 0){
      logError('failed to update customized content: $key -> $content');
      return false;
    }
    return true;
  }

  // 加载指定key的自定义信息列表
  // [key] 自定义信息键
  // 返回自定义信息列表
  Future<List<Mapper>> loadContents(String key) async {
    // 构建查询条件：key匹配
    SQLConditions cond;
    cond = SQLConditions(left: 'key', comparison: '=', right: key);
    // 执行查询操作（按时间降序）
    return await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'time DESC');
  }
}

/// 自定义信息数据访问任务：封装带缓存的自定义信息读写操作
class _CustomizedTask extends DbTask<String, List<Mapper>>{
  /// 构造方法
  /// [mutexLock] 互斥锁
  /// [cachePool] 缓存池
  /// [_table] 自定义信息表处理器
  /// [_cacheKey] 缓存键（自定义信息key）
  /// [newContent] 新的自定义信息（可选）
  /// [expires] 过期时间（可选）
  _CustomizedTask(super.mutexLock, super.cachePool, this._table, this._cacheKey, {
    required Mapper? newContent,
    required Duration? expires,
  }) : _newContent = newContent, _dataExpires = expires;

  /// 缓存键（自定义信息key）
  final String _cacheKey;

  /// 新的自定义信息（用于更新）
  final Mapper? _newContent;
  /// 过期时间
  final Duration? _dataExpires;

  /// 自定义信息表处理器
  final _CustomizedInfoTable _table;

  /// 缓存键（自定义信息key）
  @override
  String get cacheKey => _cacheKey;

  /// 从数据库读取自定义信息列表
  @override
  Future<List<Mapper>?> readData() async {
    List<Mapper> array = await _table.loadContents(_cacheKey);
    // 断言：每个key最多只有一条记录
    assert(array.length <= 1, 'duplicated contents: $_cacheKey -> $array');
    return array;
  }

  /// 写入自定义信息到数据库
  @override
  Future<bool> writeData(List<Mapper> contents) async {
    Mapper? newContent = _newContent;
    if(newContent == null){
      assert(false, 'should not happen: $_cacheKey');
      return false;
    }
    bool ok;
    if(contents.length == 1){
      // 记录已存在，更新旧记录
      ok = await _table.updateContent(newContent, _cacheKey,expires: _dataExpires);
      if (ok) {
        contents[0] = newContent;
      }
    }else if(contents.isNotEmpty){
      // 存在重复记录，先清理
      ok = await _table.clearContents(_cacheKey);
      if (ok) {
        contents.clear();
      } else {
        assert(false, 'failed to clear contents: $_cacheKey');
        return false;
      }
    }
    // 插入新纪录
    ok = await _table.addContent(newContent, _cacheKey,expires: _dataExpires);
    if (ok) {
      contents.add(newContent);
    }
    return ok;
  }
}

/// 自定义信息缓存管理器：实现AppCustomizedInfoDBI接口，提供自定义信息的缓存操作
class CustomizedInfoCache extends DataCache<String, List<Mapper>> implements AppCustomizedInfoDBI{
  /// 构造方法：初始化缓存池（名称为'app_info'）
  CustomizedInfoCache() : super('app_info');

  /// 自定义信息表处理器实例
  final _CustomizedInfoTable _table = _CustomizedInfoTable();

  /// 创建新的自定义信息数据访问任务
  /// [key] 自定义信息key
  /// [newContent] 新的自定义信息（可选）
  /// [expires] 过期时间（可选）
  /// 返回自定义信息任务实例
  _CustomizedTask _newTask(String key, {Mapper? newContent, Duration? expires}) =>
      _CustomizedTask(mutexLock, cachePool, _table, key, newContent: newContent, expires: expires);

  /// 获取指定key的自定义信息
  /// [key] 自定义信息key
  /// [mod] 模块名（可选，用于过滤）
  /// 返回自定义信息（null表示无数据）
  @override
  Future<Mapper?> getAppCustomizedInfo(String key, {String? mod}) async{
    var task = _newTask(key);
    List<Mapper>? array = await task.load();
    if (array == null || array.isEmpty) {
      // 无数据
      return null;
    } else if (mod == null || mod.isEmpty) {
      // 无模块过滤，返回第一条
      return array.first;
    }
    // 按模块名过滤
    for (Mapper content in array) {
      if (content['mod'] == mod) {
        return content;
      }
      logError('content not match: $key -> $mod, $content');
    }
    // 无匹配模块的数据
    return null;
  }

  /// 保存自定义信息
  /// [content] 自定义信息内容
  /// [key] 自定义信息key
  /// [expires] 过期时间（可选）
  /// 返回操作是否成功
  @override
  Future<bool> saveAppCustomizedInfo(Mapper content, String key, {Duration? expires}) async {
    //
    //  1. 检查旧记录
    //
    var task = _newTask(key);
    List<Mapper>? array = await task.load();
    if (array == null) {
      array = [];
    } else {
      // 检查时间：新记录时间不能早于旧记录
      DateTime? newTime = content.getDateTime('time');
      if (newTime != null) {
        DateTime? oldTime;
        for (Mapper item in array) {
          oldTime = item.getDateTime('time');
          if (oldTime != null && oldTime.isAfter(newTime)) {
            logWarning('ignore expired info: $content');
            return false;
          }
        }
      }
    }
    //
    //  2. 保存新记录
    //
    task = _newTask(key, newContent: content, expires: expires);
    bool ok = await task.save(array);
    if (!ok) {
      logError('failed to save content: $key -> $content');
      return false;
    }
    //
    //  3. 发送自定义信息更新通知
    //
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kCustomizedInfoUpdated, this, {
      'key': key,
      'info': content,
    });
    return true;
  }

  /// 清理过期的自定义信息
  /// 返回操作是否成功
  @override
  Future<bool> clearExpiredAppCustomizedInfo() async {
    bool ok;
    // 加锁保证并发安全
    await mutexLock.acquire();
    try {
      // 清理数据库过期记录
      ok = await _table.clearExpiredContents();
      if (ok) {
        // 清理缓存
        cachePool.purge();
      }
    } finally {
      // 解锁
      mutexLock.release();
    }
    return ok;
  }
}