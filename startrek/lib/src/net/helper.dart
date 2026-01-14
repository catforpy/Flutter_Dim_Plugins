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


import 'package:startrek/nio.dart';

/// 套接字工具类（统一TCP/UDP套接字操作）
abstract interface class SocketHelper {
  /// 获取套接字的本地地址（兼容TCP/UDP）
  static SocketAddress? socketGetLocalAddress(SelectableChannel sock) {
    if (sock is SocketChannel) {
      //TCP 套接字
      return sock.localAddress;
    } else if (sock is DatagramChannel) {
      //UDP 套接字
      return sock.localAddress;
    } else {
      assert(false, '未知的套接字通道: $sock');
      return null;
    }
  }

  /// 获取套接字的远程地址（兼容TCP/UDP）
  static SocketAddress? socketGetRemoteAddress(SelectableChannel sock) {
    if (sock is SocketChannel) {
      // TCP套接字
      return sock.remoteAddress;
    } else if (sock is DatagramChannel) {
      // UDP套接字
      return sock.remoteAddress;
    } else {
      assert(false, '未知的套接字通道: $sock');
      return null;
    }
  }

  //
  //  状态判断
  //

  /// 判断套接字是否为阻塞模式
  static bool socketIsBlocking(SelectableChannel sock) {
    return sock.isBlocking;
  }

  /// 判断套接字是否已连接(兼容TCP/UDP)
  static bool socketIsConnected(SelectableChannel sock) {
    if (sock is SocketChannel) {
      // TCP套接字
      return sock.isConnected;
    } else if (sock is DatagramChannel) {
      // UDP套接字
      return sock.isConnected;
    } else {
      assert(false, '未知的套接字通道: $sock');
      return false;
    }
  }

  /// 判断套接字是否已绑定（兼容TCP/UDP）
  static bool socketIsBound(SelectableChannel sock) {
    if (sock is SocketChannel) {
      // TCP套接字
      return sock.isBound;
    } else if (sock is DatagramChannel) {
      // UDP套接字
      return sock.isBound;
    } else {
      assert(false, '未知的套接字通道: $sock');
      return false;
    }
  }

  /// 判断套接字是否已关闭
  static bool socketIsClosed(SelectableChannel sock) {
    return sock.isClosed;
  }

  /// 判断套接字是否可读取（TODO: 需检查读缓冲区）
  static bool socketIsAvailable(SelectableChannel sock) {
    return true;
  }

  /// 判断套接字是否可写入（TODO: 需检查写缓冲区）
  static bool socketIsVacant(SelectableChannel sock) {
    return true;
  }

  //
  //  异步套接字I/O操作
  //

  /// 绑定套接字到本地地址
  static Future<bool> socketBind(
    NetworkChannel sock,
    SocketAddress local,
  ) async {
    await sock.bind(local);
    return sock is SelectableChannel &&
        socketIsBound(sock as SelectableChannel);
  }

  /// 连接套接字到远程地址（兼容TCP/UDP）
  static Future<bool> socketConnect(
    NetworkChannel sock,
    SocketAddress remote,
  ) async {
    if (sock is SocketChannel) {
      // TCP套接字：返回连接结果
      return await sock.connect(remote);
    } else if (sock is DatagramChannel) {
      // UDP套接字：连接后判断是否已连接
      await sock.connect(remote);
      return sock.isConnected;
    }
    assert(false, '未知的套接字通道: $sock');
    return false;
  }

  /// 关闭/断开套接字（兼容TCP/UDP）
  static Future<bool> socketDisconnect(SelectableChannel sock) async {
    if (sock is SocketChannel) {
      // TCP套接字：直接关闭
      if (sock.isClosed) {
        // 已关闭，直接返回成功
        return true;
      } else {
        await sock.close();
        return sock.isClosed;
      }
    } else if (sock is DatagramChannel) {
      // UDP套接字：断开连接（非关闭）
      if (sock.isConnected) {
        await sock.disconnect();
      }
      return !sock.isConnected;
    }
    assert(false, '未知的套接字通道: $sock');
    return false;
  }
}
