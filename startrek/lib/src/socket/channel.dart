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

/// Socket 读取器接口
/// 定义通道的“读/接收”能力，适配 TCP（无地址）和 UDP（带地址）的差异
abstract interface class SocketReader {
  /// 从Socket 读取数据(TCP 专用，无远程地址)
  /// @param maxLen - 最大读取长度
  /// @return 读取到的字节数组（null 表示无数据/关闭）
  Future<Uint8List?> read(int maxLen);

  /// 从 Socket 接收数据（UDP 专用，带远程地址）
  /// @param maxLen - 最大接收长度
  /// @return 键值对：(读取到的字节数组, 发送方地址)
  Future<Pair<Uint8List?, SocketAddress?>> receive(int maxLen);
}

/// Socket 写入器接口
/// 定义通道的“写/发送”能力，适配 TCP（无地址）和 UDP（带地址）的差异
abstract interface class SocketWriter {
  /// 向 Socket 写入数据（TCP 专用，无远程地址）
  /// @param src - 待发送的字节数组
  /// @return 实际发送的字节数
  Future<int> write(Uint8List src);

  /// 通过 Socket 发送数据到指定地址（UDP 专用）
  /// @param src - 待发送的字节数组
  /// @param target - 目标远程地址
  /// @return 实际发送的字节数
  Future<int> send(Uint8List src, SocketAddress target);
}

/// Socket 通道控制器
/// 辅助类：持有通道的弱引用，提供地址/套接字的快捷访问
/// 泛型 C：可选择通道（SelectableChannel，TCP/UDP 通道的父类）
abstract class ChannelController<C extends SelectableChannel> {
  ChannelController(BaseChannel<C> channel)
    : _channelRef = WeakReference(channel);

  /// 通道的弱引用(避免内存泄漏)
  final WeakReference<BaseChannel<C>> _channelRef;

  /// 获取关联的通道(可能为Null，须判空)
  BaseChannel<C>? get channel => _channelRef.target;

  /// 快捷获取远程地址(透传通道的remoteAddress)
  SocketAddress? get remoteAddress => channel?.remoteAddress;

  /// 快捷获取本地地址（透传通道的 localAddress）
  SocketAddress? get localAddress => channel?.localAddress;

  /// 快捷获取底层 Socket（透传通道的 socket）
  C? get socket => channel?.socket;
}

/// 基础通道类（TCP/UDP 通用）
/// 核心实现：封装 Socket 通道的通用逻辑（状态管理、生命周期、读写/收发）
/// 泛型 C：可选择通道（SelectableChannel），子类需指定为 TCP/UDP 具体通道类型
abstract class BaseChannel<C extends SelectableChannel>
    extends AddressPairObject
    implements Channel {
  BaseChannel({super.remote, super.local}) {
    // 初始化时创建读写器(子类需要实现createReader/createWriter)
    reader = createReader();
    writer = createWriter();
  }

  /// 创建Socket读取器(子类实现:TCPReader/UDPReader)
  SocketReader createReader();

  /// 创建 Socket 写入器（子类实现：TCPWriter/UDPWriter）
  SocketWriter createWriter();

  /// 通道读取器（由子类创建，适配 TCP/UDP）
  late final SocketReader reader;

  /// 通道写入器（由子类创建，适配 TCP/UDP）
  late final SocketWriter writer;

  /// 底层Socket 实例(TCP: Socket,UDP: RawDatagramSocket)
  C? _sock;

  /// 关闭标记（避免重复关闭）
  bool? _closed;

  // ====================== Socket 管理 ======================
  /// 获取底层 Socket 实例
  C? get socket => _sock;

  /// 设置底层 Socket 实例（核心方法：替换/关闭旧 Socket）
  /// @param sock - 新的 Socket 实例（null 表示关闭）
  Future<void> setSocket(C? sock) async {
    // 1.替换新Socket
    C? old = _sock;
    if (sock != null) {
      _sock = sock;
      _closed = false;
    } else {
      _sock = null;
      _closed = true;
    }

    // 2.关闭旧Socket（避免资源泄露）
    if (old == null || identical(old, sock)) {
    } else {
      // 关闭Socket套接字
      await SocketHelper.socketDisconnect(old);
    }
  }

  // ====================== 状态管理 ======================
  /// 获取通道状态（核心：整合 Socket 状态，转换为统一的 ChannelStatus）
  @override
  ChannelStatus get status {
    if (_closed == null) {
      // 初始化种
      return ChannelStatus.init;
    }
    C? sock = _sock;
    if (sock == null || SocketHelper.socketIsClosed(sock)) {
      // 已关闭
      return ChannelStatus.closed;
    } else if (SocketHelper.socketIsConnected(sock) ||
        SocketHelper.socketIsBound(sock)) {
      // 存活(TCP已连接/UDP已绑定)
      return ChannelStatus.alive;
    } else {
      // 已打开但未链接/绑定
      return ChannelStatus.open;
    }
  }

  /// 判断通道是否关闭
  @override
  bool get isClosed {
    if (_closed == null) {
      // 初始化中，视为未关闭
      return false;
    }
    C? sock = _sock;
    return sock == null || SocketHelper.socketIsClosed(sock);
  }

  /// 判断通道是否绑定（UDP 专用：绑定本地地址）
  @override
  bool get isBound {
    C? sock = _sock;
    return sock != null && SocketHelper.socketIsBound(sock);
  }

  /// 判断通道是否连接（TCP 专用：连接远程地址）
  @override
  bool get isConnected {
    C? sock = _sock;
    return sock != null && SocketHelper.socketIsConnected(sock);
  }

  /// 判断通道是否存活（未关闭 + 已连接/已绑定）
  @override
  bool get isAlive => (!isClosed) && (isConnected || isBound);

  /// 判断通道是否可读（有数据待读取）
  @override
  bool get isAvailable {
    C? sock = _sock;
    if (sock == null || SocketHelper.socketIsClosed(sock)) {
      return false;
    } else if (SocketHelper.socketIsConnected(sock) ||
        SocketHelper.socketIsBound(sock)) {
      // 存活状态下，检查读取缓冲区
      return checkAvailable(sock);
    } else {
      return false;
    }
  }

  /// 子类实现：检查通道是否可读（适配 TCP/UDP）
  bool checkAvailable(C sock) => SocketHelper.socketIsAvailable(sock);

  /// 判断通道是否可写（发送缓冲区有空余）
  @override
  bool get isVacant {
    C? sock = _sock;
    if (sock == null || SocketHelper.socketIsClosed(sock)) {
      return false;
    } else if (SocketHelper.socketIsConnected(sock) ||
        SocketHelper.socketIsBound(sock)) {
      // 存活状态下，检查发送缓冲区
      return checkVacant(sock);
    } else {
      return false;
    }
  }

  /// 子类实现： 检查通道是否可写(适配TCP/UDP)
  bool checkVacant(C sock) => SocketHelper.socketIsVacant(sock);

  /// 判断通道是否为阻塞模式
  @override
  bool get isBlocking {
    C? sock = _sock;
    return sock != null && SocketHelper.socketIsBlocking(sock);
  }

  /// 重写 toString：便于调试（显示地址、状态、Socket 实例）
  @override
  String toString() {
    String clazz = className;
    return '<$clazz remote="$remoteAddress" local="$localAddress"'
        ' closed=$isClosed bound=$isBound connected=$isConnected>\n\t'
        '$_sock\n</$clazz>';
  }

  /// 设置通道阻塞/非阻塞模式
  @override
  SelectableChannel? configureBlocking(bool block) {
    C? sock = socket;
    sock?.configureBlocking(block);
    return sock;
  }

  // ====================== 绑定/连接/断开 ======================
  /// 子类实现：绑定本地地址（UDP 专用）
  Future<bool> doBind(C sock, SocketAddress local) async {
    if (sock is NetworkChannel) {
      return await SocketHelper.socketBind(sock as NetworkChannel, local);
    }
    assert(false, 'socket error: $sock');
    return false;
  }

  /// 子类实现：连接远程地址（TCP 专用）
  Future<bool> doConnect(C sock, SocketAddress remote) async {
    if (sock is NetworkChannel) {
      return await SocketHelper.socketConnect(sock as NetworkChannel, remote);
    }
    assert(false, 'socket error: $sock');
    return false;
  }

  /// 断开连接（通用）
  Future<bool> doDisconnect(C sock) async =>
      await SocketHelper.socketDisconnect(sock);

  /// 绑定本地地址（对外接口）
  @override
  Future<NetworkChannel?> bind(SocketAddress local) async {
    C? sock = socket;
    bool ok = sock != null && await doBind(sock, local);
    if (!ok) {
      assert(false, 'failed to bind socket: $local');
      return null;
    }
    localAddress = local;
    return sock as NetworkChannel;
  }

  /// 连接远程地址（对外接口）
  @override
  Future<NetworkChannel?> connect(SocketAddress remote) async {
    C? sock = socket;
    bool ok = sock != null && await doConnect(sock, remote);
    if (!ok) {
      assert(false, 'failed to connect socket: $remote');
      return null;
    }
    remoteAddress = remote;
    return sock as NetworkChannel;
  }

  /// 断开连接（对外接口）
  @override
  Future<ByteChannel?> disconnect() async {
    C? sock = _sock;
    bool ok = sock == null || await doDisconnect(sock);
    if (!ok) {
      assert(false, 'failed to disconnect socket: $sock');
      return null;
    }
    return sock is ByteChannel ? sock as ByteChannel : null;
  }

  /// 关闭通道（核心：设置 Socket 为 null，触发旧 Socket 关闭）
  @override
  Future<void> close() async => await setSocket(null);

  // ====================== 读写/收发（对外接口） ======================
  /// 读取数据（TCP 专用）
  @override
  Future<Uint8List?> read(int maxLen) async {
    try {
      return await reader.read(maxLen);
    } on IOException {
      // 读取异常时关闭通道
      await close();
      rethrow;
    }
  }

  /// 写入数据（TCP 专用）
  @override
  Future<int> write(Uint8List src) async {
    try {
      return await writer.write(src);
    } on IOException {
      // 写入异常时关闭通道
      await close();
      rethrow;
    }
  }

  /// 接收数据（UDP 专用）
  @override
  Future<Pair<Uint8List?, SocketAddress?>> receive(int maxLen) async {
    try {
      return await reader.receive(maxLen);
    } on IOException {
      // 接收异常时关闭通道
      await close();
      rethrow;
    }
  }

  /// 发送数据（UDP 专用）
  @override
  Future<int> send(Uint8List src, SocketAddress target) async {
    try {
      return await writer.send(src, target);
    } on IOException {
      // 发送异常时关闭通道
      await close();
      rethrow;
    }
  }
}
