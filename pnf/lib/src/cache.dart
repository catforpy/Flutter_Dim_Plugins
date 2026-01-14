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

import 'dos/files.dart';   // 导入文件系统基础工具（Directory/File等）
import 'dos/paths.dart';   // 导入路径拼接工具
import 'external.dart';    // 导入ExternalStorage（文件读写）

/// 本地文件缓存管理器
/// 定义应用缓存目录、临时目录的规范，提供缓存文件路径生成、过期文件清理能力
abstract class FileCache {

  /// 获取应用缓存目录（受保护，不同平台路径不同）
  /// 用途：存储持久化缓存文件（如图片、音视频、元数据等）
  /// Android: "/sdcard/Android/data/chat.dim.sechat/cache"
  /// iOS: "/Application/{...}/Library/Caches"
  Future<String> get cachesDirectory;

  /// 获取应用临时目录（受保护，不同平台路径不同）
  /// 用途：存储临时文件（如上传中、下载中的加密文件）
  /// Android: "/data/data/chat.dim.sechat/cache"
  /// iOS: "/Application/{...}/tmp"
  Future<String> get temporaryDirectory;

  /// 生成缓存文件的存储路径（分层存储，避免单目录文件过多）
  /// [filename] - 加密后的文件名：hex(md5(data)) + 扩展名（如 "1234abcd.jpg"）
  /// 返回值：Future<String> - 完整路径 "{caches}/files/{AA}/{BB}/{filename}"
  /// 分层规则：取文件名前两位作为一级目录，3-4位作为二级目录
  Future<String> getCacheFilePath(String filename) async {
    // 校验文件名格式：扩展名位置需≥4位（确保前4位是MD5哈希）
    if (filename.indexOf('.') < 4) {
      assert(false, 'invalid filename: $filename');
      return Paths.append(await cachesDirectory, filename);
    }
    // 提取前两位和3-4位作为分层目录
    String aa = filename.substring(0, 2);
    String bb = filename.substring(2, 4);
    // 拼接完整路径：缓存目录/files/AA/BB/filename
    return Paths.append(await cachesDirectory, 'files', aa, bb, filename);
  }

  /// 生成上传文件的临时存储路径
  /// [filename] - 加密后的文件名：hex(md5(data)) + 扩展名
  /// 返回值：Future<String> - 完整路径 "{tmp}/upload/{filename}"
  Future<String> getUploadFilePath(String filename) async =>
      Paths.append(await temporaryDirectory, 'upload', filename);

  /// 生成下载文件的临时存储路径
  /// [filename] - 加密后的文件名：hex(md5(data)) + 扩展名
  /// 返回值：Future<String> - 完整路径 "{tmp}/download/{filename}"
  Future<String> getDownloadFilePath(String filename) async =>
      Paths.append(await temporaryDirectory, 'download', filename);

  /// 清理过期文件（避免缓存目录过大）
  /// [expired] - 过期时间：删除该时间点之前的文件
  /// 返回值：Future<int> - 成功删除的文件数量
  Future<int> burnAll(DateTime expired) async {
    // 1. 频率限制：15秒内仅执行一次，避免频繁清理
    DateTime now = DateTime.now();
    DateTime? last = _lastBurned;
    if (last != null) {
      int elapsed = now.millisecondsSinceEpoch - last.millisecondsSinceEpoch;
      if (elapsed < 15000) { // 15秒
        // 清理操作过于频繁，直接返回0
        return 0;
      }
    }
    // 更新最后清理时间
    _lastBurned = now;

    // 2. 清理缓存目录下的files子目录
    String path = Paths.append(await cachesDirectory, 'files');
    Directory dir = Directory(path);
    // 递归清理目录下的过期文件
    return await ExternalStorage.cleanupDirectory(dir, expired);
  }

  /// 最后一次清理过期文件的时间（用于频率限制）
  DateTime? _lastBurned;
}