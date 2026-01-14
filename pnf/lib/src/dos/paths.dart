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

import 'package:path/path.dart' as utils;

// 导入文件系统核心类
import 'files.dart';

/// 路径工具类
/// 封装路径拼接、解析、规范化等通用操作，适配多平台（Windows/Linux/Web）
class Paths {
  /// 拼接路径组件（支持多参数）
  /// [a] - 根路径
  /// [b/c/d/e] - 子路径/文件名（可选）
  /// 返回值：拼接后的完整路径
  /// 示例：append('/root', 'dir', 'file.txt') → /root/dir/file.txt
  static String append(String a, [String? b, String? c, String? d, String? e]) {
    return utils.join(a, b, c, d, e);
  }

  /// 从路径/URL中提取文件名
  /// [path] - 路径/URL字符串
  /// 返回值：文件名（含扩展名）
  /// 示例：filename('/root/dir/file.txt') → file.txt
  static String? filename(String path) {
    return utils.basename(path);
  }

  /// 从文件名中提取扩展名（不带.）
  /// [filename] - 文件名（含扩展名）
  /// 返回值：扩展名（无则返回null）
  /// 示例：extension('file.txt') → txt；extension('file') → null
  static String? extension(String filename) {
    String ext = utils.extension(filename);
    return ext.isEmpty ? null : trimExtension(ext);
  }

  /// 清理扩展名中的多余.
  /// [ext] - 原始扩展名（如.txt、..pdf、jpg.）
  /// 返回值：清理后的扩展名（如txt、pdf、jpg）
  static String trimExtension(String ext) {
    int start = 0, end = ext.length;
    // 跳过开头的.
    for (; start < ext.length; ++start) {
      if (ext.codeUnitAt(start) != dot) {
        break;
      }
    }
    // 跳过结尾的.
    for (; end > 0; --end) {
      if (ext.codeUnitAt(end - 1) != dot) {
        break;
      }
    }
    // 无多余.则返回原字符串
    if (0 == start && end == ext.length) {
      return ext;
    }
    return ext.substring(start, end);
  }

  /// .的ASCII码（用于快速比较）
  static final int dot = '.'.codeUnitAt(0);

  /// 获取路径的父目录
  /// [path] - 任意路径
  /// 返回值：父目录路径
  /// 示例：parent('/root/dir/file.txt') → /root/dir
  static String? parent(String path) {
    return utils.dirname(path);
  }

  /// 将相对路径转换为绝对路径
  /// [relative] - 相对路径
  /// [base] - 基准目录（必填）
  /// 返回值：绝对路径
  /// 示例：abs('file.txt', base: '/root/dir') → /root/dir/file.txt
  static String abs(String relative, {required String base}) {
    // 已为绝对路径（Linux/Windows/URL），直接返回
    if (relative.startsWith('/') || relative.indexOf(':') > 0) {
      return relative;
    }
    // 拼接基准目录和相对路径
    String path;
    if (base.endsWith('/') || base.endsWith('\\')) {
      path = base + relative;
    } else {
      String separator = base.contains('\\') ? '\\' : '/';
      path = base + separator + relative;
    }
    // 清理相对路径组件（./、../）
    if (path.contains('./')) {
      return tidy(path, separator: '/');
    } else if (path.contains('.\\')) {
      return tidy(path, separator: '\\');
    } else {
      return path;
    }
  }

  /// 清理路径中的相对组件（./、../）
  /// [path] - 原始路径
  /// [separator] - 路径分隔符（/或\）
  /// 返回值：规范化后的路径
  static String tidy(String path, {required String separator}) {
    path = utils.normalize(path);
    // 统一分隔符
    if (separator == '/' && path.contains('\\')) {
      path = path.replaceAll('\\', '/');
    }
    return path;
  }

  // ---- 文件操作快捷方法 ----

  /// 检查文件是否存在（快捷方法）
  /// [path] - 文件路径
  /// 返回值：Future<bool> - 存在返回true
  static Future<bool> exists(String path) async {
    File file = File(path);
    return await file.exists();
  }

  /// 创建目录（递归创建，快捷方法）
  /// [path] - 目录路径
  /// 返回值：Future<bool> - 创建成功返回true
  static Future<bool> mkdirs(String path) async {
    Directory dir = Directory(path);
    await dir.create(recursive: true);
    return await dir.exists();
  }

  /// 删除文件（快捷方法）
  /// [path] - 文件路径
  /// 返回值：Future<bool> - 始终返回true（兼容不存在的情况）
  static Future<bool> delete(String path) async {
    File file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    return true;
  }
}