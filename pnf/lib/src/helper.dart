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

import 'package:mkm/format.dart';  // 导入UTF8/Hex编解码工具

import 'crypto/digest.dart';  // 导入MD5哈希工具
import 'dos/paths.dart';      // 导入路径解析工具（文件名/扩展名提取）

/// URL/数据哈希文件名工具类
/// 提供基于URL/字节数据生成哈希文件名的能力，用于PNF文件的唯一标识和缓存
abstract class URLHelper {

  /// 从URL生成哈希文件名（避免重复下载/缓存）
  /// 规则：
  /// 1. 从URL/传入的文件名提取扩展名
  /// 2. 对URL做MD5哈希并转为16进制字符串
  /// 3. 最终文件名 = hex(md5(url)) + 扩展名
  /// [url] - 下载URL
  /// [filename] - 原始文件名（可选，用于提取扩展名）
  /// 返回值：String - 哈希后的文件名（如 "md5值.jpg"）
  static String filenameFromURL(Uri url, String? filename) {
    // 1. 从URL提取文件名和扩展名
    String? urlFilename = Paths.filename(url.toString());
    String? urlExt;
    if (urlFilename != null) {
      urlExt = Paths.extension(urlFilename);
      // 如果URL中的文件名已是哈希格式，直接返回
      if (_isEncoded(urlFilename, urlExt)) {
        return urlFilename;
      }
    }

    // 2. 从传入的文件名提取扩展名（优先级高于URL扩展名）
    String? ext;
    if (filename != null) {
      ext = Paths.extension(filename);
      // if (_isEncoded(filename, ext)) {
      //   // 传入的文件名已是哈希格式，直接返回
      //   return filename;
      // }
    }
    // 最终扩展名：传入文件名 > URL文件名
    ext ??= urlExt;

    // 3. 对URL做MD5哈希并生成文件名
    Uint8List data = UTF8.encode(url.toString()); // URL转为UTF8字节
    filename = Hex.encode(MD5.digest(data));      // MD5哈希+16进制编码
    // 拼接扩展名（无扩展名则直接返回哈希字符串）
    return ext == null || ext.isEmpty ? filename : '$filename.$ext';
  }

  /// 从字节数据生成哈希文件名（避免重复上传/缓存）
  /// 规则：
  /// 1. 从原始文件名提取扩展名
  /// 2. 对数据做MD5哈希并转为16进制字符串
  /// 3. 最终文件名 = hex(md5(data)) + 扩展名
  /// [data] - 文件字节数据
  /// [filename] - 原始文件名（用于提取扩展名）
  /// 返回值：String - 哈希后的文件名
  static String filenameFromData(Uint8List data, String filename) {
    // 1. 提取原始文件名的扩展名
    String? ext = Paths.extension(filename);
    // if (_isEncoded(filename, ext)) {
    //   // 已是哈希格式，直接返回
    //   return filename;
    // }

    // 2. 对数据做MD5哈希并生成文件名
    filename = Hex.encode(MD5.digest(data));
    // 拼接扩展名
    return ext == null || ext.isEmpty ? filename : '$filename.$ext';
  }

  /// 检查文件名是否为哈希格式（用于判断是否已加密/缓存）
  /// [filename] - 待检查的文件名
  /// 返回值：bool - true:是哈希格式，false:否
  static bool isFilenameEncoded(String filename) {
    String? ext = Paths.extension(filename);
    return _isEncoded(filename, ext);
  }

  /// 私有方法：核心判断逻辑
  /// 哈希格式要求：
  /// 1. 去除扩展名后长度为32位（MD5哈希的16进制长度）
  /// 2. 仅包含0-9/A-F/a-f字符（16进制）
  static bool _isEncoded(String filename, String? ext) {
    // 移除扩展名（如果有）
    if (ext != null/* && ext.isNotEmpty*/) {
      filename = filename.substring(0, filename.length - ext.length - 1);
    }
    // 校验长度和字符
    return filename.length == 32 && _hex.hasMatch(filename);
  }

  /// 16进制字符正则表达式（匹配0-9/A-F/a-f）
  static final _hex = RegExp(r'^[\dA-Fa-f]+$');

}