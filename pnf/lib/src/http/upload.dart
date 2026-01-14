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

import 'package:dio/dio.dart';
import 'package:object_key/object_key.dart'; // 弱引用列表依赖
import 'package:startrek/skywalker.dart';   // 导入Runner/线程相关工具

import 'client.dart';  // 导入HTTPClient
import 'tasks.dart';   // 导入UploadTask/UploadInfo

/// HTTP上传器抽象接口
/// 定义上传器核心能力：添加任务、启动后台上传
abstract interface class Uploader {
  /// 添加上传任务
  /// [task] - 上传任务（实现UploadTask接口）
  /// 返回值：Future<bool> - 是否成功加入队列（true:加入，false:无需上传）
  Future<bool> addTask(UploadTask task);

  /// 启动后台上传线程
  void start();
}

/// 文件上传器（Uploader实现，继承Runner）
/// 基于单线程队列的上传器，自动管理上传任务，避免重复上传
class FileUploader extends Runner implements Uploader {
  /// 构造方法
  /// [client] - HTTP客户端（提供基础上传能力）
  /// 父类构造：设置轮询间隔（慢轮询×4）
  FileUploader(this.client) : super(Runner.INTERVAL_SLOW * 4);

  /// 基础HTTP客户端
  final HTTPClient client;

  /// 上传任务队列（弱引用列表，避免内存泄漏）
  final List<UploadTask> _tasks = WeakList();

  /// 添加上传任务到队列
  @override
  Future<bool> addTask(UploadTask task) async {
    // 准备任务：检查重复/前置条件，返回是否需要加入队列
    var waiting = await task.prepareUpload();
    if (waiting) {
      _tasks.add(task); // 加入队列
    }
    return waiting;
  }

  /// 获取下一个待执行的上传任务
  /// 返回值：UploadTask? - 待执行任务，无则返回null
  UploadTask? getTask() {
    if (_tasks.isNotEmpty) {
      return _tasks.removeAt(0); // 移除并返回队列第一个任务（FIFO）
    }
    return null;
  }

  /// 移除并处理相同参数的任务（避免重复上传）
  /// [task] - 已完成的任务
  /// [response] - 服务器响应字符串（可为null）
  /// 返回值：Future<int> - 处理成功的任务数量
  Future<int> removeTasks(UploadTask task, String? response) async {
    // 获取当前任务的上传参数（URL+表单数据）
    UploadInfo? params = task.uploadParams;
    if (params == null) {
      assert(false, 'upload task error: $task');
      return -1;
    }
    UploadInfo? uploadParams;
    int success = 0; // 成功处理的任务数
    List<UploadTask> array = _tasks.toList(); // 复制列表，避免遍历中修改原列表

    // 遍历所有任务
    for (UploadTask item in array) {
      // 0. 检查是否为同一任务：直接移除
      if (identical(item, task)) {
        _tasks.remove(item);
        success += 1;
        continue;
      }

      // 1. 准备任务参数：检查是否需要上传
      uploadParams = null;
      try {
        if (await item.prepareUpload()) {
          uploadParams = item.uploadParams;
          assert(uploadParams != null, 'upload params error: $item');
        }
      } catch (e, st) {
        print('[HTTP] failed to prepare upload task: $item, error: $e, $st');
      }
      if (uploadParams != params) {
        // 参数不同（URL/表单数据不同），跳过
        assert(uploadParams != null, 'upload params error: $item');
        continue;
      }

      // 2. 处理相同参数的任务：复用上传响应
      try {
        await item.processResponse(response);
        success += 1;
      } catch (e, st) {
        print('[HTTP] failed to handle response: ${response?.length} bytes, $params, error: $e, $st');
      }

      // 3. 从队列移除该任务
      _tasks.remove(item);
    }
    return success;
  }

  /// 启动上传器：启动后台线程
  @override
  void start() {
    /*await */run(); // 非阻塞启动线程
  }

  /// 线程核心处理逻辑（循环执行）
  /// 返回值：Future<bool> - true:继续循环，false:休眠等待
  @override
  Future<bool> process() async {
    // 1. 获取下一个任务
    UploadTask? next = getTask();
    if (next == null) {
      // 无任务：返回false，线程休眠
      return false;
    }
    // 2. 执行任务
    try {
      await handleUploadTask(next);
    } catch (e, st) {
      print('[HTTP] failed to process upload task: $e, $next, $st');
      return false; // 执行失败：返回false，休眠
    }
    // 3. 任务完成：返回true，立即执行下一个任务
    return true;
  }

  /// 同步处理上传任务（核心逻辑）
  /// [task] - 待处理的上传任务
  /// 返回值：Future<String?> - 服务器响应字符串（失败返回null）
  Future<String?> handleUploadTask(UploadTask task) async {
    // 0. 准备任务：获取上传参数（URL+表单数据）
    UploadInfo? params;
    try {
      if (await task.prepareUpload()) {
        params = task.uploadParams;
        assert(params != null, 'upload params error: $task');
      }
    } catch (e, st) {
      print('[HTTP] failed to prepare upload task: $task, error: $e, $st');
    }
    if (params == null) {
      // 任务无需上传（如已上传），直接返回null
      return null;
    }

    // 1. 执行上传：上传表单数据到远程URL
    String? text = await upload(params.url, params.data,
      onSendProgress: (count, total) => task.uploadProgress(count, total), // 进度回调
    );

    // 2. 处理响应数据：任务完成后的回调（如记录上传结果）
    try {
      await task.processResponse(text);
    } catch (e, st) {
      print('[HTTP] failed to handle response: ${text?.length} bytes, $params, error: $e, $st');
    }

    // 3. 清理相同任务：移除队列中相同参数的任务，避免重复上传
    if (text == null) {
      // FIXME: 上传失败是否重试？暂不处理
      // return null;
    }
    await removeTasks(task, text);

    // 完成：返回服务器响应
    return text;
  }

  /// 上传表单数据（封装HTTPClient的upload方法）
  /// [url] - 上传URL
  /// [data] - 表单数据（包含文件）
  /// [onSendProgress] - 上传进度回调
  /// 返回值：Future<String?> - 服务器响应字符串（失败返回null）
  Future<String?> upload(Uri url, FormData data, {
    ProgressCallback? onSendProgress,
    // ProgressCallback? onReceiveProgress,
  }) async {
    // 构建上传配置：响应类型为纯文本
    var options = client.uploadOptions(ResponseType.plain);
    // 执行上传
    Response<String>? response = await client.upload(url,
      data: data,
      options: options,
      onSendProgress: onSendProgress,
      // onReceiveProgress: onReceiveProgress,
    );
    // 检查响应状态：仅200 OK视为成功
    int? statusCode = response?.statusCode;
    if (response == null || statusCode != 200) {
      assert(false, 'failed to upload $url, status: $statusCode - ${response?.statusMessage}');
      return null;
    }
    // 检查响应内容
    String? text = response.data;
    if (text == null || text.isEmpty) {
      assert(false, 'response text error: $response');
    }
    // 返回响应字符串
    return text;
  }
}