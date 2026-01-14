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

/// 可关闭接口：表示可释放资源的数据源/数据目标（如文件、套接字）
abstract interface class Closeable {
  /// 关闭流并释放关联的系统资源
  /// 如果流已关闭，调用此方法无效果
  /// 注意：关闭失败时需先释放资源，再抛出异常
  Future<void> close();
}

/// I/O操作的核心抽象（通道）
/// 通道表示与硬件设备、文件、网络套接字等实体的开放连接，支持读/写等I/O操作
/// 通道只有“打开”和“关闭”两种状态：创建时打开，关闭后保持关闭，关闭后调用I/O操作会抛ClosedChannelException
/// 通道通常支持多线程安全访问
abstract interface class NIOChannel implements Closeable {
  /// 判断通道是否已关闭（!isOpen）
  bool get isClosed;
}

/// 可读字节通道
/// 同一时刻只能有一个读操作：若一个线程发起读操作，其他线程的读操作会阻塞至前者完成
/// 其他I/O操作是否可与读操作并发，取决于通道类型
abstract interface class ReadableByteChannel implements NIOChannel {
  /// 从通道读取字节序列到缓冲区
  /// @param maxLen - 最大读取字节数（缓冲区剩余空间）
  /// @return 读取的字节数（可能为0），或-1（通道到达流末尾）
  /// 阻塞模式：若缓冲区有剩余空间，会阻塞至至少读取1字节
  /// 非阻塞模式：可能读取0字节（无数据可用）
  Future<Uint8List?> read(int maxLen);
}

/// 可写字节通道
/// 同一时刻只能有一个写操作：若一个线程发起写操作，其他线程的写操作会阻塞至前者完成
/// 其他I/O操作是否可与写操作并发，取决于通道类型
abstract interface class WritableByteChannel implements NIOChannel {
  /// 从缓冲区写入字节序列到通道
  /// @param src - 待写入的字节数据
  /// @return 写入的字节数（可能为0）
  /// 阻塞模式：默认会写入所有请求的字节
  /// 非阻塞模式：可能只写入部分字节（如套接字输出缓冲区满）
  Future<int> write(Uint8List src);
}

/// 可读可写字节通道（仅整合接口，无新增方法）
abstract interface class ByteChannel
    implements ReadableByteChannel, WritableByteChannel {}
