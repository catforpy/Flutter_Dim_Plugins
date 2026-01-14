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

import 'package:dim_client/common.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/sqlite.dart';

import '../common/dbi/network.dart';

import 'helper/handler.dart';
import 'service.dart';

/// 从查询结果集中提取速度测试记录
/// [resultSet]: SQL查询结果集
/// [index]: 结果集索引（此处未使用）
/// 返回解析后的SpeedRecord对象
SpeedRecord _extractSpeed(ResultSet resultSet, int index) {
  String? host = resultSet.getString('host');         // 获取中继站主机地址
  int? port = resultSet.getInt('port');               // 获取中继站端口
  String? sid = resultSet.getString('sid');           // 获取中继站ID
  DateTime? time = resultSet.getDateTime('time');     // 获取测试时间
  double duration = resultSet.getDouble('duration') ?? -1; // 获取响应时长（默认-1）
  String socket = resultSet.getString('socket') ?? ''; // 获取socket地址（默认空）
  // 构建SpeedRecord对象（Triplet/Pair为数据结构封装）
  return Triplet(Pair(host!, port!), ID.parse(sid), Triplet(time!, duration, socket));
}

/// 速度测试记录表处理器
/// 实现SpeedDBI接口，负责速度测试记录的数据库CRUD操作
class SpeedTable extends DataTableHandler<SpeedRecord> implements SpeedDBI {
  /// 构造函数：初始化数据库连接器和数据提取方法
  SpeedTable() : super(ServiceProviderDatabase(), _extractSpeed);

  /// 数据表名称
  static const String _table = ServiceProviderDatabase.tSpeed;
  /// 查询字段：所有速度测试相关字段
  static const List<String> _selectColumns = ["host", "port", "sid", "time", "duration", "socket"];
  /// 插入字段：所有速度测试相关字段
  static const List<String> _insertColumns = ["host", "port", "sid", "time", "duration", "socket"];

  /// 获取指定中继站的速度测试记录
  /// [host]: 中继站主机地址
  /// [port]: 中继站端口
  /// 返回按ID降序排列的SpeedRecord列表
  @override
  Future<List<SpeedRecord>> getSpeeds(String host, int port) async {
    // 构建查询条件：host等于目标主机 且 port等于目标端口
    SQLConditions cond;
    cond = SQLConditions(left: 'host', comparison: '=', right: host);
    cond.addCondition(SQLConditions.kAnd,
        left: 'port', comparison: '=', right: port);
    // 执行查询：按ID降序（最新记录在前）
    return await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'id DESC');
  }

  /// 添加速度测试记录
  /// [host]: 中继站主机地址
  /// [port]: 中继站端口
  /// [identifier]: 中继站ID（必填）
  /// [time]: 测试时间（必填）
  /// [duration]: 响应时长（秒，必填）
  /// [socketAddress]: socket地址（可选）
  /// 返回是否添加成功
  @override
  Future<bool> addSpeed(String host, int port,
      {required ID identifier, required DateTime time, required double duration,
        required String? socketAddress}) async {
    // 将时间转换为秒级时间戳
    int seconds = time.millisecondsSinceEpoch ~/ 1000;
    // 准备插入数据
    List values = [host, port, identifier.toString(), seconds, duration, socketAddress];
    // 执行插入操作，返回值>0表示成功
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

  /// 移除过期的速度测试记录
  /// [expired]: 过期时间（可选，默认72小时前）
  /// 返回是否移除成功
  @override
  Future<bool> removeExpiredSpeed(DateTime? expired) async {
    double time;
    if (expired == null) {
      // 默认移除72小时前的记录
      time = TimeUtils.currentTimeSeconds - 72 * 3600;
    } else {
      // 转换为秒级时间戳
      time = expired.millisecondsSinceEpoch / 1000;
    }
    // 构建删除条件：time小于过期时间
    SQLConditions cond;
    cond = SQLConditions(left: 'time', comparison: '<', right: time);
    // 执行删除操作，返回值>=0表示成功
    return await delete(_table, conditions: cond) >= 0;
  }

}