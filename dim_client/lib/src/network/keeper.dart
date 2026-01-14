/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2025 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2025 Albert Moky
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

import 'package:lnc/log.dart';
import 'package:object_key/object_key.dart';
import 'package:stargate/skywalker.dart';
import 'package:stargate/startrek.dart';
import 'package:stargate/websocket.dart';

import 'gate.dart';

/// 网关管理器（单例模式）
/// 实现了Processor和PorterDelegate接口，负责管理网关连接、处理消息、转发回调
class GateKeeper with Logging implements Processor, PorterDelegate {
  /// 工厂方法，返回单例实例
  factory GateKeeper() => _instance;

  /// 单例实例
  static final GateKeeper _instance = GateKeeper._internal();

  /// 私有构造方法
  GateKeeper._internal() {
    // 创建网关和集线器
    _gate = createGate();
    _hub = createHub(_gate);
    _gate.hub = _hub;
  }

  /// 网关集线器（管理连接）联网、收数据、管连接，不处理业务逻辑
  late final CommonHub _hub;

  /// 通用网关，管创建Porter、发数据、处理业务逻辑，持有hub的属性引用来获取数据来源
  late final CommonGate _gate;

  /// 处理状态标记（防止并发处理）
  bool _processing = false;

  /// 获取网关实例
  CommonGate get gate => _gate;

  /// PorterDelegate监听器集合（弱引用，防止内存泄漏）
  final Set<PorterDelegate> _listeners = WeakSet();

  /// 创建网关实例（可重写）
  /// 返回：CommonGate实例（默认创建AckEnableGate）
  // protected
  CommonGate createGate() {
    CommonGate gate = AckEnableGate();
    gate.delegate = this;
    return gate;
  }

  /// 创建集线器实例（可重写）
  /// [delegate]：连接委托
  /// 返回：CommonHub实例
  // protected
  CommonHub createHub(ConnectionDelegate delegate) {
    CommonHub hub = ClientHub();
    hub.delegate = delegate;
    return hub;
  }

  /// 添加PorterDelegate监听器
  /// [delegate]：监听器
  /// 返回：是否添加成功
  bool addListener(PorterDelegate delegate) => _listeners.add(delegate);

  /// 移除PorterDelegate监听器
  /// [delegate]：监听器
  /// 返回：是否移除成功
  bool removeListener(PorterDelegate delegate) => _listeners.remove(delegate);

  /// 重新连接指定远程地址
  /// [remote]：远程地址
  /// 返回：新的连接实例（null表示失败）
  Future<Connection?> reconnect({required SocketAddress remote}) async {
    // 移除旧链接
    await disconnect(remote: remote);
    // 建立新连接
    return await connect(remote: remote);
  }

  /// 连接指定远程地址
  /// [remote]：远程地址
  /// 返回：连接实例（null表示失败）
  Future<Connection?> connect({required SocketAddress remote}) async {
    Connection? conn = await _hub.connect(remote: remote);
    logInfo('new connection: $remote, $conn');
    return conn;
  }

  /// 断开指定远程地址的连接
  /// [remote]：远程地址
  /// 返回：关闭的连接数量
  Future<int> disconnect({required SocketAddress remote}) async {
    int count = 0;
    // 获取当前链接
    Connection? conn = _hub.getConnection(remote: remote);
    // 从集线器移除链接
    Connection? cached = _hub.removeConnection(conn, remote: remote);
    if (cached == null || identical(cached, conn)) {
    } else {
      logWarning('close cached connection: $remote, $cached');
      await cached.close();
      count += 1;
    }
    if (conn != null) {
      logWarning('close connection: $remote, $conn');
      await conn.close();
      count += 1;
    }
    return count;
  }

  /// 处理网关/集线器的消息（实现Processor接口）
  /// 返回：是否有消息处理（入站/出站）
  @override
  Future<bool> process() async {
    if (_processing) {
      // 正在处理中，返回false
      return false;
    } else {
      _processing = true;
    }
    // 处理入站消息
    bool incoming = await _hub.process();
    // 处理出栈消息
    bool outgoing = await _gate.process();
    // 重置处理状态
    _processing = false;
    // 返回是否有消息处理
    return incoming || outgoing;
  }

  //
  //  Docker Delegate（PorterDelegate接口实现）
  //

  /// Porter状态变更回调
  /// [previous]：之前的状态
  /// [current]：当前的状态
  /// [porter]：对应的Porter实例
  @override
  Future<void> onPorterStatusChanged(
    PorterStatus previous,
    PorterStatus current,
    Porter porter,
  ) async {
    logInfo(
      'onPorterStatusChanged: ${porter.remoteAddress}, calling ${_listeners.length} listener(s)',
    );
    // 转发回调到所有监听器
    for (var delegate in _listeners) {
      await delegate.onPorterStatusChanged(previous, current, porter);
    }
  }

  /// Porter收到消息回调
  /// [ship]：收到的数据包
  /// [porter]：对应的Porter实例
  @override
  Future<void> onPorterReceived(Arrival ship, Porter porter) async {
    logDebug(
      'onPorterReceived: ${porter.remoteAddress}, calling ${_listeners.length} listener(s)',
    );
    // 转发回调到所有监听器
    for (var delegate in _listeners) {
      await delegate.onPorterReceived(ship, porter);
    }
  }

  /// Porter发送消息成功回调
  /// [ship]：发送的数据包
  /// [porter]：对应的Porter实例
  @override
  Future<void> onPorterSent(Departure ship, Porter porter) async {
    logDebug(
      'onPorterSent: ${porter.remoteAddress}, calling ${_listeners.length} listener(s)',
    );
    // 转发回调到所有监听器
    for (var delegate in _listeners) {
      await delegate.onPorterSent(ship, porter);
    }
  }

  /// Porter发送消息失败回调
  /// [error]：错误信息
  /// [ship]：发送失败的数据包
  /// [porter]：对应的Porter实例
  @override
  Future<void> onPorterFailed(
    IOError error,
    Departure ship,
    Porter porter,
  ) async {
    logWarning(
      'onPorterFailed: ${porter.remoteAddress}, calling ${_listeners.length} listener(s)',
    );
    // 转发回调到所有监听器
    for (var delegate in _listeners) {
      await delegate.onPorterFailed(error, ship, porter);
    }
  }

  /// Porter发送消息出错回调
  /// [error]：错误信息
  /// [ship]：出错的数据包
  /// [porter]：对应的Porter实例
  @override
  Future<void> onPorterError(
    IOError error,
    Departure ship,
    Porter porter,
  ) async {
    logError(
      'onPorterError: ${porter.remoteAddress}, calling ${_listeners.length} listener(s)',
    );
    // 转发回调到所有监听器
    for (var delegate in _listeners) {
      await delegate.onPorterError(error, ship, porter);
    }
  }
}
