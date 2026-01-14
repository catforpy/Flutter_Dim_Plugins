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

import 'dart:io';
import 'dart:typed_data';

import 'package:object_key/object_key.dart';
import 'package:startrek/nio.dart';
import 'package:startrek/pair.dart';
import 'package:startrek/startrek.dart';

/// 连接池（基于地址对的映射）
/// 核心：管理 (remote, local) → Connection 的映射，支持添加/移除/清理连接
class ConnectionPool extends AddressPairMap<Connection> {
  /// 设置连接（覆盖旧连接 + 关闭旧连接）
  @override
  Connection? setItem(
    Connection? value, {
    SocketAddress? remote,
    SocketAddress? local,
  }) {
    // 1. 移除缓存的旧连接
    Connection? cached = super.removeItem(value, remote: remote, local: local);
    // 2. 添加新连接
    Connection? old = super.setItem(value, remote: remote, local: local);
    assert(old == null, 'should not happen');
    return cached;
  }
}

/// 基础枢纽类
/// 核心实现：连接池管理、通道驱动、数据分发，是所有连接/通道的统一调度中心
abstract class BaseHub implements Hub {
  BaseHub() {
    // 初始化连接池
    _connectionPool = createConnectionPool();
  }

  /// 创建连接池(子类可重写，定制连接池逻辑)
  AddressPairMap<Connection> createConnectionPool() => ConnectionPool();

  /// 连接池（(remote, local) → Connection）
  late final AddressPairMap<Connection> _connectionPool;

  /// 枢纽代理弱引用(回调上层事件)
  WeakReference<ConnectionDelegate>? _delegateRef;

  /// 获取枢纽代理
  ConnectionDelegate? get delegate => _delegateRef?.target;

  /// 设置枢纽代理
  set delegate(ConnectionDelegate? gate) =>
      _delegateRef = gate == null ? null : WeakReference(gate);

  /// 最大分段大小（MSS）：适配 MTU，避免数据分片
  /// MTU=1500 - IP头20 - UDP头8 = 1472
  static int MSS = 1472;

  // ====================== 通道管理（子类实现） ======================
  /// 获取所有通道（子类实现：返回 TCP/UDP 通道列表）
  Iterable<Channel> get allChannels;

  /// 移除通道（子类实现：从通道列表中移除 + 清理关联资源）
  Channel? removeChannel(
    Channel? channel, {
    SocketAddress? remote,
    SocketAddress? local,
  });

  // ====================== 连接管理 ======================
  /// 创建连接（子类实现：返回 TCPConnection/UDPConnection）
  Connection createConnection({
    required SocketAddress remote,
    SocketAddress? local,
  });

  /// 获取所有连接（从连接池）
  Iterable<Connection> get allConnections => _connectionPool.items;

  /// 根据地址获取连接
  Connection? getConnection({
    required SocketAddress remote,
    SocketAddress? local,
  }) => _connectionPool.getItem(remote: remote, local: local);

  /// 设置连接（添加到连接池）
  Connection? setConnection(
    Connection conn, {
    required SocketAddress remote,
    SocketAddress? local,
  }) => _connectionPool.setItem(conn, remote: remote, local: local);

  /// 移除连接（从连接池）
  Connection? removeConnection(
    Connection? conn, {
    required SocketAddress remote,
    SocketAddress? local,
  }) => _connectionPool.removeItem(conn, remote: remote, local: local);

  /// 连接远程地址（对外接口：创建/复用连接 + 启动连接）
  @override
  Future<Connection?> connect({
    required SocketAddress remote,
    SocketAddress? local,
  }) async {
    // 1. 检查是否已有连接
    Connection? conn = getConnection(remote: remote, local: local);
    if (conn != null) {
      // 本地地址为空/匹配，复用现有连接
      if (local == null || conn.localAddress == local) {
        return conn;
      }
    }
    // 2. 创建新连接并加入连接池
    conn = createConnection(remote: remote, local: local);
    local ??= conn.localAddress;
    // 移除旧连接并关闭
    var cached = setConnection(conn, remote: remote, local: local);
    if (cached != null && !identical(cached, conn)) {
      await cached.close();
    }
    // 3. 启动新连接（打开通道 + 启动状态机）
    if (conn is BaseConnection) {
      await conn.start(this);
    } else {
      assert(false, 'connection error: $remote, $conn');
    }
    return conn;
  }

  // ====================== 通道驱动 ======================
  /// 关闭通道（安全关闭：捕获异常）
  Future<void> closeChannel(Channel sock) async {
    try {
      if (!sock.isClosed) {
        await sock.close();
      }
    } on IOException catch (_) {
      // 关闭异常不抛错
    }
  }

  /// 驱动单个通道（核心：接收数据 + 分发到对应连接）
  Future<bool> driveChannel(Channel sock) async {
    // 1. 检查通道状态
    ChannelStatus cs = sock.status;
    if (cs == ChannelStatus.init || cs == ChannelStatus.closed) {
      return false;
    }
    Uint8List? data;
    SocketAddress? remote;
    SocketAddress? local;
    // 2. 接收数据
    try {
      Pair<Uint8List?, SocketAddress?> pair = await sock.receive(MSS);
      data = pair.first;
      remote = pair.second;
    } on IOException catch (e) {
      // 接收异常：移除通道 + 回调错误
      remote = sock.remoteAddress;
      local = sock.localAddress;
      Channel? cached = removeChannel(sock, remote: remote, local: local);
      if (cached != null && !identical(cached, sock)) {
        await closeChannel(cached);
      }
      await closeChannel(sock);
      // 回调上层错误
      if (delegate != null && remote != null) {
        Connection? conn = getConnection(remote: remote, local: local);
        await delegate?.onConnectionError(IOError(e), conn!);
      }
      return false;
    }
    // 3. 数据为空，跳过
    if (remote == null || data == null || data.isEmpty) {
      return false;
    }
    local = sock.localAddress;
    // 4. 分发数据到对应连接（无则创建）
    Connection? conn = await connect(remote: remote, local: local);
    if (conn != null) {
      await conn.onReceivedData(data);
    }
    return true;
  }

  /// 驱动所有通道（批量处理）
  Future<int> driveChannels(Iterable<Channel> channels) async {
    int count = 0;
    List<Future<bool>> futures = [];
    for (Channel sock in channels) {
      futures.add(driveChannel(sock));
    }
    // 等待所有通道处理完成
    List<bool> results = await Future.wait(futures);
    for (bool busy in results) {
      if (busy) {
        count += 1;
      }
    }
    return count;
  }

  /// 清理关闭的通道
  Future<void> cleanupChannels(Iterable<Channel> channels) async {
    Channel? cached;
    for (Channel sock in channels) {
      if (sock.isClosed) {
        // 移除关闭的通道
        cached = removeChannel(
          sock,
          remote: sock.remoteAddress,
          local: sock.localAddress,
        );
        if (cached != null && !identical(cached, sock)) {
          await closeChannel(cached);
        }
      }
    }
  }

  /// 驱动所有连接（触发状态机流转）
  Future<void> driveConnections(Iterable<Connection> connections) async {
    DateTime now = DateTime.now();
    Duration elapsed = Duration(
      microseconds: now.microsecondsSinceEpoch - _last.microsecondsSinceEpoch,
    );
    List<Future<void>> futures = [];
    for (Connection conn in connections) {
      futures.add(conn.tick(now, elapsed));
    }
    await Future.wait(futures);
    _last = now;
  }

  /// 清理关闭的连接
  Future<void> cleanupConnections(Iterable<Connection> connections) async {
    Connection? cached;
    for (Connection conn in connections) {
      if (conn.isClosed) {
        // 移除关闭的连接
        cached = removeConnection(
          conn,
          remote: conn.remoteAddress!,
          local: conn.localAddress,
        );
        if (cached != null && !identical(cached, conn)) {
          await cached.close();
        }
      }
    }
  }

  /// 上次驱动时间（用于计算 elapsed）
  DateTime _last = DateTime.now();

  /// 枢纽主循环（对外接口：驱动通道 + 驱动连接 + 清理资源）
  @override
  Future<bool> process() async {
    // 1. 驱动所有通道接收数据并分发
    Iterable<Channel> channels = allChannels;
    int count = await driveChannels(channels);
    // 2. 驱动所有连接的状态机流转
    Iterable<Connection> connections = allConnections;
    await driveConnections(connections);
    // 3. 清理关闭的通道和连接
    await cleanupChannels(channels);
    await cleanupConnections(connections);
    // 返回是否有数据处理（true 表示有数据，false 表示空闲）
    return count > 0;
  }
}
