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

// 导入文件系统核心类
import 'files.dart';

/// 可读资源抽象接口
/// 定义资源的读取能力：检查存在性、读取内容、获取字节数据
abstract class Readable {
  /// 检查文件是否存在（异步）
  /// [path] - 文件路径
  /// 返回值：Future<bool> - 存在返回true
  Future<bool> exists(String path);

  /// 读取文件内容到内存（异步）
  /// [path] - 文件路径
  /// 返回值：Future<int> - 文件字节长度
  /// 异常：文件不存在时抛出FileSystemException
  Future<int> read(String path);

  /// 获取已读取的文件字节数据
  Uint8List? get data;
}

/// 可写资源抽象接口（继承Readable）
/// 扩展可读接口，增加写入、删除能力
abstract class Writable implements Readable {
  /// 设置待写入的文件字节数据
  set data(Uint8List? content);

  /// 将内存中的数据写入文件（异步）
  /// [path] - 文件路径
  /// 返回值：Future<int> - 写入的字节长度
  /// 异常：数据为空/目录创建失败时抛出FileSystemException
  Future<int> write(String path);

  /// 删除文件（异步）
  /// [path] - 文件路径
  /// 返回值：Future<bool> - 删除成功返回true
  /// 异常：删除失败时抛出FileSystemException
  Future<bool> remove(String path);
}

/// 只读资源实现类（Readable）
/// 封装文件读取逻辑，将文件内容缓存到内存
class Resource implements Readable {
  /// 缓存的文件字节数据
  Uint8List? _content;

  /// 获取缓存的字节数据
  @override
  Uint8List? get data => _content;

  /// 检查文件是否存在
  @override
  Future<bool> exists(String path) async {
    File file = File(path);
    return await file.exists();
  }

  /// 读取文件内容到内存
  @override
  Future<int> read(String path) async {
    File file = File(path);
    // 检查文件是否存在
    if (!await file.exists()) {
      throw FileSystemException('file not exists: $path');
    }
    // 读取字节并缓存
    Uint8List bytes = await file.readAsBytes();
    _content = bytes;
    return bytes.length;
  }
}

/// 可读写存储实现类（继承Resource + Writable）
/// 扩展只读资源，增加写入、删除能力，自动创建父目录
class Storage extends Resource implements Writable {
  /// 设置待写入的字节数据（覆盖父类缓存）
  @override
  set data(Uint8List? content) => _content = content;

  /// 删除文件
  @override
  Future<bool> remove(String path) async {
    File file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    return true;
  }

  /// 将内存数据写入文件
  @override
  Future<int> write(String path) async {
    Uint8List? bytes = _content;
    // 检查数据是否为空
    if (bytes == null) {
      throw FileSystemException('content empty, failed to save file: $path');
    }
    File file = File(path);
    // 检查父目录是否存在，不存在则创建
    if (!await file.exists()) {
      Directory dir = file.parent;
      await dir.create(recursive: true);
      if (!await dir.exists()) {
        throw FileSystemException('failed to create directory: ${dir.path}');
      }
    }
    // 写入数据并强制刷盘
    await file.writeAsBytes(bytes, flush: true);
    return bytes.length;
  }
}