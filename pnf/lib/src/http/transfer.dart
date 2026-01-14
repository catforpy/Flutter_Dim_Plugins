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

import 'client.dart';    // 导入HTTPClient
import 'download.dart';  // 导入Downloader/FileDownloader
import 'tasks.dart';     // 导入DownloadTask/UploadTask
import 'upload.dart';    // 导入Uploader/FileUploader

/// 文件传输管理器
/// 统一管理上传/下载器，提供简洁的入口方法，支持自定义扩展上传/下载器
class FileTransfer {
  /// 构造方法
  /// [client] - HTTP客户端（基础网络能力）
  FileTransfer(this.client) {
    // 初始化上传/下载器
    downloader = createDownloader();
    uploader = createUploader();
  }

  /// 基础HTTP客户端
  final HTTPClient client;
  /// 下载器（可自定义）
  late final Downloader downloader;
  /// 上传器（可自定义）
  late final Uploader uploader;

  /// 创建下载器（可重写自定义）
  /// 返回值：Downloader - 默认返回FileDownloader并启动
  Downloader createDownloader() {
    var http = FileDownloader(client);
    http.start();
    return http;
  }

  /// 创建上传器（可重写自定义）
  /// 返回值：Uploader - 默认返回FileUploader并启动
  Uploader createUploader() {
    var http = FileUploader(client);
    http.start();
    return http;
  }

  /// 设置HTTP请求的User-Agent头
  /// [userAgent] - 自定义User-Agent字符串
  void setUserAgent(String userAgent) =>
      client.userAgent = userAgent;

  /// 添加下载任务（入口方法）
  /// [task] - 下载任务（实现DownloadTask接口）
  /// 返回值：Future<bool> - 是否成功加入队列
  Future<bool> addDownloadTask(DownloadTask task) async =>
      downloader.addTask(task);

  /// 添加上传任务（入口方法）
  /// [task] - 上传任务（实现UploadTask接口）
  /// 返回值：Future<bool> - 是否成功加入队列
  Future<bool> addUploadTask(UploadTask task) async =>
      uploader.addTask(task);
}