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

// 导入Dio网络请求库（核心依赖）
import 'package:dio/dio.dart';

// 导入自定义类型工具类
import 'package:mkm/type.dart';

/// 简易HTTP客户端（专注于文件上传/下载）
/// 基于Dio封装，提供基础的文件上传、下载能力，包含失败重试限制、进度回调等特性
class HTTPClient{
  /// 构造方法
  /// [baseOptions] - Dio基础配置（如超时时间、基础URL等，可选）
  HTTPClient([this.baseOptions]);

  /// Dio基础配置（可全局设置超时、拦截器等）
  final BaseOptions? baseOptions;

  /// 下载失败检查器（限制短时间内重复失败的下载请求）
  DownloadChecker checker = DownloadChecker(timeout: Duration(minutes: 15));

  /// HTTP请求User-Agent头（标识客户端类型）
  String userAgent = 'DIMP/1.0 (Linux; U; Android 4.1; zh-CN)'
      ' DIMCoreKit/1.0 (Terminal, like WeChat)'
      ' DIM-by-GSP/1.3.1';

  // ------------------------------
  //  文件上传
  // ------------------------------

  /// 上传文件（异步）POST
  /// [url] - 上传目标URL（Uri类型）
  /// [data] - 表单数据（包含文件的FormData）
  /// [options] - 请求配置（如响应类型、请求头，可选）
  /// [onSendProgress] - 上传进度回调（count:已发送字节, total:总字节）
  /// 返回值：Future<Response<T>?> - 响应对象（失败返回null）
  Future<Response<T>?> upload<T>(Uri url, {
    FormData? data,
    Options? options,
    ProgressCallback? onSendProgress,
    // ProgressCallback? onReceiveProgress,
  }) async {
    try{
      // 创建Dio实例并执行post上传
      return await Dio(baseOptions).postUri<T>(url,
      data: data,
      options: options,
      onSendProgress: onSendProgress,
      // onReceiveProgress: onReceiveProgress,
      ).onError((error, stackTrace) {
        //Dio层错误捕获
        print('[DIO] failed to upload ${data?.files.length} file(s), ${data?.length} bytes'
            ' => "$url" error: $error, $stackTrace');
        throw Exception(error);
      });
    }catch(e,st){
      // 全局错误捕获，打印日志并返回null
      print('[HTTP] failed to upload ${data?.files.length} file(s), ${data?.length} bytes'
          ' => "$url" error: $e, $st');
      return null;
    }
  }

  /// 构建上传请求配置
  /// [responseType] - 响应类型（如plain/text、bytes等）
  /// 返回值：Options - 包含User-Agent的请求配置
  Options uploadOptions(ResponseType responseType) => Options(
    responseType: responseType,
    headers: {
      'User-Agent': userAgent,
    },
  );

  // ------------------------------
  //  文件下载
  // ------------------------------

  /// 下载文件（异步）GET
  /// [url] - 下载目标URL（Uri类型）
  /// [options] - 请求配置（如响应类型、请求头，可选）
  /// [onReceiveProgress] - 下载进度回调（count:已接收字节, total:总字节）
  /// 返回值：Future<Response<D>?> - 响应对象（失败返回null）
  Future<Response<D>?> download<D>(Uri url, {
    Options? options,
    ProgressCallback? onReceiveProgress,
  }) async{
    // 0. 检查失败超时：短时间内失败过的请求直接返回null，避免重复请求
    DateTime? expired = checker.checkFailure(url, options);
    if (expired != null) {
      print('[HTTP] cannot download: $url (headers: ${options?.headers}) now, please try again after $expired');
      return null;
    }
    try{
      // 1.执行下载请求（GET方法）
      return await Dio(baseOptions).getUri<D>(url,
      options: options,
      onReceiveProgress: onReceiveProgress,
      ).onError((error, stackTrace){
        // Dio层错误捕获
        print('[DIO] failed to download "$url" error: $error, $stackTrace');
        throw Exception(error);
      });
    }catch (e, st) {
      // 全局错误捕获，打印日志
      print('[HTTP] failed to download $url (headers: ${options?.headers}) error: $e, $st');
      // 2. 记录失败时间：标记该URL的失败时间，短时间内不再尝试
      checker.setFailure(url, options);
      return null;
    }
  }

  /// 构建下载请求配置
  /// [responseType] - 响应类型（如bytes、json等）
  /// 返回值：Options - 包含User-Agent的请求配置
  Options downloadOptions(ResponseType responseType) => Options(
    responseType: responseType,
    headers: {
      'User-Agent': userAgent,
    },
  );

  // ------------------------------
  //  工具方法
  // ------------------------------

  /// 解析URL字符串为Uri对象（带异常捕获）
  /// [url] - URL字符串（可选）
  /// [start/end] - 字符串截取范围（可选）
  /// 返回值：Uri? - 解析成功返回Uri，失败返回null
  static Uri? parseURL(String? url, [int start = 0, int? end]) {
    if (url == null) {
      return null;
    }
    try {
      return Uri.parse(url, start, end);
    } catch (e, st) {
      print('[HTTP] url error: $url, $e, $st');
      return null;
    }
  }

  /// 构建表单数据（单文件）
  /// [key] - 表单字段名
  /// [file] - 待上传的文件（MultipartFile）
  /// 返回值：FormData - 包含单个文件的表单数据
  static FormData buildFormData(String key, MultipartFile file) => FormData.fromMap({
    key: file,
  });

  /// 构建MultipartFile（从字节数据）
  /// [filename] - 文件名
  /// [data] - 文件字节数据
  /// 返回值：MultipartFile - 可用于上传的文件对象
  static MultipartFile buildMultipartFile(String filename, Uint8List data) => MultipartFile.fromBytes(
    data,
    filename: filename,
    // contentType: MediaType.parse('application/octet-stream'), // 可选：指定MIME类型
  );

  /// 从响应中获取内容长度（Content-Length头）
  /// [response] - Dio响应对象
  /// 返回值：int? - 内容长度（字节），解析失败返回null
  static int? getContentLength(Response response) {
    String? value = response.headers.value(Headers.contentLengthHeader);
    return Converter.getInt(value);
  }
}

/// 下载失败检查器
/// 用于限制短时间内重复失败的下载请求，避免无效请求占用资源
class DownloadChecker{
  /// 构造方法
  /// [timeout] - 失败后禁止重试的时长（默认15分钟）
  DownloadChecker({required this.timeout});

  /// 失败重试超时时间
  final Duration timeout;

  /// 失败记录：URL字符串 → 失败过期时间
  final Map<String, DateTime> failedTimes = {};

  /// 记录下载失败时间
  /// [url] - 失败的下载URL
  /// [options] - 请求配置（暂未使用，预留扩展）
  void setFailure(Uri url, Options? options) {
    DateTime expired = DateTime.now().add(timeout);
    failedTimes[url.toString()] = expired;
  }

  /// 检查下载是否被限制（失败未过期）
  /// [url] - 待检查的下载URL
  /// [options] - 请求配置（暂未使用，预留扩展）
  /// 返回值：DateTime? - 未过期返回过期时间，已过期/无记录返回null
  DateTime? checkFailure(Uri url, Options? options) {
    DateTime? expired = failedTimes[url.toString()];
    if (expired == null) {
      // 无失败记录：首次尝试
      return null;
    } else if (DateTime.now().isAfter(expired)) {
      // 失败记录已过期：可以重试
      return null;
    }
    // 失败记录未过期：禁止重试
    return expired;
  }
}