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

/// 面向流套接字的可选择通道（TCP专用）
/// 新创建的通道是打开但未连接的，未连接时调用I/O操作会抛NotYetConnectedException
/// 连接后保持连接状态，直到关闭
/// 支持非阻塞连接：connect发起连接，finishConnect完成连接
abstract class SocketChannel extends AbstractSelectableChannel
    implements ByteChannel, NetworkChannel {
  /// 绑定到本地地址（TCP）
  @override
  Future<SocketChannel?> bind(SocketAddress local);

  /// 判断是否已绑定到本地地址
  bool get isBound;

  /// 判断通道的套接字是否已连接
  bool get isConnected;

  /// 连接到远程地址
  /// 阻塞模式：阻塞至连接建立/失败
  /// 非阻塞模式：发起连接后返回false，需调用finishConnect完成
  /// 连接失败会关闭通道
  Future<bool> connect(SocketAddress remote);

  /// 获取已连接的远程地址（未连接返回null）
  SocketAddress? get remoteAddress;

  /// 获取绑定的本地地址（受安全管理器限制时返回回环地址）
  @override
  SocketAddress? get localAddress;
}
