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

import 'package:mkm/format.dart';  // 导入UTF8/JSON编解码工具

import 'dos/files.dart';    // 导入文件系统基础工具（Directory/File等）
import 'dos/storage.dart';  // 导入Storage（文件读写核心类）

/// 外部存储工具类（静态方法）
/// 提供文件的二进制/文本/JSON读写、过期文件清理能力，封装底层Storage操作
abstract class ExternalStorage {
  // ------------------------------
  //  文件读取
  // ------------------------------

  /// 私有方法：从文件加载字节数据
  /// [path] - 文件路径
  /// 返回值：Future<Uint8List?> - 字节数据（读取失败返回null）
  static Future<Uint8List?> _load(String path) async {
    Storage file = Storage();
    // 调用Storage的read方法，返回值<0表示读取失败
    if (await file.read(path) < 0) {
      return null;
    }
    // 返回读取到的字节数据
    return file.data;
  }

  /// 从文件加载二进制数据（对外暴露）
  /// [path] - 文件路径
  /// 返回值：Future<Uint8List?> - 字节数据（失败返回null）
  static Future<Uint8List?> loadBinary(String path) async =>
      await _load(path);

  /// 从文件加载文本数据（UTF8编码）
  /// [path] - 文件路径
  /// 返回值：Future<String?> - 文本内容（失败返回null）
  static Future<String?> loadText(String path) async {
    Uint8List? data = await _load(path);
    if (data == null) {
      return null;
    }
    // 解码UTF8字节为字符串
    String? text = UTF8.decode(data);
    assert(text != null, 'Text file error: $path, size: ${data.length}');
    return text;
  }

  /// 从文件加载JSON数据（UTF8+JSON解码）
  /// [path] - 文件路径
  /// 返回值：Future<dynamic> - Map/List对象（失败返回null）
  static Future<dynamic> loadJson(String path) async {
    Uint8List? data = await _load(path);
    if (data == null) {
      return null;
    }
    // 先解码UTF8，再解析JSON
    String? text = UTF8.decode(data);
    if (text == null) {
      assert(false, 'JsON file error: $path, size: ${data.length}');
      return null;
    }
    return JSON.decode(text);
  }

  /// 便捷方法：加载JSON并转为Map
  static Future<Map?> loadJsonMap(String path) async =>
      await loadJson(path);

  /// 便捷方法：加载JSON并转为List
  static Future<List?> loadJsonList(String path) async =>
      await loadJson(path);

  // ------------------------------
  //  文件写入
  // ------------------------------

  /// 私有方法：将字节数据写入文件
  /// [data] - 待写入的字节数据
  /// [path] - 文件路径
  /// 返回值：Future<int> - 写入的字节数（失败返回-1）
  static Future<int> _save(Uint8List data, String path) async {
    Storage file = Storage();
    file.data = data; // 设置待写入的数据
    try {
      // 调用Storage的write方法，返回写入的字节数
      return await file.write(path);
    } catch (e, st) {
      // 捕获异常并打印日志
      print('[DOS] failed to save file: $path, $e, $st');
      return -1;
    }
  }

  /// 将二进制数据写入文件（对外暴露）
  /// [data] - 字节数据
  /// [path] - 文件路径
  /// 返回值：Future<int> - 写入的字节数（失败返回-1）
  static Future<int> saveBinary(Uint8List data, String path) async =>
      await _save(data, path);

  /// 将文本写入文件（UTF8编码）
  /// [text] - 文本内容
  /// [path] - 文件路径
  /// 返回值：Future<int> - 写入的字节数（失败返回-1）
  static Future<int> saveText(String text, String path) async {
    // 编码文本为UTF8字节
    Uint8List data = UTF8.encode(text);
    return await _save(data, path);
  }

  /// 将Map/List写入JSON文件（JSON+UTF8编码）
  /// [container] - Map/List对象
  /// [path] - 文件路径
  /// 返回值：Future<int> - 写入的字节数（失败返回-1）
  static Future<int> saveJson(Object container, String path) async {
    // 先编码为JSON字符串，再转为UTF8字节
    String text = JSON.encode(container);
    Uint8List data = UTF8.encode(text);
    return await _save(data, path);
  }

  /// 便捷方法：写入Map为JSON文件
  static Future<int> saveJsonMap(Map container, String path) async =>
      await saveJson(container, path);

  /// 便捷方法：写入List为JSON文件
  static Future<int> saveJsonList(List container, String path) async =>
      await saveJson(container, path);

  // ------------------------------
  //  文件清理
  // ------------------------------

  /// 递归清理目录下的过期文件
  /// [dir] - 根目录
  /// [expired] - 过期时间：删除该时间点之前修改的文件
  /// 返回值：Future<int> - 成功删除的文件数量
  static Future<int> cleanupDirectory(Directory dir, DateTime expired) async{
    int total = 0;  // 累计删除的文件数
    // 遍历目录下的所有实体（文件/目录/链接）
    Stream<FileSystemEntity> files = dir.list();
    await files.forEach((item) async {
      if (item is Directory) {
        // 递归清理子目录
        total += await cleanupDirectory(item, expired);
      } else if (item is! File) {
        // 忽略非文件实体（如链接）
        assert(false, 'ignore link: $item');
      } else if (await cleanupFile(item, expired)) {
        // 文件已过期，成功删除则计数+1
        total += 1;
      }
    });
    return total;
  }

  /// 清理单个过期文件
  /// [file] - 待检查的文件
  /// [expired] - 过期时间
  /// 返回值：Future<bool> - true:文件已过期并删除，false:文件未过期
  static Future<bool> cleanupFile(File file, DateTime expired) async {
    // 获取文件最后修改时间
    DateTime last = await file.lastModified();
    if (last.isAfter(expired)) {
      // 文件未过期，返回false
      return false;
    }
    // 文件已过期，执行删除（捕获异常避免崩溃）
    await file.delete().onError((error, stackTrace) {
      print('[DOS] failed to delete file: ${file.path}, $error, $stackTrace');
      return file;
    });
    return true;
  }
}