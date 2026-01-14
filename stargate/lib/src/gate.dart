/* license: https://mit-license.org
 *
 *  ObjectKey : Object & Key kits
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

import 'dart:typed_data';

import 'package:stargate/startrek.dart';
import 'package:stargate/websocket.dart';

/// 带Hub的网关抽象类（核心：连接管理入口）
/// 泛型H：Hub类型（连接管理器）
/// 核心职责：
/// 1. 定义网关的核心接口（获取Porter、发送响应、心跳检测）；
/// 2. 关联Hub，实现连接的统一管理；
abstract class CommonGate<H extends Hub> extends StarGate {
  CommonGate();

  /// 连接管理器（Hub）
  H? hub;

  /// 获取Porter（搬运工：数据收发器）
  /// [remote] - 远程地址
  /// [local] - 本地地址
  Future<Porter?> fetchPorter({
    required SocketAddress remote,
    SocketAddress? local,
  }) async {
    // 从Hub获取连接
    Connection? conn = await hub?.connect(remote: remote, local: local);
    if (conn == null) {
      // 获取失败 → 断言错误
      assert(false, 'failed to get connection: $local -> $remote');
      return null;
    }
    // 连接成功 → 获取Porter
    return await dock(conn, true);
  }

  /// 发送响应数据
  /// [payload] - 响应数据
  /// [ship] - 入站数据包
  /// [remote] - 远程地址
  /// [local] - 本地地址
  Future<bool> sendResponse(
    Uint8List payload,
    Arrival ship, {
    required SocketAddress remote,
    SocketAddress? local,
  }) async {
    // 断言：ship必须是PlainArrival类型
    assert(ship is PlainArrival, 'arrival ship error: $ship');
    // 获取Porter
    Porter? docker = getPorter(remote: remote, local: local);
    if (docker == null) {
      // Porter未找到 → 断言错误
      assert(false, 'docker not found: $local -> $remote');
      return false;
    } else if (!docker.isAlive) {
      // Porter未激活 → 断言错误
      assert(false, 'docker not alive: $local -> $remote');
      return false;
    }
    // 发送数据
    return await docker.sendData(payload);
  }

  //
  //  保持活跃（心跳检测）
  //

  /// 心跳检测（重写父类方法）
  /// 核心：仅对ActiveConnection执行心跳
  @override
  Future<void> heartbeat(Connection connection) async {
    if (connection is ActiveConnection) {
      await super.heartbeat(connection);
    }
  }
}
