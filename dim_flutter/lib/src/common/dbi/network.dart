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
import 'package:dim_client/plugins.dart';

/// 服务器测速记录类型定义
/// 结构说明：
/// Triplet<
///   Pair<String, int>,       // (服务器地址, 端口)
///   ID?,                     // 服务器ID（可选）
///   Triplet<
///     DateTime,              // 测试时间
///     double,                // 响应时间（毫秒）
///     String                 // 实际连接的Socket地址
///   >
/// >
typedef SpeedRecord = Triplet<Pair<String, int>, ID?, Triplet<DateTime, double, String>>;

/// 服务器测速数据库接口
/// 用于管理服务器测速记录的存储、查询和清理
abstract class SpeedDBI {

  /// 获取指定服务器的所有测速记录
  /// [host] - 服务器地址
  /// [port] - 服务器端口
  /// @return 测速记录列表
  Future<List<SpeedRecord>> getSpeeds(String host, int port);

  /// 添加一条服务器测速记录
  /// [host] - 服务器地址
  /// [port] - 服务器端口
  /// [identifier] - 服务器ID
  /// [time] - 测试时间
  /// [duration] - 响应时间（毫秒）
  /// [socketAddress] - 实际连接的Socket地址
  /// @return 操作成功返回true
  Future<bool> addSpeed(String host, int port,
      {required ID identifier, required DateTime time, required double duration,
        required String? socketAddress});
  
  /// 移除过期的测速记录
  /// [expired] - 过期时间点（null表示移除所有记录）
  /// @return 操作成功返回true
  Future<bool> removeExpiredSpeed(DateTime? expired);
}