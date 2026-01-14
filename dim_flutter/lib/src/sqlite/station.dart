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

import 'service.dart';

/// 从查询结果集中提取中继站信息
/// [resultSet]: SQL查询结果集
/// [index]: 结果集索引（此处未使用）
/// 返回解析后的StationInfo对象
StationInfo _extractStation(ResultSet resultSet, int index) {
  String? host = resultSet.getString('host');       // 获取中继站主机地址
  int? port = resultSet.getInt('port');             // 获取中继站端口
  String? sp = resultSet.getString('pid');          // 获取所属提供商ID
  int? chosen = resultSet.getInt('chosen');         // 获取选中标记
  ID? provider = ID.parse(sp);                      // 解析提供商ID
  // 构建StationInfo对象
  return StationInfo(null, chosen!, host: host!, port: port!, provider: provider);
}

/// 中继站数据表处理器
/// 负责中继站的数据库CRUD操作，泛型为StationInfo
class _StationTable extends DataTableHandler<StationInfo> {
  /// 构造函数：初始化数据库连接器和数据提取方法
  _StationTable() : super(ServiceProviderDatabase(), _extractStation);

  /// 数据表名称
  static const String _table = ServiceProviderDatabase.tStation;
  /// 查询字段：pid、host、port、chosen
  static const List<String> _selectColumns = ["pid", "host", "port", "chosen"];
  /// 插入字段：pid、host、port、chosen
  static const List<String> _insertColumns = ["pid", "host", "port", "chosen"];

  /// 加载指定提供商的所有中继站
  /// [provider]: 提供商ID（必填）
  /// 返回按chosen降序排列的StationInfo列表
  Future<List<StationInfo>> loadStations({required ID provider}) async {
    // 构建查询条件：pid等于目标提供商ID
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: provider.toString());
    // 执行查询：去重，按选中标记降序排列
    return await select(_table, distinct: true, columns: _selectColumns,
        conditions: cond, orderBy: 'chosen DESC');
  }

  /// 添加中继站
  /// [sid]: 中继站ID（可选）
  /// [chosen]: 选中标记（默认0）
  /// [host]: 中继站主机地址（必填）
  /// [port]: 中继站端口（必填）
  /// [provider]: 所属提供商ID（必填）
  /// 返回是否添加成功
  Future<bool> addStation(ID? sid, {
    int chosen = 0,
    required String host, required int port, required ID provider
  }) async {
    // 准备插入数据
    List values = [
      provider.toString(),
      host,
      port,
      chosen,
    ];
    // 执行插入操作，返回值<=0表示失败
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      logError('failed to add station: $sid, $host:$port, provider: $provider -> $chosen');
      return false;
    }
    return true;
  }

  /// 更新中继站的选中标记
  /// [sid]: 中继站ID（可选）
  /// [chosen]: 新的选中标记（默认0）
  /// [host]: 中继站主机地址（必填）
  /// [port]: 中继站端口（必填）
  /// [provider]: 所属提供商ID（必填）
  /// 返回是否更新成功
  Future<bool> updateStation(ID? sid, {
    int chosen = 0,
    required String host, required int port, required ID provider
  }) async {
    // 构建更新条件：pid=提供商ID 且 host=主机地址 且 port=端口
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: provider.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'host', comparison: '=', right: host);
    cond.addCondition(SQLConditions.kAnd, left: 'port', comparison: '=', right: port);
    // 准备更新的字段和值
    Map<String, dynamic> values = {
      'chosen': chosen,
    };
    if (sid == null || sid.isBroadcast) {} else {
      // TODO: save station ID? （待实现：保存中继站ID）
    }
    // 执行更新操作，返回值<1表示无记录更新
    if (await update(_table, values: values, conditions: cond) < 1) {
      logError('failed to update station: $sid, $host:$port, provider: $provider -> $chosen');
      return false;
    }
    return true;
  }

  /// 移除指定的中继站
  /// [host]: 中继站主机地址（必填）
  /// [port]: 中继站端口（必填）
  /// [provider]: 所属提供商ID（必填）
  /// 返回是否移除成功
  Future<bool> removeStation({required String host, required int port, required ID provider}) async {
    // 构建删除条件：pid=提供商ID 且 host=主机地址 且 port=端口
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: provider.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'host', comparison: '=', right: host);
    cond.addCondition(SQLConditions.kAnd, left: 'port', comparison: '=', right: port);
    // 执行删除操作，返回值<0表示失败
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove station: $host:$port, provider: $provider');
      return false;
    }
    return true;
  }

  /// 移除指定提供商的所有中继站
  /// [provider]: 提供商ID（必填）
  /// 返回是否移除成功
  Future<bool> removeStations({required ID provider}) async {
    // 构建删除条件：pid等于目标提供商ID
    SQLConditions cond;
    cond = SQLConditions(left: 'pid', comparison: '=', right: provider.toString());
    // 执行删除操作，返回值<0表示失败
    if (await delete(_table, conditions: cond) < 0) {
      logError('failed to remove stations of provider: $provider');
      return false;
    }
    return true;
  }

}

/// 中继站数据库操作任务
/// 封装中继站的读写操作，支持缓存和并发控制
/// 泛型参数：缓存键类型ID，数据类型List<StationInfo>
class _SrvTask extends DbTask<ID, List<StationInfo>> {
  /// 构造函数
  /// [mutexLock]: 互斥锁（父类参数）
  /// [cachePool]: 缓存池（父类参数）
  /// [_table]: 中继站数据表处理器
  /// [_provider]: 所属提供商ID
  /// [append]: 要添加的中继站（可选）
  /// [update]: 要更新的中继站（可选）
  /// [remove]: 要移除的中继站（可选）
  _SrvTask(super.mutexLock, super.cachePool, this._table, this._provider, {
    required StationInfo? append,
    required StationInfo? update,
    required StationInfo? remove,
  }) : _append = append, _update = update, _remove = remove;

  /// 所属提供商ID
  final ID _provider;
  /// 要添加的中继站
  final StationInfo? _append;
  /// 要更新的中继站
  final StationInfo? _update;
  /// 要移除的中继站
  final StationInfo? _remove;

  /// 中继站数据表处理器实例
  final _StationTable _table;

  /// 获取缓存键（提供商ID）
  @override
  ID get cacheKey => _provider;

  /// 从数据库读取中继站列表
  @override
  Future<List<StationInfo>?> readData() async {
    return await _table.loadStations(provider: _provider);
  }

  /// 向数据库写入中继站数据
  /// [stations]: 当前的中继站列表
  /// 返回是否成功执行写入操作
  @override
  Future<bool> writeData(List<StationInfo> stations) async {
    // 1. 添加中继站
    bool ok1 = false;
    StationInfo? append = _append;
    if (append != null) {
      ok1 = await _table.addStation(append.identifier,
        chosen: append.chosen,
        host: append.host,
        port: append.port,
        provider: _provider,
      );
      if (ok1) {
        stations.add(append); // 同步更新内存中的列表
      }
    }
    // 2. 更新中继站
    bool ok2 = false;
    StationInfo? update = _update;
    if (update != null) {
      ok2 = await _table.updateStation(update.identifier,
        chosen: update.chosen,
        host: update.host,
        port: update.port,
        provider: _provider,
      );
      // if (ok2) {
      //   // clear to reload
      //   cachePool.erase(cacheKey);
      // }
    }
    // 3. 移除中继站
    bool ok3 = false;
    StationInfo? remove = _remove;
    if (remove != null) {
      ok3 = await _table.removeStation(
        host: remove.host,
        port: remove.port,
        provider: _provider,
      );
      if (ok3) {
        // 从内存列表中移除对应中继站
        stations.removeWhere((srv) => srv.port == remove.port && srv.host == remove.host);
      }
    }
    // 只要有一个操作成功就返回true
    return ok1 || ok2 || ok3;
  }

}

/// 中继站缓存管理器
/// 实现StationDBI接口，提供中继站的缓存和数据库操作封装
class StationCache extends DataCache<ID, List<StationInfo>> implements StationDBI {
  /// 构造函数：初始化缓存名称
  StationCache() : super('relay_stations');

  /// 中继站数据表处理器实例
  final _StationTable _table = _StationTable();

  /// 创建新的中继站操作任务
  /// [sp]: 所属提供商ID
  /// [append]: 要添加的中继站（可选）
  /// [update]: 要更新的中继站（可选）
  /// [remove]: 要移除的中继站（可选）
  /// 返回新的任务实例
  _SrvTask _newTask(ID sp, {StationInfo? append, StationInfo? update, StationInfo? remove}) =>
      _SrvTask(mutexLock, cachePool, _table, sp,
          append: append,
          update: update,
          remove: remove,
      );

  /// 在中继站列表中查找指定主机和端口的中继站
  /// [host]: 主机地址
  /// [port]: 端口
  /// [stations]: 中继站列表
  /// 返回找到的StationInfo或null
  static StationInfo? _find(String host, int port, List<StationInfo> stations) {
    for (StationInfo item in stations) {
      if (item.host == host && item.port == port) {
        return item;
      }
    }
    return null;
  }

  /// 获取指定提供商的所有中继站
  /// [provider]: 提供商ID（必填）
  /// 返回StationInfo列表（空列表表示无中继站）
  @override
  Future<List<StationInfo>> allStations({required ID provider}) async {
    var task = _newTask(provider);
    var providers = await task.load(); // 从缓存/数据库加载数据
    return providers ?? []; // 空值处理为空列表
  }

  /// 添加中继站
  /// [sid]: 中继站ID（可选）
  /// [chosen]: 选中标记（默认0）
  /// [host]: 主机地址（必填）
  /// [port]: 端口（必填）
  /// [provider]: 所属提供商ID（必填）
  /// 返回是否添加成功
  @override
  Future<bool> addStation(ID? sid, {
    int chosen = 0,
    required String host, required int port, required ID provider
  }) async {
    var task = _newTask(provider);
    var stations = await task.load(); // 加载当前中继站列表
    stations ??= []; // 空值处理为空列表

    // 1. 检查是否已存在
    if (_find(host, port, stations) != null) {
      logWarning('duplicated station: $host, $port, provider: $provider, chosen: $chosen');
      // 已存在则执行更新
      return await updateStation(sid, chosen: chosen, host: host, port: port, provider: provider);
    }
    // 2. 添加新中继站
    var info = StationInfo(sid, chosen, host: host, port: port, provider: provider);
    task = _newTask(provider, append: info);
    bool ok = await task.save(stations); // 执行添加操作

    if (!ok) {
      logError('failed to add station: $host, $port, provider: $provider, chosen: $chosen');
      return false;
    }
    // 3. 发送中继站更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kStationsUpdated, this, {
      'action': 'add',
      'host': host,
      'port': port,
      'provider': provider,
      'chosen': chosen,
    });
    return true;
  }

  /// 更新中继站的选中标记
  /// [sid]: 中继站ID（可选）
  /// [chosen]: 新的选中标记（默认0）
  /// [host]: 主机地址（必填）
  /// [port]: 端口（必填）
  /// [provider]: 所属提供商ID（必填）
  /// 返回是否更新成功
  @override
  Future<bool> updateStation(ID? sid, {
    int chosen = 0,
    required String host, required int port, required ID provider
  }) async {
    var task = _newTask(provider);
    var stations = await task.load(); // 加载当前中继站列表
    stations ??= []; // 空值处理为空列表

    // 1. 检查是否存在
    var info = _find(host, port, stations);
    if (info == null) {
      logWarning('station not found: $host, $port, provider: $provider, chosen: $chosen');
      return false;
    }
    // 2. 更新选中标记
    info.chosen = chosen;
    // var info = StationInfo(sid, chosen, host: host, port: port, provider: provider);
    task = _newTask(provider, update: info);
    bool ok = await task.save(stations); // 执行更新操作
    if (!ok) {
      logError('failed to update station: $host, $port, provider: $provider, chosen: $chosen');
      return false;
    }
    // 3. 发送中继站更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kStationsUpdated, this, {
      'action': 'update',
      'host': host,
      'port': port,
      'provider': provider,
      'chosen': chosen,
    });
    return true;
  }

  /// 移除指定的中继站
  /// [host]: 主机地址（必填）
  /// [port]: 端口（必填）
  /// [provider]: 所属提供商ID（必填）
  /// 返回是否移除成功
  @override
  Future<bool> removeStation({
    required String host, required int port, required ID provider
  }) async {
    var task = _newTask(provider);
    var stations = await task.load(); // 加载当前中继站列表
    stations ??= []; // 空值处理为空列表

    // 1. 检查是否存在
    if (_find(host, port, stations) == null) {
      logWarning('station not found: $host, $port, provider: $provider');
      return true; // 不存在则直接返回成功
    }
    // 2. 移除中继站
    var info = StationInfo(Station.ANY, 0, host: host, port: port, provider: provider);
    task = _newTask(provider, remove: info);
    bool ok = await task.save(stations); // 执行移除操作
    if (!ok) {
      logError('failed to remove station: $host, $port, provider: $provider');
      return false;
    }
    // 3. 发送中继站更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kStationsUpdated, this, {
      'action': 'remove',
      'host': host,
      'port': port,
      'provider': provider,
    });
    return true;
  }

  /// 移除指定提供商的所有中继站
  /// [provider]: 提供商ID（必填）
  /// 返回是否移除成功
  @override
  Future<bool> removeStations({required ID provider}) async {
    bool ok;
    await mutexLock.acquire(); // 获取互斥锁
    try {
      ok = await _table.removeStations(provider: provider); // 执行批量删除
      if (ok) {
        cachePool.purge(); // 清空缓存
      }
    } finally {
      mutexLock.release(); // 释放互斥锁
    }
    if (!ok) {
      logError('failed to remove stations for provider: $provider');
      return false;
    }
    // 3. 发送中继站更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kStationsUpdated, this, {
      'action': 'removeAll',
      'provider': provider,
    });
    return true;
  }

}