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

import 'package:startrek/fsm.dart';
import 'package:startrek/nio.dart';
import 'package:startrek/startrek.dart';

/// 网络连接接口（继承Ticker，支持状态机自动驱动）
abstract interface class Connection implements Ticker {
  //
  //  连接状态标识
  //
  /// 是否已关闭（!isOpen()）
  bool get isClosed;

  /// 是否已绑定到本地地址
  bool get isBound;

  /// 是否已连接到远程地址
  bool get isConnected;

  /// 是否存活：已打开 且（已连接或已绑定）
  bool get isAlive;

  /// 是否可读取（存活即可读）
  bool get isAvailable;

  /// 是否可写入（存活即可写）
  bool get isVacant;

  /// 获取本地地址
  SocketAddress? get localAddress;

  /// 获取远程地址
  SocketAddress? get remoteAddress;

  /// 获取当前连接状态（状态机管理）
  ConnectionState? get state;

  /// 发送数据
  /// @param data - 待发送的字节数据
  /// @return 已发送的字节数（非阻塞模式下可能为0）
  Future<int> sendData(Uint8List data);

  /// 处理接收到的数据（内部回调）
  /// @param data - 已接收的字节数据
  Future<void> onReceivedData(Uint8List data);

  /// 关闭连接
  Future<void> close();
}

/// 连接代理接口（连接事件回调）
abstract interface class ConnectionDelegate {
  /// 连接状态变更时调用
  /// @param previous   - 旧状态
  /// @param current    - 新状态
  /// @param connection - 当前连接
  Future<void> onConnectionStateChanged(
    ConnectionState? previous,
    ConnectionState? current,
    Connection connection,
  );

  /// 连接接收到数据时调用
  /// @param data        - 已接收的字节数据
  /// @param connection  - 当前连接
  Future<void> onConnectionReceived(Uint8List data, Connection connection);

  /// 连接发送数据完成后调用
  /// @param sent        - 已发送的字节数
  /// @param data        - 待发送的字节数据
  /// @param connection  - 当前连接
  Future<void> onConnectionSent(
    int sent,
    Uint8List data,
    Connection connection,
  );

  /// 连接发送数据失败时调用
  /// @param error       - 错误信息
  /// @param data        - 待发送的字节数据
  /// @param connection  - 当前连接
  Future<void> onConnectionFailed(
    IOError error,
    Uint8List data,
    Connection connection,
  );

  /// 连接（接收数据）出错时调用
  /// @param error       - 错误信息
  /// @param connection  - 当前连接
  Future<void> onConnectionError(IOError error, Connection connection);
}

/// 带时间戳的连接接口（记录收发时间，用于心跳/超时判断）
abstract interface class TimedConnection {
  // 超时时间常量：16秒
  static Duration EXPIRES = Duration(seconds: 16);

  /// 最后一次发送数据的时间
  DateTime? get lastSentTime;

  /// 最后一次接收数据的时间
  DateTime? get lastReceivedTime;

  /// 判断是否近期发送过数据（基于EXPIRES）
  bool isSentRecently(DateTime now);

  /// 判断是否近期接收过数据（基于EXPIRES）
  bool isReceivedRecently(DateTime now);

  /// 判断是否长时间未接收数据（超过EXPIRES）
  bool isNotReceivedLongTimeAgo(DateTime now);
}
