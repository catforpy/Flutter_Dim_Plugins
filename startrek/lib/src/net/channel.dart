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

/// 通道状态枚举
/// ~~~~~~~~~~~~~~~~~~~
enum ChannelStatus {
  init,    // 初始化中
  open,    // 已初始化（打开）
  alive,   // 存活（未关闭）且（已连接或已绑定）
  closed;  // 已关闭
}

/// 通用网络通道接口（整合字节读写、阻塞配置、地址管理、数据收发）
abstract interface class Channel implements ByteChannel{

  /// 获取通道当前状态
  ChannelStatus get status;

  /// 是否已绑定到本地地址
  bool get isBound;

  /// 是否存活：已打开 且（已连接或已绑定）
  bool get isAlive;     

  /// 是否可读取（存活即可读）
  bool get isAvailable;  

  /// 是否可写入（存活即可写）
  bool get isVacant;    

  /*================================================*\
  |*          可选择通道（阻塞/非阻塞配置）          *|
  \*================================================*/

  /// 配置通道的阻塞模式
  /// @param block - true: 阻塞模式，false: 非阻塞模式
  /// @return 配置后的可选择通道（null表示不支持）
  SelectableChannel? configureBlocking(bool block);

  /// 获取当前是否为阻塞模式
  bool get isBlocking;

  /*================================================*\
  |*          网络通道（本地地址绑定）               *|
  \*================================================*/

  /// 绑定到本地地址
  /// @param local - 本地地址（IP+端口）
  /// @return 绑定后的网络通道（null表示绑定失败）
  Future<NetworkChannel?> bind(SocketAddress local);

  /// 获取已绑定的本地地址
  SocketAddress? get localAddress;

  /*================================================*\
  |*          套接字/数据报通道（远程连接）         *|
  \*================================================*/

  /// 是否已连接到远程地址
  bool get isConnected;

  /// 连接到远程地址
  /// @param remote - 远程地址（IP+端口）
  /// @return 连接后的网络通道（null表示连接失败）
  Future<NetworkChannel?> connect(SocketAddress remote);

  /// 获取已连接的远程地址
  SocketAddress? get remoteAddress;

  /*================================================*\
  |*          数据报通道（UDP专用）                  *|
  \*================================================*/

  /// 断开与远程地址的链接(UDP专用)
  Future<ByteChannel?> disconnect();

  /// 接收数据报（UDP专用）
  /// @param maxLen - 最大接收字节数
  /// @return 接收的字节数据 + 发送方地址（均为null表示接收失败）
  Future<Pair<Uint8List?,SocketAddress?>> receive(int maxLen);

  /// 发送数据报到指定目标地址（UDP专用）
  /// @param src - 待发送的字节数据
  /// @param target - 目标地址
  /// @return 已发送的字节数
  Future<int> send(Uint8List src, SocketAddress target);
}