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
///  存储服务提供商(SP)和中继站(Station)信息
///
///     文件路径: '/data/data/chat.dim.sechat/databases/sp.db'
///

/// 服务提供商数据库连接器
/// 负责创建和升级sp.db数据库及相关表
class ServiceProviderDatabase extends DatabaseConnector {
  /// 构造函数：初始化数据库名称、版本，定义创建和升级逻辑
  ServiceProviderDatabase() : super(name: dbName, version: dbVersion,
      onCreate: (db, version) {
        // 创建服务提供商表
        DatabaseConnector.createTable(db, tProvider, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT", // 自增主键
          "pid VARCHAR(64) NOT NULL UNIQUE",      // 提供商ID（唯一）
          "chosen INTEGER",                       // 选中标记（优先级）
        ]);
        // 创建中继站表
        DatabaseConnector.createTable(db, tStation, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT", // 自增主键
          "pid VARCHAR(64) NOT NULL",    // 所属提供商ID
          "host VARCHAR(128) NOT NULL",  // 中继站IP/域名
          "port INTEGER NOT NULL",       // 中继站端口
          "chosen INTEGER",              // 选中标记（优先级）
        ]);
        // 为中继站表创建pid索引
        DatabaseConnector.createIndex(db, tStation,
            name: 'sp_id_index', fields: ['pid']);
        // 创建速度测试表
        _createSpeedTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) {
        // 版本升级逻辑：旧版本<3时添加socket字段
        if (oldVersion < 3) {
          DatabaseConnector.addColumn(db, tSpeed, name: 'socket', type: 'VARCHAR(32)');
        }
        // ALTER TABLE t_speed ADD COLUMN socket VARCHAR(32),  // '255.255.255.255:65535'
      });

  /// 创建速度测试表
  /// [db]: 数据库实例
  static void _createSpeedTable(Database db) {
    DatabaseConnector.createTable(db, tSpeed, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT", // 自增主键
      "host VARCHAR(128) NOT NULL",  // 中继站IP/域名
      "port INTEGER NOT NULL",       // 中继站端口
      "sid VARCHAR(64) NOT NULL",    // 中继站ID
      "time INTEGER NOT NULL",       // 最后测试时间（秒）
      "duration REAL NOT NULL",      // 响应时间（秒）
      "socket VARCHAR(32)",          // socket地址（IP:端口）
    ]);
    // 为速度表创建host索引
    DatabaseConnector.createIndex(db, tSpeed,
        name: 'ip_index', fields: ['host']);
  }

  /// 数据库名称
  static const String dbName = 'sp.db';
  /// 数据库版本
  static const int dbVersion = 3;

  /// 服务提供商表名
  static const String tProvider = 't_provider';
  /// 中继站表名
  static const String tStation  = 't_station';
  /// 速度测试表名
  static const String tSpeed    = 't_speed';

}

/// 从查询结果集中提取服务提供商信息
/// [resultSet]: SQL查询结果集
/// [index]: 结果集索引（此处未使用）
/// 返回解析后的ProviderInfo对象
ProviderInfo _extractProvider(ResultSet resultSet, int index) {
  String? sp = resultSet.getString('pid');       // 获取提供商ID
  int? chosen = resultSet.getInt('chosen');      // 获取选中标记
  return ProviderInfo(ID.parse(sp)!, chosen!);  // 构建ProviderInfo对象
}

/// 服务提供商数据表处理器
/// 负责服务提供商的数据库CRUD操作，泛型为ProviderInfo
class _ProviderTable extends DataTableHandler<ProviderInfo> {
  /// 构造函数：初始化数据库连接器和数据提取方法
  _ProviderTable() : super(ServiceProviderDatabase(), _extractProvider);

  /// 数据表名称
  static const String _table = ServiceProviderDatabase.tProvider;
  /// 查询字段：pid和chosen
  static const List<String> _selectColumns = ["pid", "chosen"];
  /// 插入字段：pid和chosen
  static const List<String> _insertColumns = ["pid", "chosen"];

  /// 加载所有服务提供商列表
  /// 返回按chosen降序排列的ProviderInfo列表
  Future<List<ProviderInfo>> loadProviders() async {
    SQLConditions cond = SQLConditions.kTrue; // 条件：所有记录
    return await select(_table, distinct: true, columns: _selectColumns,
        conditions: cond, orderBy: 'chosen DESC'); // 按选中标记降序排列
  }

  /// 添加新的服务提供商
  /// [identifier]: 提供商ID
  /// [chosen]: 选中标记（优先级）
  /// 返回是否添加成功
  Future<bool> addProvider(ID identifier, int chosen) async {
    // 准备插入数据
    List values = [
      identifier.toString(),
      chosen,
    ];
    // 执行插入操作，返回值<=0表示失败
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      logError('failed to add service provider: $identifier -> $chosen');
      return false;
    }
    return true;
  }

  /// 更新服务提供商的选中标记
  /// [identifier]: 提供商ID
  /// [chosen]: 新的选中标记
  /// 返回是否更新成功
  Future<bool> updateProvider(ID identifier, int chosen) async {
    // 准备更新的字段和值
    Map<String, dynamic> values = {
      'chosen': chosen,
    };
    // 构建更新条件：pid等于目标提供商ID
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: identifier.toString());
    // 执行更新操作，返回值<1表示无记录更新
    if (await update(_table, values: values, conditions: cond) < 1) {
      logError('failed to update service provider: $identifier -> $chosen');
      return false;
    }
    return true;
  }

  /// 移除服务提供商
  /// [identifier]: 要移除的提供商ID
  /// 返回是否移除成功
  Future<bool> removeProvider(ID identifier) async {
    // 构建删除条件：pid等于目标提供商ID
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: identifier.toString());
    // 执行删除操作，返回值<0表示失败
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove service provider: $identifier');
      return false;
    }
    return true;
  }

}

/// 服务提供商数据库操作任务
/// 封装服务提供商的读写操作，支持缓存和并发控制
/// 泛型参数：缓存键类型String，数据类型List<ProviderInfo>
class _SpTask extends DbTask<String, List<ProviderInfo>> {
  /// 构造函数
  /// [mutexLock]: 互斥锁（父类参数）
  /// [cachePool]: 缓存池（父类参数）
  /// [_table]: 服务提供商数据表处理器
  /// [append]: 要添加的提供商（可选）
  /// [update]: 要更新的提供商（可选）
  /// [remove]: 要移除的提供商（可选）
  _SpTask(super.mutexLock, super.cachePool, this._table, {
    required ProviderInfo? append,
    required ProviderInfo? update,
    required ProviderInfo? remove,
  }) : _append = append, _update = update, _remove = remove;

  /// 要添加的服务提供商
  final ProviderInfo? _append;
  /// 要更新的服务提供商
  final ProviderInfo? _update;
  /// 要移除的服务提供商
  final ProviderInfo? _remove;

  /// 服务提供商数据表处理器实例
  final _ProviderTable _table;

  /// 获取缓存键（固定字符串）
  @override
  String get cacheKey => 'service_providers';

  /// 从数据库读取服务提供商列表
  @override
  Future<List<ProviderInfo>?> readData() async {
    return await _table.loadProviders();
  }

  /// 向数据库写入服务提供商数据
  /// [providers]: 当前的服务提供商列表
  /// 返回是否成功执行写入操作
  @override
  Future<bool> writeData(List<ProviderInfo> providers) async {
    // 1. 添加新提供商
    bool ok1 = false;
    ProviderInfo? append = _append;
    if (append != null) {
      ok1 = await _table.addProvider(append.identifier, append.chosen);
      if (ok1) {
        providers.add(append); // 同步更新内存中的列表
      }
    }
    // 2. 更新提供商
    bool ok2 = false;
    ProviderInfo? update = _update;
    if (update != null) {
      ok2 = await _table.updateProvider(update.identifier, update.chosen);
      // if (ok2) {
      //   // clear to reload
      //   cachePool.erase(cacheKey);
      // }
    }
    // 3. 移除提供商
    bool ok3 = false;
    ProviderInfo? remove = _remove;
    if (remove != null) {
      ok3 = await _table.removeProvider(remove.identifier);
      if (ok3) {
        // 从内存列表中移除对应提供商
        providers.removeWhere((sp) => sp.identifier == remove.identifier);
      }
    }
    // 只要有一个操作成功就返回true
    return ok1 || ok2 || ok3;
  }

}

/// 服务提供商缓存管理器
/// 实现ProviderDBI接口，提供服务提供商的缓存和数据库操作封装
class ProviderCache extends DataCache<String, List<ProviderInfo>> implements ProviderDBI {
  /// 构造函数：初始化缓存名称
  ProviderCache() : super('service_providers');

  /// 服务提供商数据表处理器实例
  final _ProviderTable _table = _ProviderTable();

  /// 创建新的服务提供商操作任务
  /// [append]: 要添加的提供商（可选）
  /// [update]: 要更新的提供商（可选）
  /// [remove]: 要移除的提供商（可选）
  /// 返回新的任务实例
  _SpTask _newTask({ProviderInfo? append, ProviderInfo? update, ProviderInfo? remove}) =>
      _SpTask(mutexLock, cachePool, _table,
          append: append,
          update: update,
          remove: remove,
      );

  /// 在提供商列表中查找指定ID的提供商
  /// [identifier]: 要查找的提供商ID
  /// [providers]: 提供商列表
  /// 返回找到的ProviderInfo或null
  static ProviderInfo? _find(ID identifier, List<ProviderInfo> providers) {
    for (ProviderInfo item in providers) {
      if (item.identifier == identifier) {
        return item;
      }
    }
    return null;
  }

  /// 获取所有服务提供商列表
  /// 返回ProviderInfo列表（空列表表示无提供商）
  @override
  Future<List<ProviderInfo>> allProviders() async {
    var task = _newTask();
    var providers = await task.load(); // 从缓存/数据库加载数据
    return providers ?? []; // 空值处理为空列表
  }

  /// 添加服务提供商
  /// [identifier]: 提供商ID
  /// [chosen]: 选中标记（默认0）
  /// 返回是否添加成功
  @override
  Future<bool> addProvider(ID identifier, {int chosen = 0}) async {
    var task = _newTask();
    var providers = await task.load(); // 加载当前提供商列表
    providers ??= []; // 空值处理为空列表

    // 1. 检查是否已存在
    if (_find(identifier, providers) != null) {
      assert(false, 'duplicated provider: $identifier, chosen: $chosen'); // 断言重复
      return await updateProvider(identifier, chosen: chosen); // 已存在则执行更新
    }
    // 2. 添加新提供商
    var info = ProviderInfo(identifier, chosen);
    task = _newTask(append: info);
    bool ok = await task.save(providers); // 执行添加操作
    if (!ok) {
      logError('failed to add provider: $identifier, chosen: $chosen');
      return false;
    }
    // 3. 发送提供商更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kServiceProviderUpdated, this, {
      'action': 'add',
      'ID': identifier,
      'chosen': chosen,
    });
    return true;
  }

  /// 更新服务提供商的选中标记
  /// [identifier]: 提供商ID
  /// [chosen]: 新的选中标记（默认0）
  /// 返回是否更新成功
  @override
  Future<bool> updateProvider(ID identifier, {int chosen = 0}) async {
    var task = _newTask();
    var providers = await task.load(); // 加载当前提供商列表
    providers ??= []; // 空值处理为空列表

    // 1. 检查是否存在
    var info = _find(identifier, providers);
    if (info == null) {
      assert(false, 'provider not found: $identifier, chosen: $chosen'); // 断言未找到
      return false;
    }
    // 2. 更新选中标记
    info.chosen = chosen;
    // var info = ProviderInfo(identifier, chosen);
    task = _newTask(update: info);
    bool ok = await task.save(providers); // 执行更新操作
    if (!ok) {
      logError('failed to update provider: $identifier, chosen: $chosen');
      return false;
    }
    // 3. 发送提供商更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kServiceProviderUpdated, this, {
      'action': 'update',
      'ID': identifier,
      'chosen': chosen,
    });
    return true;
  }

  /// 移除服务提供商
  /// [identifier]: 要移除的提供商ID
  /// 返回是否移除成功
  @override
  Future<bool> removeProvider(ID identifier) async {
    var task = _newTask();
    var providers = await task.load(); // 加载当前提供商列表
    providers ??= []; // 空值处理为空列表

    // 1. 检查是否存在
    if (_find(identifier, providers) == null) {
      assert(false, 'provider not found: $identifier'); // 断言未找到
      return true; // 不存在则直接返回成功
    }
    // 2. 移除提供商
    var info = ProviderInfo(identifier, 0);
    task = _newTask(remove: info);
    bool ok = await task.save(providers); // 执行移除操作
    if (!ok) {
      logError('failed to remove provider: $identifier');
      return false;
    }
    // 3. 发送提供商更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kServiceProviderUpdated, this, {
      'action': 'remove',
      'ID': identifier,
    });
    return true;
  }

}