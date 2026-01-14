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

import 'dart:typed_data';

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/pnf.dart';

import '../filesys/local.dart';
import '../filesys/upload.dart';


/// 便携文件加载器：管理PNF的上传/下载任务，处理文件数据和状态
class PortableFileLoader {
  PortableFileLoader(this.pnf);

  /// 便携网络文件对象
  final PortableNetworkFile pnf;

  /// 上传任务
  PortableNetworkUpper? uploadTask;
  /// 下载任务
  PortableNetworkLoader? downloadTask;

  /// 预加载处理：根据PNF类型创建上传/下载任务
  Future<void> prepare() async {
    var ftp = SharedFileUploader();
    if(pnf.url == null){
      // 无URL，创建上传任务
      var task = PortableFileUploadTask(pnf, ftp.enigma);
      uploadTask = task;
      await ftp.addUploadTask(task);
      _plaintext = await task.plaintext;
    } else {
      // 有URL，创建下载任务
      var task = PortableFileDownloadTask(pnf);
      downloadTask = task;
      await ftp.addDownloadTask(task);
      // _plaintext = task.plaintext;
    }
  }

  /// 明文数据缓存
  Uint8List? _plaintext;
  /// 获取明文数据（优先缓存，其次下载任务）
  Uint8List? get plaintext => _plaintext ?? downloadTask?.plaintext;

  /// 获取文件传输状态
  PortableNetworkStatus get status {
    var s = uploadTask?.status;
    s ??= downloadTask?.status;
    return s ?? PortableNetworkStatus.init;
  }

  /// 获取已传输字节数
  int get count => uploadTask?.count ?? downloadTask?.count ?? 0;
  /// 获取总字节数
  int get total => uploadTask?.total ?? downloadTask?.total ?? 0;

  /// 获取文件名（优先上传任务，其次下载任务）
  String? get filename => uploadTask?.filename ?? downloadTask?.filename;

  /// 获取缓存文件路径（优先上传任务，其次下载任务）
  Future<String?> get cacheFilePath async =>
      await (uploadTask?.cacheFilePath ?? downloadTask?.cacheFilePath);
}

/// 便携文件下载任务：处理文件下载、缓存和状态通知
class PortableFileDownloadTask extends PortableNetworkLoader {
  PortableFileDownloadTask(super.pnf);

  /// 获取下载优先级（从PNF获取，无则用默认值）
  @override
  int get priority => pnf.getInt('priority') ?? super.priority;

  /// 获取文件缓存实例（本地存储）
  @override
  FileCache get fileCache => LocalStorage();

  /// 发送通知（封装NotificationCenter）
  @override
  Future<void> postNotification(String name, [Map? info]) async {
    var nc = NotificationCenter();
    await nc.postNotification(name, this, info);
  }
}

/// 便携文件上传任务：处理文件上传、加密、本地缓存和状态通知
class PortableFileUploadTask extends PortableNetworkUpper {
  PortableFileUploadTask(super.pnf, this._enigma);

  /// 加密器
  final Enigma _enigma;

  /// 获取加密器
  @override
  Enigma get enigma => _enigma;

  /// 获取文件缓存实例（本地存储）
  @override
  FileCache get fileCache => LocalStorage();

  /// 发送通知（封装NotificationCenter）
  @override
  Future<void> postNotification(String name, [Map? info]) async {
    var nc = NotificationCenter();
    await nc.postNotification(name, this, info);
  }

  /// 获取文件数据（优先PNF，其次本地缓存；有数据时保存到本地）
  @override
  Future<Uint8List?> get fileData async {
    String? path = await cacheFilePath;
    Uint8List? data = pnf.data;
    if (data == null || data.isEmpty) {
      // 无数据，从本地缓存加载
      if (path != null && await Paths.exists(path)) {
        data = await ExternalStorage.loadBinary(path);
      }
    } else if (path == null) {
      assert(false, 'failed to get file path: $pnf');
    } else {
      // 有数据，保存到本地缓存
      int cnt = await ExternalStorage.saveBinary(data, path);
      if (cnt == data.length) {
        // 保存成功，清空PNF中的数据（节省内存）
        pnf.data = null;
      } else {
        assert(false, 'failed to save data: $path');
      }
    }
    return data;
  }

  /// 创建上传任务（静态工厂方法）
  /// [api] 上传API地址
  /// [pnf] 便携网络文件对象
  /// [sender] 发送者ID
  /// [enigma] 加密器
  /// 返回上传任务（null表示创建失败）
  static Future<PortableFileUploadTask?> create(String api, PortableNetworkFile pnf, {
    required ID sender, required Enigma enigma,
  }) async {
    Uri? url = pnf.url;
    Uint8List? data = pnf.data;
    String? filename = pnf.filename;
    assert(url == null, 'remote URL already exists: $pnf');
    //
    //  1. 检查文件名
    //
    if (filename == null) {
      Log.error('failed to create upload task: $pnf');
      assert(false, 'file content error: $pnf');
      return null;
    } else if (URLHelper.isFilenameEncoded(filename)) {
      // 文件名已编码（md5(data).ext）
    } else if (data != null) {
      // 从数据重建文件名（md5+扩展名）
      filename = URLHelper.filenameFromData(data, filename);
      Log.info('rebuild filename: ${pnf.filename} -> $filename');
      pnf.filename = filename;
    } else {
      // 文件名错误
      assert(false, 'filename error: $pnf');
      return null;
    }
    //
    //  2. 为PNF添加加密信息
    //
    pnf['enigma'] = {
      'API': api,
      'sender': sender.toString(),
    };
    return PortableFileUploadTask(pnf, enigma);
  }

}