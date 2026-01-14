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

/// 导出dart:io的IOException（IO异常基类）
export 'dart:io' show IOException;

/// 导出dart:io的OSError（操作系统错误）
export 'dart:io' show OSError;

/// 导出dart:io的FileSystemException（文件系统异常）
export 'dart:io' show FileSystemException;

/// 导出dart:io的FileMode（文件打开模式）
export 'dart:io' show FileMode;

/// 导出dart:io的FileSystemEntity（文件系统实体基类）
/// 补充说明：
/// - FileSystemEntity是File/Directory/Link的父类；
/// - 可通过类型检查判断实体类型（entity is File）；
/// - 建议优先使用异步方法避免阻塞；
export 'dart:io' show FileSystemEntity;

/// 导出dart:io的File（文件对象）
/// 补充说明：
/// - File对象封装文件路径，提供读写/创建/删除等操作；
/// - 支持异步/同步两种方式，优先使用异步（如readAsString而非readAsStringSync）；
/// - 若路径是符号链接，操作会指向链接的目标（除delete外）；
export 'dart:io' show File;

/// 导出dart:io的Directory（目录对象）
/// 补充说明：
/// - Directory封装目录路径，提供创建/列出子项/删除等操作；
/// - 支持静态访问系统临时目录（Directory.systemTemp）和当前目录（Directory.current）；
/// - 优先使用异步方法（如create而非createSync）；
export 'dart:io' show Directory;

// ------------------------------
//  文件系统委托接口（与第一段一致）
// ------------------------------

/// 文件系统委托接口（核心）
/// 定义文件系统操作的底层实现契约，适配dart:io的File/Directory行为
abstract interface class FileSystemDelegate {
  /// 检查实体是否存在（异步）
  /// 返回值：Future<bool> - 存在返回true，否则false
  /// 注：会检查实体类型（File/Directory）是否匹配
  Future<bool> exists(FileSystemEntity entity);

  /// 删除实体（异步）
  /// [entity] - 待删除的文件/目录
  /// [recursive] - 目录是否递归删除（默认false，空目录才能删）
  /// 返回值：Future<FileSystemEntity> - 删除后的实体对象
  /// 异常：删除失败时Future会抛出FileSystemException
  Future<FileSystemEntity> delete(FileSystemEntity entity, {bool recursive = false});

  // ---- File 相关方法 ----
  /// 创建文件（异步）
  /// [file] - 待创建的File对象
  /// [recursive] - 是否递归创建父目录（默认false）
  /// [exclusive] - 是否排他创建（已存在则抛PathExistsException，默认false）
  /// 返回值：Future<File> - 创建后的File对象
  Future<File> createFile(File file, {bool recursive = false, bool exclusive = false});

  /// 读取文件所有字节（异步）
  /// [file] - 待读取的File对象
  /// 返回值：Future<Uint8List> - 文件字节数据
  Future<Uint8List> readAsBytes(File file);

  /// 写入字节到文件（异步）
  /// [file] - 待写入的File对象
  /// [bytes] - 待写入的字节数据
  /// [mode] - 写入模式（默认FileMode.write，覆盖）
  /// [flush] - 是否强制刷盘（默认false）
  /// 返回值：Future<File> - 写入后的File对象
  Future<File> writeAsBytes(File file, List<int> bytes,
      {FileMode mode = FileMode.write, bool flush = false});

  // ---- Directory 相关方法 ----
  /// 创建目录（异步）
  /// [dir] - 待创建的Directory对象
  /// [recursive] - 是否递归创建父目录（默认false）
  /// 返回值：Future<Directory> - 创建后的Directory对象
  Future<Directory> createDirectory(Directory dir, {bool recursive = false});

  /// 列出目录子项（异步，返回Stream）
  /// [dir] - 待列出的Directory对象
  /// [recursive] - 是否递归列出子目录（默认false）
  /// [followLinks] - 是否跟随符号链接（默认true）
  /// 返回值：Stream<FileSystemEntity> - 子项流（File/Directory/Link）
  /// 注：Stream中的实体顺序随机，不包含.和..
  Stream<FileSystemEntity> list(Directory dir,
      {bool recursive = false, bool followLinks = true});
}

/// 全局单例文件系统管理器
/// 提供统一的文件系统入口，适配dart:io的底层实现
class FileSystem {
  /// 工厂方法：返回单例实例
  factory FileSystem() => _instance;
  /// 单例对象
  static final FileSystem _instance = FileSystem._internal();
  /// 私有构造方法：禁止外部实例化
  FileSystem._internal();

  /// 文件系统委托实现（默认null，需外部注入dart:io实现）
  FileSystemDelegate? delegate;
}