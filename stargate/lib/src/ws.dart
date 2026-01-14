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

import 'dart:typed_data';             // 字节数组

import 'package:startrek/nio.dart';    // NIO核心库
import 'package:startrek/startrek.dart';// 星际迷航核心库

import 'active.dart';                 // 主动连接类
import 'gate.dart';                   // 网关抽象类
import 'hub.dart';                    // Hub抽象类
import 'plain.dart';                  // 纯文本传输类
import 'stream.dart';                 // 流通道类
// 条件导入：Web端/io端WebSocket连接器
import 'ws_html.dart' if (dart.library.io) 'ws_io.dart';

/// 客户端网关（核心：实现CommonGate，适配客户端场景）
class ClientGate extends CommonGate<ClientHub> {
  ClientGate();

  //
  //  Porter管理（重写父类方法，简化本地地址）
  //

  /// 获取Porter（仅按远程地址）
  @override
  Porter? getPorter({required SocketAddress remote, SocketAddress? local}) =>
      super.getPorter(remote: remote);

  /// 设置Porter（仅按远程地址）
  @override
  Porter? setPorter(Porter porter, {required SocketAddress remote, SocketAddress? local}) =>
      super.setPorter(porter, remote: remote);

  /// 移除Porter（仅按远程地址）
  @override
  Porter? removePorter(Porter? porter, {required SocketAddress remote, SocketAddress? local}) =>
      super.removePorter(porter, remote: remote);

  /// 创建Porter（客户端使用PlainPorter）
  @override
  Porter createPorter({required SocketAddress remote, SocketAddress? local}) {
    var docker = PlainPorter(remote: remote/*, local: local*/);
    docker.delegate = delegate;
    return docker;
  }
}

/// 客户端Hub（核心：实现CommonHub，适配客户端场景）
class ClientHub extends CommonHub {
  ClientHub();

  //
  //  Connection管理（重写父类方法，简化本地地址）
  //

  /// 获取连接（仅按远程地址）
  @override
  Connection? getConnection({required SocketAddress remote, SocketAddress? local}) =>
      super.getConnection(remote: remote);

  /// 设置连接（仅按远程地址）
  @override
  Connection? setConnection(Connection conn, {required SocketAddress remote, SocketAddress? local}) =>
      super.setConnection(conn, remote: remote);

  /// 移除连接（仅按远程地址）
  @override
  Connection? removeConnection(Connection? conn, {required SocketAddress remote, SocketAddress? local}) =>
      super.removeConnection(conn, remote: remote);

  /// 创建连接（客户端使用ActiveConnection）
  @override
  Connection createConnection({required SocketAddress remote, SocketAddress? local}) {
    ActiveConnection conn = ActiveConnection(remote: remote/*, local: local*/);
    conn.delegate = delegate;  // 绑定网关代理
    return conn;
  }

  //
  //  Channel管理（重写父类方法，简化本地地址）
  //

  /// 创建Channel（客户端使用StreamChannel）
  @override
  Channel createChannel({required SocketAddress remote, SocketAddress? local}) =>
      StreamChannel(remote: remote/*, local: local*/);

  /// 获取Channel（仅按远程地址）
  @override
  Channel? getChannel({required SocketAddress remote, SocketAddress? local}) =>
      super.getChannel(remote: remote);

  /// 设置Channel（仅按远程地址）
  @override
  Channel? setChannel(Channel channel, {required SocketAddress remote, SocketAddress? local}) =>
      super.setChannel(channel, remote: remote);

  /// 移除Channel（仅按远程地址）
  @override
  Channel? removeChannel(Channel? channel, {SocketAddress? remote, SocketAddress? local}) =>
      super.removeChannel(channel, remote: remote);

  /// 创建SocketChannel（客户端使用WebSocketChannel）
  @override
  Future<SocketChannel?> createSocketChannel({required SocketAddress remote, SocketAddress? local}) async {
    try {
      // 创建WebSocketChannel实例
      SocketChannel? sock = _WebSocketChannel();
      // 设置为阻塞模式
      sock.configureBlocking(true);
      // 绑定本地地址（可选）
      if (local != null) {
        await sock.bind(local);
      }
      // 连接远程地址
      bool ok = await sock.connect(remote);
      if (!ok) {
        // 连接失败 → 打印日志，返回null
        logWarning('failed to connect remote address: $remote');
        return null;
      }
      // 设置为非阻塞模式
      sock.configureBlocking(false);
      return sock;
    } on Exception catch (e) {
      // 异常 → 打印日志，返回null
      logError('cannot create socket: $remote, $local, $e');
      return null;
    }
  }

  /// 打印警告日志
  // protected
  void logWarning(String msg) {
    print('[WS] WARNING | $msg');
  }

  /// 打印错误日志
  // protected
  void logError(String msg) {
    print('[WS]  ERROR  | $msg');
  }
}

/// WebSocketChannel（适配SocketChannel接口的WebSocket实现）
class _WebSocketChannel extends SocketChannel {

  /// 数据缓存（存储接收的数据包）
  final List<Uint8List> _caches = [];

  /// 远程地址
  SocketAddress? _remoteAddress;
  /// 本地地址
  SocketAddress? _localAddress;

  /// WebSocket连接器
  WebSocketConnector? _socket;

  /// 判断是否已关闭
  @override
  bool get isClosed => super.isClosed || _socket?.isClosed == true;

  /// 判断是否已绑定（客户端暂不支持 → 返回false）
  @override
  bool get isBound => false;

  /// 判断是否已连接
  @override
  bool get isConnected => _socket?.isConnected == true;

  /// 获取远程地址
  @override
  SocketAddress? get remoteAddress => _remoteAddress;

  /// 获取本地地址
  @override
  SocketAddress? get localAddress => _localAddress;

  /// 获取类名（用于日志）
  String get className => '_WebSocketChannel';

  /// 重写toString（打印通道信息）
  @override
  String toString() {
    String clazz = className;
    return '<$clazz remote="$remoteAddress" local="$localAddress">\n\t'
        '$_socket\n</$clazz>';
  }

  /// 关闭通道（实现父类方法）
  @override
  Future<void> implCloseChannel() async {
    var sock = _socket;
    _socket = null;
    // 关闭WebSocket连接器
    await sock?.close();
  }

  /// 配置阻塞模式（暂未实现）
  @override
  void implConfigureBlocking(bool block) {
    // TODO: implement implConfigureBlocking
  }

  /// 绑定本地地址（暂未实现）
  @override
  Future<SocketChannel?> bind(SocketAddress local) async {
    // TODO: implement bind
    _localAddress = local;
    return null;
  }

  /// 连接远程地址（核心：创建WebSocket连接器并连接）
  @override
  Future<bool> connect(SocketAddress remote) async {
    // 前置检查：远程地址必须是InetSocketAddress
    if (remote is! InetSocketAddress) {
      assert(false, 'remote address error: $remote');
      return false;
    } else if (_socket != null) {
      // 已连接 → 断言错误，返回false
      assert(false, 'socket already connected: $_socket');
      return false;
    }
    // 构建WebSocket URL（ws://host:port/）
    Uri url = Uri.parse('ws://${remote.host}:${remote.port}/');
    // 创建WebSocket连接器
    WebSocketConnector connector = WebSocketConnector(url);
    _socket = connector;
    // 连接WebSocket
    bool ok = await connector.connect();
    if (ok) {
      // 连接成功 → 记录地址，清空缓存
      _remoteAddress = remote;
      _caches.clear();
      // 添加NOOP包（更新连接最后接收时间）
      _caches.add(PlainPorter.NOOP);
      // 监听数据接收（缓存到_caches）
      connector.listen((msg) => _caches.add(msg));
    }
    return ok;
  }

  /// 读取数据（从缓存中取）
  @override
  Future<Uint8List?> read(int maxLen) async {
    if (_caches.isEmpty) {
      // 无数据 → 返回null
      return null;
    }
    // TODO: 处理最大长度限制
    // 移除并返回第一个数据包
    return _caches.removeAt(0);
  }

  /// 写入数据（通过WebSocket连接器发送）
  @override
  Future<int> write(Uint8List src) async {
    WebSocketConnector? connector = _socket;
    if (connector == null) {
      // 未连接 → 断言错误，返回-1
      assert(false, 'socket not connect');
      return -1;
    } else if (src.isEmpty) {
      // 空数据 → 返回0
      return 0;
    }
    // 写入数据
    return await connector.write(src);
  }
}