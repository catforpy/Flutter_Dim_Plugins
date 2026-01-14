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

import 'package:dio/dio.dart';
import 'package:startrek/skywalker.dart'; // 导入Runner/线程相关工具

import 'client.dart'; // 导入HTTPClient
import 'queue.dart';  // 导入DownloadQueue
import 'tasks.dart';  // 导入DownloadTask/DownloadInfo

/// HTTP下载器抽象接口
/// 定义下载器核心能力：添加任务、启动后台下载
abstract interface class Downloader{
  /// 添加下载任务
  /// [task] - 下载任务（实现DownloadTask接口）
  /// 返回值：Future<bool> - 是否成功加入队列（true:加入，false:无需下载）
  Future<bool> addTask(DownloadTask task);

  /// 启动后台下载线程
  void start();
}

/// 文件下载器（Downloader实现）
/// 基于优先级队列的多线程下载器，支持不同优先级的下载任务，自动管理任务队列
class FileDownloader implements Downloader {
  /// 构造方法
  /// [client] - HTTP客户端（提供基础下载能力）
  FileDownloader(this.client);

  /// 基础HTTP客户端
  final HTTPClient client;

  /// 下载任务队列（带优先级）
  final DownloadQueue queue = DownloadQueue();

  /// 下载工作线程（Spider）列表：对应不同优先级
  final List<Spider> spiders = [];

  /// 添加下载任务到队列
  @override
  Future<bool> addTask(DownloadTask task) async {
    // 准备任务：检查缓存/前置条件，返回是否需要加入队列
    var waiting = await task.prepareDownload();
    if (waiting) {
      queue.addTask(task); // 加入优先级队列
    }
    return waiting;
  }

  /// 获取下一个可执行的任务（优先级≤maxPriority）
  /// [maxPriority] - 最大优先级（如URGENT/NORMAL/SLOWER）
  /// 返回值：DownloadTask? - 待执行的任务，无则返回null
  DownloadTask? getTask(int maxPriority) => queue.nextTask(maxPriority);

  /// 移除并处理相同参数的任务（避免重复下载）
  /// [task] - 已完成的任务
  /// [downData] - 下载到的字节数据（可为null）
  /// 返回值：Future<int> - 处理成功的任务数量
  Future<int> removeTasks(DownloadTask task, Uint8List? downData) async =>
      await queue.removeTasks(task, downData);

  /// 初始化工作线程：创建不同优先级的Spider（紧急/普通/低速）
  void setup() {
    spiders.add(Spider(priority: DownloadPriority.URGENT, downloader: this));
    spiders.add(Spider(priority: DownloadPriority.NORMAL, downloader: this));
    spiders.add(Spider(priority: DownloadPriority.SLOWER, downloader: this));
  }

  /// 启动所有工作线程
  void run() {
    for (var worker in spiders) {
      /*await */worker.run(); // 非阻塞启动线程
    }
  }

  // /// 结束所有工作线程（预留方法）
  // void finish() {
  //   for (var worker in spiders) {
  //     /*await */worker.finish();
  //   }
  // }
  //
  // /// 停止所有工作线程（预留方法）
  // void stop() {
  //   for (var worker in spiders) {
  //     /*await */worker.stop();
  //   }
  // }

  /// 启动下载器：初始化并运行工作线程
  @override
  void start() {
    setup(); // 初始化工作线程
    run();   // 启动线程
  }

  /// 同步处理下载任务（核心逻辑）
  /// [task] - 待处理的下载任务
  /// 返回值：Future<Uint8List?> - 下载到的字节数据（失败返回null）
  Future<Uint8List?> handleDownloadTask(DownloadTask task) async {
    // 0. 准备任务：获取下载参数（URL等）
    DownloadInfo? params;
    try {
      if (await task.prepareDownload()) {
        params = task.downloadParams;
        assert(params != null, 'download params error: $task');
      }
    } catch (e, st) {
      print('[HTTP] failed to prepare download task: $task, error: $e, $st');
    }
    if (params == null) {
      // 任务无需下载（如缓存已存在），直接返回null
      return null;
    }

    // 1. 执行下载：从远程URL下载字节数据
    Uint8List? data = await download(params.url,
      onReceiveProgress: (count, total) => task.downloadProgress(count, total), // 进度回调
    );

    // 2. 处理响应数据：任务完成后的回调（如保存到本地）
    try {
      await task.processResponse(data);
    } catch (e, st) {
      print('[HTTP] failed to handle data: ${data?.length} bytes, $params, error: $e, $st');
    }

    // 3. 清理相同任务：移除队列中相同URL的任务，避免重复下载
    if (data == null) {
      // FIXME: 下载失败是否重试？暂不处理
      // return null;
    }
    await removeTasks(task, data);

    // 完成：返回下载数据
    return data;
  }

  /// 下载文件字节数据（封装HTTPClient的download方法）
  /// [url] - 下载URL
  /// [onReceiveProgress] - 下载进度回调
  /// 返回值：Future<Uint8List?> - 字节数据（失败返回null）
  Future<Uint8List?> download(Uri url, {
    ProgressCallback? onReceiveProgress,
  }) async {
    // 构建下载配置：响应类型为字节
    var options = client.downloadOptions(ResponseType.bytes);
    // 执行下载
    Response<Uint8List>? response = await client.download(url,
      options: options,
      onReceiveProgress: onReceiveProgress,
    );
    // 检查响应状态：仅200 OK视为成功
    int? statusCode = response?.statusCode;
    if (response == null || statusCode != 200) {
      print('[HTTP] failed to download $url, status: $statusCode - ${response?.statusMessage}');
      return null;
    }
    // 校验内容长度：确保下载数据完整
    int? contentLength = HTTPClient.getContentLength(response);
    Uint8List? data = response.data;
    if (data == null) {
      assert(contentLength == 0, 'content length error: $contentLength');
    } else if (contentLength != null && contentLength != data.length) {
      assert(false, 'content length not match: $contentLength, ${data.length}');
    }
    // 返回下载的字节数据
    return data;
  }
}

/// 下载工作线程（继承Runner）
/// 对应不同优先级的下载任务，循环从队列获取任务并执行
class Spider extends Runner {
  /// 构造方法
  /// [priority] - 该线程处理的任务优先级
  /// [downloader] - 所属的文件下载器
  Spider({
    required this.priority,
    required FileDownloader downloader
  }) : super(Runner.INTERVAL_SLOW * 4) { // 父类构造：设置轮询间隔（慢轮询×4）
    downloaderRef = WeakReference(downloader); // 弱引用避免内存泄漏
  }

  /// 该线程处理的任务优先级
  final int priority;
  /// 所属下载器的弱引用
  late final WeakReference<FileDownloader> downloaderRef;

  /// 获取所属下载器（弱引用解引用）
  FileDownloader? get downloader => downloaderRef.target;

  /// 检查线程是否运行中：父类状态+下载器未被回收
  @override
  bool get isRunning => super.isRunning && downloader != null;

  /// 线程核心处理逻辑（循环执行）
  /// 返回值：Future<bool> - true:继续循环，false:休眠等待
  @override
  Future<bool> process() async {
    // 1. 获取下一个任务（优先级≤当前线程优先级）
    DownloadTask? next = downloader?.getTask(priority);
    if (next == null) {
      // 无任务：返回false，线程休眠
      return false;
    }
    // 2. 执行任务
    try {
      await downloader?.handleDownloadTask(next);
    } catch (e, st) {
      print('[HTTP] failed to process download task: $e, $next, $st');
      return false; // 执行失败：返回false，休眠
    }
    // 3. 任务完成：返回true，立即执行下一个任务
    return true;
  }
}