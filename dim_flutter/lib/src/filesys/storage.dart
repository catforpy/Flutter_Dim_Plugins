/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
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


import 'package:dim_client/ok.dart';
import 'package:dim_client/pnf.dart' hide NotificationNames;
import 'package:dim_flutter/src/ui/nav.dart';

import '../common/constants.dart';
import '../sqlite/helper/connector.dart';

import 'local.dart';

/// 缓存文件管理器（单例）
/// 负责扫描和清理应用内各类缓存文件，包括数据库文件、头像缓存、文件缓存、上传/下载临时文件
class CacheFileManager {
  /// 工厂方法：获取单例实例
  factory CacheFileManager() => _instance;
  /// 静态单例实例
  static final CacheFileManager _instance = CacheFileManager._internal();
  /// 私有构造方法：初始化扫描器和清理器
  CacheFileManager._internal() {
    _init();
  }

  /// 数据库目录扫描器（3个不同数据库目录）
  _FileScanner? _db1Scanner;
  _FileScanner? _db2Scanner;
  _FileScanner? _db3Scanner;

  /// 各类缓存目录扫描器
  _FileScanner? _avatarScanner;   // 头像缓存扫描器
  _FileScanner? _cachesScanner;   // 文件缓存扫描器
  _FileScanner? _uploadScanner;   // 上传文件扫描器
  _FileScanner? _downloadScanner; // 下载文件扫描器

  /// 各类缓存目录清理器
  _FileCleaner? _avatarCleaner;   // 头像缓存清理器
  _FileCleaner? _cachesCleaner;   // 文件缓存清理器
  _FileCleaner? _uploadCleaner;   // 上传文件清理器
  _FileCleaner? _downloadCleaner; // 下载文件清理器

  /// 初始化扫描器和清理器
  void _init() async {
    LocalStorage local = LocalStorage();
    String caches = await local.cachesDirectory;    // 缓存根目录
    String tmp = await local.temporaryDirectory;    // 临时目录
    String dbDir1 = await DBPath.getDatabaseDirectory(null);  // 数据库目录1
    String dbDir2 = await DBPath.getDatabaseDirectory('.dkd'); // 数据库目录2
    String dbDir3 = await DBPath.getDatabaseDirectory('.dim'); // 数据库目录3
    
    // 创建数据库目录扫描器
    _db1Scanner = _FileScanner(dbDir1);
    _db2Scanner = _FileScanner(dbDir2);
    _db3Scanner = _FileScanner(dbDir3);
    
    // 创建缓存目录扫描器和清理器
    _avatarCleaner = _FileCleaner(_avatarScanner = _FileScanner(Paths.append(caches, 'avatar')));
    _cachesCleaner = _FileCleaner(_cachesScanner = _FileScanner(Paths.append(caches, 'files')));
    _uploadCleaner = _FileCleaner(_uploadScanner = _FileScanner(Paths.append(tmp, 'upload')));
    _downloadCleaner = _FileCleaner(_downloadScanner = _FileScanner(Paths.append(tmp, 'download')));
  }

  /// 判断是否正在刷新（扫描）缓存文件
  bool get refreshing => _db1Scanner?._refreshing == true
      || _db2Scanner?._refreshing == true
      || _db3Scanner?._refreshing == true
      || _avatarScanner?._refreshing == true
      || _cachesScanner?._refreshing == true
      || _uploadScanner?._refreshing == true
      || _downloadScanner?._refreshing == true;

  /// 获取数据库文件汇总信息（文件数+总大小）
  String get dbSummary {
    int count = 0;
    count += _db1Scanner?._count ?? 0;
    count += _db2Scanner?._count ?? 0;
    count += _db3Scanner?._count ?? 0;
    int size = 0;
    size += _db1Scanner?._size ?? 0;
    size += _db2Scanner?._size ?? 0;
    size += _db3Scanner?._size ?? 0;
    return _summary(count: count, size: size);
  }
  
  /// 获取头像缓存汇总信息
  String get avatarSummary => _avatarScanner?.summary ?? '';
  /// 获取文件缓存汇总信息
  String get cacheSummary => _cachesScanner?.summary ?? '';
  /// 获取上传文件汇总信息
  String get uploadSummary => _uploadScanner?.summary ?? '';
  /// 获取下载文件汇总信息
  String get downloadSummary => _downloadScanner?.summary ?? '';

  /// 获取所有缓存文件总大小（可读格式）
  String get summary {
    int size = 0;
    size += _db1Scanner?._size ?? 0;
    size += _db2Scanner?._size ?? 0;
    size += _db3Scanner?._size ?? 0;
    size += _avatarScanner?._size ?? 0;
    size += _cachesScanner?._size ?? 0;
    size += _uploadScanner?._size ?? 0;
    size += _downloadScanner?._size ?? 0;
    return _readableSize(size);
  }

  /// 扫描所有缓存目录
  void scanAll() {
    _db1Scanner?.scan();
    _db2Scanner?.scan();
    _db3Scanner?.scan();
    _avatarScanner?.scan();
    _cachesScanner?.scan();
    _uploadScanner?.scan();
    _downloadScanner?.scan();
  }

  /// 清理头像缓存
  void cleanAvatars() => _avatarCleaner?.clean();
  /// 清理文件缓存
  void cleanCaches() => _cachesCleaner?.clean();
  /// 清理上传文件
  void cleanUploads() => _uploadCleaner?.clean();
  /// 清理下载文件
  void cleanDownloads() => _downloadCleaner?.clean();
}

/// 文件清理器内部类
/// 用于清理指定目录下的所有文件
class _FileCleaner with Logging {

  /// 构造方法
  /// [_scanner] - 关联的文件扫描器
  _FileCleaner(this._scanner);

  final _FileScanner _scanner;

  /// 清理中标记（避免并发清理）
  bool _cleaning = false;

  /// 执行清理操作
  void clean() async {
    if(_cleaning){
      return;
    }
    _cleaning = true;
    await run();
    _cleaning = false;
    // 清理完成后重新扫描
    _scanner.scan();
  }

  /// 执行实际清理逻辑（保护方法）
  Future<void> run() async {
    String root = _scanner._root;
    try {
      await _cleanDir(Directory(root));
    } catch (e, st) {
      logError('failed to clean directory: $root, $e, $st');
    }
  }

  /// 递归清理目录（包括子目录）
  Future<void> _cleanDir(Directory dir) async {
    logInfo('cleaning directory: $dir');
    Stream<FileSystemEntity> files = dir.list();
    await files.forEach((item) async {
      // 遍历目录下所有项（不包含.和..）
      if (item is Directory) {
        // 递归清理子目录
        await _cleanDir(item);
      } else if (item is File) {
        // 删除文件
        try {
          logWarning('deleting cache file: $item');
          // await item.delete();
          await Paths.delete(item.path);
        } catch (e, st) {
          logError('failed to check file: $item, $e, $st');
        }
      } else {
        // 忽略链接文件
        assert(false, 'ignore link: $item');
      }
    });
  }
}

/// 文件扫描器内部类
/// 用于扫描指定目录下的文件，统计文件数量和总大小
class _FileScanner with Logging {
  /// 构造方法
  /// [_root] - 要扫描的根目录
  _FileScanner(this._root);

  final String _root;

  /// 扫描到的文件综述
  int _count = 0;
  /// 扫描到的文件总大小（字节）
  int _size = 0;

  /// 扫描中标记（避免并发扫描）
  bool _refreshing = false;

  /// 获取扫描结果汇总信息
  String get summary => _summary(count: _count, size: _size);

  /// 执行扫描操作
  void scan() async {
    if (_refreshing) {
      return;
    } else {
      // 重置统计数据
      _count = 0;
      _size = 0;
    }
    _refreshing = true;
    await run();
    _refreshing = false;
    // 发送扫描完成通知
    var nc = NotificationCenter();
    await nc.postNotification(NotificationNames.kCacheScanFinished, this, {
      'root': _root,
    });
  }

  /// 执行实际扫描逻辑（保护方法）
  Future<void> run() async {
    try {
      await _scanDir(Directory(_root));
    } catch (e, st) {
      logError('failed to scan directory: $_root, $e, $st');
    }
  }

  /// 递归扫描目录（包括子目录）
  Future<void> _scanDir(Directory dir) async {
    logInfo('scanning directory: $dir');
    Stream<FileSystemEntity> files = dir.list();
    await files.forEach((item) async {
      // 遍历目录下所有项（不包含.和..）
      if (item is Directory) {
        // 递归扫描子目录
        await _scanDir(item);
      } else if (item is File) {
        // 检查文件大小并统计
        try {
          await _checkFile(item);
        } catch (e, st) {
          logError('failed to check file: $item, $e, $st');
        }
      } else {
        // 忽略链接文件
        assert(false, 'ignore link: $item');
      }
    });
  }

  /// 检查单个文件并更新统计数据
  Future<bool> _checkFile(File file) async {
    int length = await file.length();
    if (length < 0) {
      logError('file error: $file, $length');
      return false;
    }
    // 更新统计数据
    _count += 1;
    _size += length;
    // 发送文件找到通知
    var nc = NotificationCenter();
    await nc.postNotification(NotificationNames.kCacheFileFound, this, {
      'root': _root,
      'path': file.path,
      'length': length,
    });
    return true;
  }
}

/// 生成文件统计汇总文本（支持国际化）
/// [count] - 文件数量
/// [size] - 文件总大小（字节）
/// @return 格式化的汇总文本
String _summary({required int count, required int size}) {
  String text = _readableSize(size);
  if (count < 2) {
    return i18nTranslator.translate('Contains @count file, totaling @size',
    params: {
      'count': '$count',
      'size': text,
    });
  }
  return i18nTranslator.translate('Contains @count files, totaling @size',
  params: {
    'count': '$count',
    'size': text,
  });
}

/// 将字节数转换为可读的文件大小格式（KB/MB/GB/TB）
/// [size] - 字节数
/// @return 可读格式的文件大小
String _readableSize(int size) {
  if (size < 2) {
    return '$size byte';
  } else if (size < kiloBytes) {
    return '$size bytes';
  }
  int cnt;
  String uni;
  if (size < megaBytes) {
    cnt = kiloBytes;
    uni = 'KB';
  } else if (size < gigaBytes) {
    cnt = megaBytes;
    uni = 'MB';
  } else if (size < teraBytes) {
    cnt = gigaBytes;
    uni = 'GB';
  } else {
    cnt = teraBytes;
    uni = 'TB';
  }
  double num = size.toDouble() / cnt;
  return '${num.toStringAsFixed(1)} $uni';
}

/// 文件大小单位常量定义
const int kiloBytes = 1024;          // 1KB = 1024字节
const int megaBytes = 1024 * kiloBytes; // 1MB = 1024KB
const int gigaBytes = 1024 * megaBytes; // 1GB = 1024MB
const int teraBytes = 1024 * gigaBytes; // 1TB = 1024GB