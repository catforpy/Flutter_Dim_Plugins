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

import 'package:object_key/object_key.dart';
import 'package:startrek/nio.dart';

/// 面向数据报套接字的可选择通道（UDP专用）
/// 新创建的通道是打开但未连接的，无需连接即可使用send/receive方法
/// 连接后可避免每次send/receive的安全检查开销，且必须连接才能使用read/write方法
/// 连接后保持连接状态，直到断开或关闭
abstract class DatagramChannel extends AbstractSelectableChannel
    implements ByteChannel, NetworkChannel {
  /// 绑定到本地地址（UDP）
  @override
  Future<DatagramChannel?> bind(SocketAddress local);

  /// 判断是否已绑定到本地地址
  bool get isBound;

  /// 判断通道的套接字是否已连接
  bool get isConnected;

  /// 连接到远程地址
  /// 连接后，套接字仅接收/发送该地址的数据报，直到断开/关闭
  /// 若套接字未绑定，会先自动绑定到随机地址
  Future<DatagramChannel?> connect(SocketAddress remote);

  /// 断开与远程地址的连接
  /// 断开后，套接字可接收/发送任意地址的数据报（受安全管理器限制）
  /// 未连接/已关闭时调用无效果
  Future<DatagramChannel?> disconnect();

  /// 获取已连接的远程地址（未连接返回null）
  SocketAddress? get remoteAddress;

  /// 接收数据报
  /// @param maxLen - 最大接收字节数
  /// @return 接收的字节数据 + 发送方地址（非阻塞模式无数据时返回null）
  /// 若缓冲区空间不足，数据报超出部分会被静默丢弃
  /// 未绑定的话会先自动绑定到随机地址
  Future<Pair<Uint8List?, SocketAddress>> receive(int maxLen);

  /// 发送数据报到指定地址
  /// @param src - 待发送的字节数据
  /// @param target - 目标地址
  /// @return 发送的字节数（非阻塞模式可能为0）
  /// 未绑定的话会先自动绑定到随机地址
  Future<int> send(Uint8List src, SocketAddress target);

  /// 获取绑定的本地地址（受安全管理器限制时返回回环地址）
  @override
  SocketAddress? get localAddress;
}
