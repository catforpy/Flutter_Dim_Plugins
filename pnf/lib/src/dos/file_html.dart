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

import 'dart:convert';
import 'dart:typed_data';

// 导入path工具库，用于路径解析/拼接
import 'package:path/path.dart' as utils;

/// 内部工具方法：获取路径的父目录
/// [path] - 任意文件/目录路径
/// 返回值：父目录路径
String _parentOf(String path) => utils.dirname(path);

/// 文件打开模式枚举（对标dart:io的FileMode）
/// 定义文件读写的不同模式，用于File的writeAsBytes等方法
class FileMode {
  /// 只读模式：进度去文件内容，不能写入
  static const read = FileMode._internal(0);

  /// 读写模式：覆盖原有文件（不存在则创建）
  static const write = FileMode._internal(1);

  /// 追加模式：在文件末尾写入（不存在则创建）
  static const append = FileMode._internal(2);

  /// 只写模式：覆盖原有文件（不存在则创建），不支持读取
  static const writeOnly = FileMode._internal(3);

  /// 只写追加模式：在文件末尾写入（不存在则创建），不支持读取
  static const writeOnlyAppend = FileMode._internal(4);

  /// 模式对应的整数值（用于底层区分）
  final int value;

  /// 私有构造方法：禁止外部实例化
  const FileMode._internal(this.value);
}

/// IO相关异常的基类（抽象）
/// 所有文件系统操作异常的父类
abstract class IOException implements Exception{
  /// 异常字符串描述
  @override
  String toString() => "IOException";
}

/// 操作系统级别的错误信息封装
/// 包含错误描述和错误码，用于传递底层OS的错误信息
class OSError implements Exception {
  /// 无错误码时的默认值
  static const int noErrorCode = -1;

  /// 操作系统提供的错误描述信息（空字符串表示无描述）
  final String message;

  /// 操作系统返回的错误码（noErrorCode表示无错误码）
  final int errorCode;

  /// 构造方法：创建OS错误对象
  /// [message] - 错误描述（默认空）
  /// [errorCode] - 错误码（默认noErrorCode）
  const OSError([this.message = "", this.errorCode = noErrorCode]);

  /// 转换为字符串（便于日志/调试）
  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    sb.write("OS Error");
    if (message.isNotEmpty) {
      sb..write(": ")..write(message);
      if (errorCode != noErrorCode) {
        sb..write(", errno = ")..write(errorCode.toString());
      }
    } else if (errorCode != noErrorCode) {
      sb..write(": errno = ")..write(errorCode.toString());
    }
    return sb.toString();
  }
}

/// 文件系统操作异常类
/// 封装文件操作失败的信息：错误描述、关联路径、底层OS错误
class FileSystemException implements IOException {
  /// 错误描述信息
  final String message;

  /// 触发异常的文件/目录路径（可为空）
  final String? path;

  /// 底层操作系统错误（可为空）
  final OSError? osError;

  /// 构造方法：创建文件系统异常
  /// [message] - 错误描述（默认空）
  /// [path] - 关联路径（默认空）
  /// [osError] - 底层OS错误（默认空）
  const FileSystemException([this.message = "", this.path = "", this.osError]);

  /// 获取类名（用于toString格式化）
  String get className => 'FileSystemException';

  /// 转换为字符串（便于日志/调试）
  @override
  String toString() {
    String clazz = className;
    return '<$clazz path="$path" />';
  }
}

/// 文件系统实体抽象类（File/Directory/Link的父类）
/// 定义文件系统实体（文件/目录/链接）的通用属性和方法
abstract class FileSystemEntity {
  /// 构造方法：初始化实体路径
  FileSystemEntity(this.path);

  /// 实体的文件系统路径（绝对/相对）
  final String path;

  /// 转换为Uri对象（file://协议）
  Uri get uri => Uri.file(path);

  /// 检查实体是否存在（异步）
  Future<bool> exists();

  /// 删除实体（异步）
  /// [recursive] - 是否递归删除（目录专用，默认false）
  Future<FileSystemEntity> delete({bool recursive = false});

  /// 获取父目录（返回Directory对象）
  Directory get parent => Directory(_parentOf(path));
}

/// 文件对象类（FileSystemEntity的实现）
/// 封装文件的创建、读写、删除等操作，所有操作委托给FileSystemDelegate
class File extends FileSystemEntity {
  /// 构造方法：通过路径创建File对象
  File(super.path);

  /// 工厂方法：通过Uri创建File对象
  factory File.fromUri(Uri uri) => File(uri.toFilePath());

  /// 创建文件（异步）
  /// [recursive] - 是否递归创建父目录（默认false）
  /// [exclusive] - 是否排他创建（已存在则失败，默认false）
  /// 返回值：创建后的File对象
  Future<File> create({bool recursive = false, bool exclusive = false}) async {
    // 获取文件系统委托
    var dos = FileSystem().delegate;
    if(dos == null){
      throw FileSystemException('Cannot create file', path);
    }
    // 委托给底层实现创建文件
    return await dos.createFile(this,recursive:recursive,exclusive:exclusive);
  }

  /// 获取文件长度（字节数，异步）
  Future<int> length() async{
    Uint8List data = await readAsBytes();
    return data.length;
  }

  /// 获取文件最后访问时间（异步，暂返回当前时间，需底层实现补充）
  Future<DateTime> lastAccessed() async => DateTime.now();

  /// 获取文件最后修改时间（异步，暂返回当前时间，需底层实现补充）
  Future<DateTime> lastModified() async => DateTime.now();

  /// 读取文件所有内容为字节数组（异步）
  Future<Uint8List> readAsBytes() async{
    var dos = FileSystem().delegate;
    if(dos == null){
      throw FileSystemException('Cannot read file', path);
    }
    // 委托给底层实现读取字节
    return await dos.readAsBytes(this);
  }

  /// 读取文件所有内容为字符串（异步）
  /// [encoding] - 字符编码（默认utf8）
  Future<String> readAsString({Encoding encoding = utf8}) async =>
      encoding.decode(await readAsBytes());

  /// 读取文件所有内容为字符串列表（按行分割，异步）
  /// [encoding] - 字符编码（默认utf8）
  Future<List<String>> readAsLines({Encoding encoding = utf8}) async =>
      LineSplitter().convert(await readAsString(encoding: encoding));
  
  /// 写入字节数组到文件（异步）
  /// [bytes] - 待写入的字节数据
  /// [mode] - 写入模式（默认FileMode.write）
  /// [flush] - 是否强制刷盘（默认false）
  /// 返回值：写入后的File对象
  Future<File> writeAsBytes(List<int> bytes,
      {FileMode mode = FileMode.write, bool flush = false}) async {
    var dos = FileSystem().delegate;
    if(dos == null){
      throw FileSystemException('Cannot write file', path);
    }
    // 委托给底层实现写入字节
    return await dos.writeAsBytes(this, bytes, mode: mode, flush: flush);
  }

  /// 写入字符串到文件（异步）
  /// [contents] - 待写入的字符串
  /// [mode] - 写入模式（默认FileMode.write）
  /// [encoding] - 字符编码（默认utf8）
  /// [flush] - 是否强制刷盘（默认false）
  /// 返回值：写入后的File对象
  Future<File> writeAsString(String contents,
      {FileMode mode = FileMode.write,
        Encoding encoding = utf8,
        bool flush = false}) async =>
      writeAsBytes(encoding.encode(contents), mode: mode, flush: flush);

  /// 检查文件是否存在（异步）
  @override
  Future<bool> exists() async {
    var dos = FileSystem().delegate;
    if (dos == null) {
      throw FileSystemException('Cannot check file', path);
    }
    return await dos.exists(this);
  }

  /// 删除文件（异步）
  /// [recursive] - 是否递归删除（文件无意义，仅兼容父类）
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    var dos = FileSystem().delegate;
    if (dos == null) {
      throw FileSystemException('Cannot remove file', path);
    }
    return await dos.delete(this, recursive: recursive);
  }
}

/// 目录对象类（FileSystemEntity的实现）
/// 封装目录的创建、列出子项、删除等操作，所有操作委托给FileSystemDelegate
class Directory extends FileSystemEntity {
  /// 构造方法：通过路径创建Directory对象
  Directory(super.path);

  /// 工厂方法：通过Uri创建Directory对象
  factory Directory.fromUri(Uri uri) => Directory(uri.toFilePath());

  /// 创建目录（异步）
  /// [recursive] - 是否递归创建父目录（默认false）
  /// 返回值：创建后的Directory对象
  Future<Directory> create({bool recursive = false}) async{
    var dos = FileSystem().delegate;
    if (dos == null) {
      throw FileSystemException('Cannot create directory', path);
    }
    return await dos.createDirectory(this, recursive: recursive);
  }

  /// 列出目录下的所有子项（异步，返回Stream）
  /// [recursive] - 是否递归列出子目录（默认false）
  /// [followLinks] - 是否跟随符号链接（默认true）
  /// 返回值：FileSystemEntity的Stream（File/Directory）
  Stream<FileSystemEntity> list(
      {bool recursive = false, bool followLinks = true}) {
    var dos = FileSystem().delegate;
    if (dos == null) {
      throw FileSystemException('Cannot read directory', path);
    }
    return dos.list(this, recursive: recursive, followLinks: followLinks);
  }

  /// 检查目录是否存在（异步）
  @override
  Future<bool> exists() async {
    var dos = FileSystem().delegate;
    if (dos == null) {
      throw FileSystemException('Cannot check directory', path);
    }
    return await dos.exists(this);
  }

  /// 删除目录（异步）
  /// [recursive] - 是否递归删除子目录/文件（默认false，空目录才能删）
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    var dos = FileSystem().delegate;
    if (dos == null) {
      throw FileSystemException('Cannot remove directory', path);
    }
    return await dos.delete(this, recursive: recursive);
  }
}

// ------------------------------
//  文件系统委托接口 + 内存缓存实现
// ------------------------------

/// 文件系统委托接口（核心）
/// 定义文件系统操作的底层实现契约，可替换为不同实现（内存/本地/网络）
abstract interface class FileSystemDelegate {

  /// 检查实体是否存在
  Future<bool> exists(FileSystemEntity entity);

  /// 删除实体
  Future<FileSystemEntity> delete(FileSystemEntity entity, {bool recursive = false});

  // ---- File 相关方法 ----
  /// 创建文件
  Future<File> createFile(File file, {bool recursive = false, bool exclusive = false});

  /// 读取文件字节
  Future<Uint8List> readAsBytes(File file);

  /// 写入文件字节
  Future<File> writeAsBytes(File file, List<int> bytes,
      {FileMode mode = FileMode.write, bool flush = false});

  // ---- Directory 相关方法 ----
  /// 创建目录
  Future<Directory> createDirectory(Directory dir, {bool recursive = false});

  /// 列出目录子项
  Stream<FileSystemEntity> list(Directory dir,
      {bool recursive = false, bool followLinks = true});
}

/// 内存缓存版文件系统委托（FileSystemDelegate实现）
/// 所有文件内容存储在内存Map中，仅用于测试/临时存储，重启后数据丢失
class _FileCache implements FileSystemDelegate {
  /// 内存文件缓存：路径 → 字节数据
  final Map<String, Uint8List> _files = {};

  /// 检查实体是否存在
  /// 注：目录暂默认返回true，文件检查是否在_map中
  @override
  Future<bool> exists(FileSystemEntity entity) async {
    if (entity is Directory) {
      // TODO: 实现目录存在性检查
      return true;
    }
    return _files.containsKey(entity.path);
  }

  /// 删除实体
  /// 注：目录递归删除暂未实现，仅删除文件
  @override
  Future<FileSystemEntity> delete(FileSystemEntity entity, {bool recursive = false}) async {
    // TODO: 目录递归删除子项
    _files.remove(entity.path);
    return entity;
  }

  /// 创建文件（空实现，仅返回File对象）
  @override
  Future<File> createFile(File file, {bool recursive = false, bool exclusive = false}) async {
    // TODO: 实现空文件创建逻辑
    return file;
  }

  /// 读取文件字节（从内存Map中获取）
  @override
  Future<Uint8List> readAsBytes(File file) async {
    Uint8List? data = _files[file.path];
    if (data == null) {
      throw FileSystemException('File not found', file.toString());
    }
    return data;
  }

  /// 写入文件字节（存入内存Map）
  @override
  Future<File> writeAsBytes(File file, List<int> bytes,
      {FileMode mode = FileMode.write, bool flush = false}) async {
    _files[file.path] = Uint8List.fromList(bytes);
    return file;
  }

  /// 创建目录（空实现，仅返回Directory对象）
  @override
  Future<Directory> createDirectory(Directory dir, {bool recursive = false}) async {
    // TODO: 实现目录创建逻辑
    return dir;
  }

  /// 列出目录子项（仅列出内存中该目录下的文件）
  @override
  Stream<FileSystemEntity> list(Directory dir,
      {bool recursive = false, bool followLinks = true}) {
    // TODO: 实现子目录递归列出
    List<File> items = [];
    _files.forEach((path, data) {
      // 过滤出当前目录下的文件
      if (path.length > dir.path.length && path.substring(0, dir.path.length) == dir.path) {
        items.add(File(path));
      }
    });
    return Stream.fromIterable(items);
  }
}

/// 全局单例文件系统管理器
/// 提供统一的文件系统入口，可切换不同的FileSystemDelegate实现
class FileSystem {
  /// 工厂方法：返回单例实例
  factory FileSystem() => _instance;
  /// 单例对象
  static final FileSystem _instance = FileSystem._internal();
  /// 私有构造方法：禁止外部实例化
  FileSystem._internal();

  /// 文件系统委托实现（默认使用内存缓存版_FileCache）
  FileSystemDelegate? delegate = _FileCache();
}