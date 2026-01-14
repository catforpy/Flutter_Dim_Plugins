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

import 'package:dio/dio.dart'; // 导入FormData/MultipartFile

// ------------------------------
//  下载相关定义
// ------------------------------

/// 下载参数
/// 封装下载的核心参数（仅URL），重写相等性判断便于去重
class DownloadInfo {

  /// 构造方法
  /// [url] - 下载目标URL
  DownloadInfo(this.url);

  /// 下载目标URL
  final Uri url;

  /// 字符串描述（URL）
  @override
  String toString() => url.toString();

  /// 相等性判断：URL相同则视为同一参数
  @override
  bool operator ==(Object other) {
    if (other is DownloadInfo) {
      if (identical(this, other)) {
        // 同一对象
        return true;
      }
      return other.url == url;
    } else if (other is Uri) {
      return other == url;
    } else {
      return false;
    }
  }

  /// 哈希值：基于URL计算
  @override
  int get hashCode => url.hashCode;
}

/// 下载优先级常量
class DownloadPriority {
  // ignore_for_file: constant_identifier_names

  /// 紧急优先级（数值越小优先级越高）
  static const int URGENT = -7;
  /// 普通优先级
  static const int NORMAL =  0;
  /// 低速优先级（数值越大优先级越低）
  static const int SLOWER =  7;
}

/// 下载任务抽象接口
/// 定义下载任务的核心能力：优先级、参数、生命周期回调
abstract interface class DownloadTask {
  /// 获取任务优先级（越小优先级越高）
  int get priority;

  /// 获取下载参数（URL）
  DownloadInfo? get downloadParams;

  /// 准备任务（异步）
  /// 作用：检查缓存、前置条件等，判断是否需要下载
  /// 返回值：bool - true:需要下载（加入队列），false:无需下载（如缓存已存在）
  Future<bool> prepareDownload();

  /// 下载进度回调（异步）
  /// [count] - 已下载字节数
  /// [total] - 总字节数（-1表示未知）
  Future<void> downloadProgress(int count, int total);

  /// 下载完成/失败回调（异步）
  /// [data] - 下载到的字节数据（null表示失败）
  Future<void> processResponse(Uint8List? data);
}

// ------------------------------
//  上传相关定义
// ------------------------------

/// 上传参数
/// 封装上传的核心参数（URL+表单数据），重写相等性判断便于去重
class UploadInfo {
  /// 构造方法
  /// [url] - 上传目标URL
  /// [data] - 表单数据（包含文件）
  UploadInfo(this.url, this.data);

  /// 上传目标URL
  final Uri url;
  /// 表单数据（包含文件）
  final FormData data;

  /// 字符串描述（URL+数据大小）
  @override
  String toString() => '<$runtimeType url="$url" size=${data.length} />';

  /// 相等性判断：URL+表单数据均相同则视为同一参数
  @override
  bool operator ==(Object other) {
    if (other is UploadInfo) {
      if (identical(this, other)) {
        // 同一对象
        return true;
      }
      return other.url == url && _FormUtils.checkData(other.data, data);
    } else {
      return false;
    }
  }

  /// 哈希值：基于URL+表单数据计算
  @override
  int get hashCode => url.hashCode + _FormUtils.hashData(data) * 13;
}

/// 表单数据工具类（内部接口）
/// 提供表单数据的相等性判断、哈希计算
abstract interface class _FormUtils {
  /// 计算表单数据哈希值
  static int hashData(FormData data) {
    return data.hashCode;
  }

  /// 检查两个表单数据是否相等
  /// [a/b] - 待比较的表单数据
  /// 返回值：bool - true:相等，false:不相等
  static bool checkData(FormData a, FormData b) {
    if (identical(a, b)) {
      // 同一对象
      return true;
    }
    // 检查字段和文件均相等
    return checkFields(a.fields, b.fields) && checkFiles(a.files, b.files);
  }

  /// 检查表单字段列表是否相等
  static bool checkFields(List<MapEntry<String, String>> a, List<MapEntry<String, String>> b) {
    if (identical(a, b)) {
      return true;
    } else if (a.length != b.length) {
      return false;
    }
    // 遍历a的所有字段，检查是否都在b中存在
    for (var item in a) {
      if (containsField(item, b)) {
        continue;
      } else {
        return false;
      }
    }
    return true;
  }

  /// 检查表单文件列表是否相等
  static bool checkFiles(List<MapEntry<String, MultipartFile>> a, List<MapEntry<String, MultipartFile>> b) {
    if (identical(a, b)) {
      return true;
    } else if (a.length != b.length) {
      return false;
    }
    // 遍历a的所有文件，检查是否都在b中存在
    for (var item in a) {
      if (containsFile(item, b)) {
        continue;
      } else {
        return false;
      }
    }
    return true;
  }

  /// 检查字段是否在列表中存在
  static bool containsField(MapEntry<String, String> field, List<MapEntry<String, String>> array) {
    for (var item in array) {
      if (item.key == field.key && item.value == field.value) {
        return true;
      }
    }
    return false;
  }

  /// 检查文件是否在列表中存在
  static bool containsFile(MapEntry<String, MultipartFile> file, List<MapEntry<String, MultipartFile>> array) {
    for (var item in array) {
      if (item.key == file.key && checkMultipartFile(item.value, file.value)) {
        return true;
      }
    }
    return false;
  }

  /// 检查两个MultipartFile是否相等
  /// 注：此处通过文件名+长度判断（文件名是MD5编码，可唯一标识文件）
  static bool checkMultipartFile(MultipartFile a, MultipartFile b) {
    if (a.filename != b.filename) {
      return false;
    } else if (a.length != b.length) {
      return false;
    }
    // TODO: 可选：对比文件字节数据（性能较低，此处省略）
    // 文件名是MD5(file_data).ext，因此文件名相等则数据相等
    return true;
  }
}

/// 上传任务抽象接口
/// 定义上传任务的核心能力：参数、生命周期回调
abstract interface class UploadTask {
  /// 获取上传参数（URL+表单数据）
  UploadInfo? get uploadParams;

  /// 准备任务（异步）
  /// 作用：检查重复任务、前置条件等，判断是否需要上传
  /// 返回值：bool - true:需要上传（加入队列），false:无需上传（如已上传）
  Future<bool> prepareUpload();

  /// 上传进度回调（异步）
  /// [count] - 已上传字节数
  /// [total] - 总字节数（-1表示未知）
  Future<void> uploadProgress(int count, int total);

  /// 上传完成/失败回调（异步）
  /// [response] - 服务器响应字符串（null表示失败）
  Future<void> processResponse(String? response);
}