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
import 'package:stargate/startrek.dart';

/// 流通道读取器（实现SocketReader接口）
/// 核心职责：从SocketChannel读取数据
class StreamChannelReader extends ChannelController<SocketChannel> implements SocketReader {
  /// 构造方法
  StreamChannelReader(super.channel);

  /// 读取数据（指定最大长度）
  @override
  Future<Uint8List?> read(int maxLen) async {
    // 获取SocketChannel
    SocketChannel? sock = socket;
    if (sock == null || sock.isClosed) {
      // Socket已关闭 → 抛出异常
      throw ClosedChannelException();
    }
    // 读取数据
    return await sock.read(maxLen);
  }

  /// 接收数据（返回数据+远程地址）
  @override
  Future<Pair<Uint8List?, SocketAddress?>> receive(int maxLen) async {
    // 读取数据
    Uint8List? data = await read(maxLen);
    if (data == null || data.isEmpty) {
      // 无数据 → 返回空
      return Pair(data, null);
    }
    // 获取远程地址
    SocketAddress? remote = remoteAddress;
    assert(remote != null, 'should not happen: ${data.length}');
    // 返回数据+地址对
    return Pair(data, remote);
  }
}

/// 流通道写入器（实现SocketWriter接口）
/// 核心职责：向SocketChannel写入数据
class StreamChannelWriter extends ChannelController<SocketChannel> implements SocketWriter {
  /// 构造方法
  StreamChannelWriter(super.channel);

  /// 发送全部数据（扩展点：子类可重写）
  // protected
  Future<int> sendAll(WritableByteChannel sock, Uint8List src) async {
    /// TODO: override for sending
    return await sock.write(src);
  }

  /// 写入数据
  @override
  Future<int> write(Uint8List src) async {
    // 获取SocketChannel
    SocketChannel? sock = socket;
    if (sock == null || sock.isClosed) {
      // Socket已关闭 → 抛出异常
      throw ClosedChannelException();
    }
    // 发送数据
    return await sendAll(sock, src);
  }

  /// 发送数据到指定地址（TCP已连接 → 忽略目标地址）
  @override
  Future<int> send(Uint8List src, SocketAddress target) async {
    // 断言：目标地址必须等于远程地址
    assert(target == remoteAddress, 'target error: $target, remote=$remoteAddress');
    // 写入数据
    return await write(src);
  }
}

/// 流通道（核心：封装SocketChannel的读写）
/// 继承自BaseChannel，实现流数据的读写
class StreamChannel extends BaseChannel<SocketChannel> {
  /// 构造方法
  StreamChannel({super.remote, super.local});

  /// 创建读取器
  @override
  SocketReader createReader() => StreamChannelReader(this);

  /// 创建写入器
  @override
  SocketWriter createWriter() => StreamChannelWriter(this);
}