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

import 'dart:async';

import 'package:flutter/services.dart';

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';
import 'package:dim_client/pnf.dart';

import '../client/shared.dart';
import '../models/config.dart';
import '../pnf/loader.dart';

import 'local.dart';

/// 共享文件上传管理器（单例）
/// 负责头像和文件的上传管理，支持加密上传、缓存管理和跨平台适配
class SharedFileUploader with Logging {
  /// 工厂方法：获取单例实例
  factory SharedFileUploader() => _instance;
  /// 静态单例实例
  static final SharedFileUploader _instance = SharedFileUploader._internal();
  /// 私有构造方法：初始化文件传输和加密工具
  SharedFileUploader._internal() {
    // 初始化文件传输工具（HTTP客户端，连接超时15秒）
    _ftp = FileTransfer(HTTPClient(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
    )));
    // 初始化加密工具
    _enigma = Enigma();
  }

  /// 文件传输工具实例
  late final FileTransfer _ftp;
  /// 加密工具实例
  late final Enigma _enigma;

  /// 获取加密工具实例
  Enigma get enigma => _enigma;

  /// 加密密钥是否已加载标记
  bool _secretsLoaded = false;

  /// 头像上传API地址
  String? _upAvatarAPI;
  /// 文件上传API地址
  String? _upFileAPI;

  //  User-Agent示例:
  //  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'
  //  + ' AppleWebKit/537.36 (KHTML, like Gecko)'
  //  + ' Chrome/118.0.0.0 Safari/537.36'
  
  /// 设置HTTP请求的User-Agent
  void setUserAgent(String userAgent) {
    _ftp.setUserAgent(userAgent);
  }

  /// 添加头像下载任务（通过URL）
  Future<bool> addAvatarTask(DownloadTask task) async {
    await _initSecrets();
    return await _ftp.addDownloadTask(task);
  }

  /// 添加文件下载任务（通过URL）
  Future<bool> addDownloadTask(DownloadTask task) async {
    await _initSecrets();
    return await _ftp.addDownloadTask(task);
  }
  
  /// 添加文件上传任务
  Future<bool> addUploadTask(UploadTask task) async {
    await _initSecrets();
    return await _ftp.addUploadTask(task);
  }

  /// 初始化加密密钥和用户代理（懒加载）
  Future<bool> _initSecrets() async {
    if(_secretsLoaded){
      return true;
    }else{
      _secretsLoaded = true;
    }
    //
    //  1. 设置用户代理
    //
    GlobalVariable shared = GlobalVariable();
    String ua = shared.terminal.userAgent;
    logInfo('update user-agent: $ua');
    _ftp.setUserAgent(ua);
    //
    //  2. 加载加密密钥
    //
    String json = await rootBundle.loadString('assets/enigma.json');
    Map? info = JSONMap.decode(json);
    List? secrets = info?['secrets'];
    if(secrets == null){
      assert(false, 'failed to update enigma secrets: $json');
      return false;
    }
    logInfo('set enigma secrets: $secrets');
    List<String> lines = [];
    for(var pwd in secrets){
      if(pwd is String && pwd.isNotEmpty){
        lines.add(pwd);
      }
    }
    _enigma.update(lines);
    return lines.isNotEmpty;
  }

  /// 根据配置初始化上传API地址
  void initWithConfig(Config config){
    String? api = config.uploadAvatarAPI;
    logInfo('set avatar API: $_upAvatarAPI -> $api');
    if(api != null){
      _upAvatarAPI = api;
    }
    api = config.uploadAvatarAPI;
    logInfo('set file API: $_upFileAPI -> $api');
    if (api != null) {
      _upFileAPI = api;
    }
  }

  ///  为用户上传头像图片数据
  ///
  /// @param data     - 图片二进制数据
  /// @param filename - 图片文件名 ('avatar.jpg')
  /// @param sender   - 上传用户ID
  /// @return 上传后的文件URL（失败返回null）
  Future<Uri?> uploadAvatar(Uint8List data, String filename, ID sender) async {
    String? api = _upAvatarAPI;
    if (api == null) {
      assert(false, 'avatar API not ready');
      return null;
    }
    // 创建上传任务
    var ted = TransportableData.create(data);
    var pnf = PortableNetworkFile.createFromData(ted, filename);
    pnf.password = Password.kPlainKey;    // 头像使用明文上传
    var task = await PortableFileUploadTask.create(api, pnf,
      sender: sender, enigma: _enigma,
    );
    if (task == null) {
      return null;
    }
    // 处理上传任务
    try {
      var uploader = _ftp.uploader;
      if (uploader is FileUploader) {
        await uploader.handleUploadTask(task);
      }
    } catch (e, st) {
      logError('[HTTP] failed to handle upload task: $task, error: $e, $st');
      return null;
    }
    // 上传成功，返回文件URL
    return pnf.url;
  }

  ///  为用户上传加密后的文件数据
  ///
  /// @param content - 包含文件名和数据的消息内容
  /// @param sender  - 上传用户ID
  /// @return 任务添加成功返回true（等待上传）
  Future<bool> uploadEncryptData(FileContent content, ID sender) async {
    String? api = _upFileAPI;
    if (api == null) {
      assert(false, 'file API not ready');
      return false;
    }
    // 从消息内容解析PNF对象
    var pnf = PortableNetworkFile.parse(content.toMap());
    if (pnf == null) {
      logError('file content error: $content');
      assert(false, 'file content error: $content');
      return false;
    }
    // 创建加密上传任务
    var task = await PortableFileUploadTask.create(api, pnf,
      sender: sender, enigma: _enigma,
    );
    if (task == null) {
      logError('failed to create upload task: $api, $sender');
      return false;
    }
    // 添加到上传队列
    return await addUploadTask(task);
  }

  /// 将文件数据缓存到本地
  /// [data] - 文件二进制数据
  /// [filename] - 文件名
  /// @return 缓存的字节数
  static Future<int> cacheFileData(Uint8List data, String filename) async {
    String? path = await _getCacheFilePath(filename);
    return await ExternalStorage.saveBinary(data, path);
  }

  /// 从本地缓存获取文件数据
  /// [filename] - 文件名
  /// @return 文件二进制数据（null表示获取失败）
  static Future<Uint8List?> getFileData(String filename) async {
    String? path = await _getCacheFilePath(filename);
    return await ExternalStorage.loadBinary(path);
  }

  /// 获取文件缓存路径
  /// [filename] - 文件名（支持相对路径/绝对路径）
  /// @return 完整的缓存文件路径
  static Future<String> _getCacheFilePath(String filename) async {
    if (filename.contains('/') || filename.contains('\\')) {
      // 绝对路径直接返回
      return filename;
    } else {
      // 相对路径拼接缓存目录
      LocalStorage cache = LocalStorage();
      return await cache.getCacheFilePath(filename);
    }
  }
}