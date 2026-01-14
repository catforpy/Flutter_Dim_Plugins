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

import 'entity.dart';


/// 从数据库结果集中提取元数据对象
/// [resultSet] 数据库查询结果集
/// [index] 行索引
/// 返回元数据对象
Meta _extractMeta(ResultSet resultSet, int index) {
  int? type = resultSet.getInt('type');         // 元数据类型/版本
  String? json = resultSet.getString('pub_key');// 公钥（JSON字符串）
  Map? key = JSON.decode(json!);               // 解析公钥

  // 构建元数据信息
  Map info = {
    'version': type,
    'type': type,
    'key': key,
  };
  // 包含种子的版本添加种子和指纹
  if (MetaVersion.hasSeed(type!)) {
    info['seed'] = resultSet.getString('seed');
    info['fingerprint'] = resultSet.getString('fingerprint');
  }
  // 解析为元数据对象
  return Meta.parse(info)!;
}

/// 元数据数据表处理器：封装元数据表的增删改查操作
class _MetaTable extends DataTableHandler<Meta> {
  /// 构造方法：初始化数据库连接器和结果集提取器
  _MetaTable() : super(EntityDatabase(), _extractMeta);

  /// 元数据表名
  static const String _table = EntityDatabase.tMeta;
  /// 查询列名列表
  static const List<String> _selectColumns = ["type", "pub_key", "seed", "fingerprint"];
  /// 插入列名列表
  static const List<String> _insertColumns = ["did", "type", "pub_key", "seed", "fingerprint"];

  /// 加载指定实体的元数据
  /// [entity] 实体ID
  /// 返回元数据对象（null表示无）
  Future<Meta?> loadMeta(ID entity) async {
    // 构建查询条件：实体ID匹配
    SQLConditions cond;
    cond = SQLConditions(left: 'did', comparison: '=', right: entity.toString());
    // 查询最新的一条
    List<Meta> array = await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'id DESC', limit: 1);
    // 返回第一条记录
    return array.isEmpty ? null : array.first;
  }

  /// 保存元数据
  /// [meta] 元数据对象
  /// [entity] 实体ID
  /// 返回操作是否成功
  Future<bool> saveMeta(Meta meta, ID entity) async {
    // 获取元数据版本/类型
    int type = MetaVersion.parseInt(meta.type, 0);
    // 序列化公钥为JSON字符串
    String json = JSON.encode(meta.publicKey.toMap());
    // 处理种子和指纹
    String seed;
    String fingerprint;
    if (MetaVersion.hasSeed(type)) {
      seed = meta.seed!;
      fingerprint = meta.getString('fingerprint') ?? '';
    } else {
      seed = '';
      fingerprint = '';
    }
    // 构建插入值列表
    List values = [entity.toString(), type, json, seed, fingerprint];
    // 执行插入操作
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

}

/// 元数据数据访问任务：封装带缓存的元数据读写操作
class _MetaTask extends DbTask<ID, Meta> {
  /// 构造方法
  /// [mutexLock] 互斥锁
  /// [cachePool] 缓存池
  /// [_table] 元数据表处理器
  /// [_entity] 实体ID
  _MetaTask(super.mutexLock, super.cachePool, this._table, this._entity)
      : super(cacheExpires: 36000, cacheRefresh: 128);

  /// 实体ID（缓存键）
  final ID _entity;
  /// 元数据表处理器
  final _MetaTable _table;

  /// 缓存键（实体ID）
  @override
  ID get cacheKey => _entity;

  /// 从数据库读取元数据
  @override
  Future<Meta?> readData() async => await _table.loadMeta(_entity);

  /// 写入元数据到数据库
  @override
  Future<bool> writeData(Meta meta) async => await _table.saveMeta(meta, _entity);

}

/// 元数据缓存管理器：实现MetaDBI接口，提供元数据的缓存操作
class MetaCache extends DataCache<ID, Meta> implements MetaDBI {
  /// 构造方法：初始化缓存池（名称为'meta'）
  MetaCache() : super('meta');

  /// 元数据表处理器实例
  final _MetaTable _table = _MetaTable();

  /// 创建新的元数据数据访问任务
  /// [entity] 实体ID
  /// 返回元数据任务实例
  _MetaTask _newTask(ID entity) => _MetaTask(mutexLock, cachePool, _table, entity);

  /// 获取指定实体的元数据
  /// [entity] 实体ID
  /// 返回元数据对象（null表示无）
  @override
  Future<Meta?> getMeta(ID entity) async {
    var task = _newTask(entity);
    return await task.load();
  }

  /// 保存元数据（带验证、缓存和通知）
  /// [meta] 元数据对象
  /// [entity] 实体ID
  /// 返回操作是否成功
  @override
  Future<bool> saveMeta(Meta meta, ID entity) async {
    // 0. 验证元数据有效性
    if (!checkMeta(meta, entity)) {
      logError('meta not match: $entity');
      return false;
    }
    // 1. 检查旧记录
    Meta? old = await getMeta(entity);
    if (old != null) {
      // 元数据不会变更，无需更新
      logWarning('meta exists: $entity');
      return true;
    }
    // 2. 保存到数据库
    var task = _newTask(entity);
    var ok = await task.save(meta);
    if (!ok) {
      logError('failed to save meta: $entity');
      return false;
    }
    // 3. 发送元数据保存通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kMetaSaved, this, {
      'ID': entity,
      'meta': meta,
    });
    return true;
  }

  /// 验证元数据与实体ID是否匹配
  /// [meta] 元数据对象
  /// [identifier] 实体ID
  /// 返回验证结果
  bool checkMeta(Meta meta, ID identifier) {
    return meta.isValid && MetaUtils.matchIdentifier(identifier, meta);
  }

}