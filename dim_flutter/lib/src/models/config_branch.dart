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

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/pnf.dart';

import '../filesys/local.dart';
import '../utils/html.dart';

/// 配置分支管理器：处理单个配置分支的下载、缓存、加载、保存
/// 支持两种分支值类型：
/// 1. List/Map：直接缓存到本地，返回null（表示无需更新）
/// 2. String（URL）：从URL下载配置，缓存到本地后返回下载结果
class ConfigBranch with Logging {
  /// 构造函数
  /// [config] 全局配置Map
  ConfigBranch(this.config);

  /// 全局配置Map
  final Map config;

  /// 获取并更新配置分支
  /// 逻辑：
  /// 1. 若分支值是List/Map：缓存到本地，返回null
  /// 2. 若分支值是URL：下载配置，缓存到本地，返回下载结果
  /// 3. 下载失败则加载本地缓存
  /// [name] 分支名称（如services、stations）
  /// 返回更新后的分支值（List/Map）或null
  Future<dynamic> fetchBranch(String name) async {
    logInfo('checking config branch: $name');
    var value = config[name];
    if(value is List || value is Map){
      // 分支值是List/Map,直接缓存到本地
      bool ok = await _saveBranch(value,name);
      assert(ok, 'failed to save branch: $name');
      // 返回null表示无需更新
      return null;
    }else if(value is String){
      // 分支是URL，从远程下载
      assert(value.indexOf('://') > 0, 'config branch error: "$name" -> $value');
      var info = await _downloadBranch(value, name);
      if(info == null){
        // 下载失败，加载本地缓存
        info = await _loadBranch(name);
        assert(info != null, 'failed to load config branch: $name');
      }else{
        // 下载成功，更新本地缓存
        bool ok = await _saveBranch(info, name);
        assert(ok, 'failed to save branch: $name');
      }
      return info;
    }else{
      // 分支值为null，返回null
      assert(value == null, 'config branch error: "$name" -> $value');
      return null;
    }
  }

  /// 获取配置分支的本地缓存路径
  /// [name] 分支名称
  /// 返回缓存文件路径（如：caches/config.d/{name}.json）
  Future<String> _cachePath(String name) async {
    // TODO: 校验文件名安全性
    String dir = await LocalStorage().cachesDirectory;
    return Paths.append(dir, 'config.d', '$name.json');
  }

  /// 将配置分支缓存到本地存储
  /// 格式：{ "name": 分支值 }
  /// [info] 分支值（List/Map）
  /// [name] 分支名称
  /// 返回是否保存成功
  Future<bool> _saveBranch(dynamic info, String name) async {
    // 1.包装分支值（确保是{name: value}格式）
    Map container;
    if(info is Map){
      var inner = info[name];
      if (inner == null) {
        container = {name: info};
      } else {
        // 已包装，直接使用
        container = info;
      }
    }else{
      assert(info is List, 'config branch error: "$name", $info');
      container = {name: info};
    }
    // 2.保存到本地
    String path = await _cachePath(name);
    logInfo('saving config branch: "$name" -> $path');
    bool ok = await ConfigStorage.save(container, path);
    assert(ok, 'failed to save config branch: "$name" -> $path');
    return ok;
  }

  /// 从本地存储加载配置分支
  /// [name] 分支名称
  /// 返回分支值（List/Map）
  Future<dynamic> _loadBranch(String name) async {
    String path = await _cachePath(name);
    logInfo('loading config branch: "$name" -> $path');
    // 1. 加载文件
    Map? info = await ConfigStorage.load(path);
    assert(info != null, 'config branch not found: "$name" -> $path');
    // 2. 解包（提取name对应的分支值）
    var inner = info?[name];
    if (inner != null) {
      // 本地缓存的配置分支必须以name为根键
      return inner;
    }
    assert(false, 'config branch error: "$name" -> $path, $info');
    return info;
  }

  /// 从远程URL下载配置分支
  /// [remote] 远程URL
  /// [name] 分支名称
  /// 返回下载的分支值（List/Map）
  Future<dynamic> _downloadBranch(String remote, String name) async {
    logInfo('downloading config branch: "$name", $remote');
    // 1. 下载配置
    var info = await ConfigServer.download(remote);
    assert(info != null, 'config branch not found: "$name" -> $remote');
    // 2. 解包（提取name对应的分支值）
    if (info is Map) {
      // 远程配置必须以name为根键
      return info[name];
    }
    assert(false, 'config branch error: "$name" -> $remote, $info');
    return null;
  }
}

/// 配置服务器工具类：提供远程配置下载能力
abstract interface class ConfigServer {

  /// 从远程URL下载配置
  /// [remote] 远程URL
  /// 返回解析后的配置Map（失败返回null）
  static Future<dynamic> download(String remote) async {
    var url = HtmlUri.parseUri(remote);
    if(url == null){
      assert(false, 'URL error: $remote');
      return null;
    }
    try{
      // 1.下载二进制数据
      var http = FileDownloader(HTTPClient());
      var data = await http.download(url);
      if(data == null){
        Log.error('failed to download: $url');
        return null;
      }
      // 2.解码为UTF8字符串
      var text = UTF8.decode(data);
      if (text == null) {
        assert(false, 'data error: ${data.length} bytes');
        return null;
      }
      // 3. 解析JSON为Map
      var info = JSON.decode(text);
      if(info == null){
        assert(false, 'json data error: $text');
        return null;
      }
      // 下载成功
      Log.info('downloaded json: $remote -> $text');
      return info;
    }catch(e,st){
      Log.error('failed to download: $remote, error: $e, $st');
    }
    assert(false, 'failed to download: $remote');
    return null;
  }
}

/// 配置存储工具类：提供本地配置文件的加载和保存能力
abstract interface class ConfigStorage {

  /// 从本地路径加载配置Map
  /// [path] 文件路径
  /// 返回解析后的Map（文件不存在/解析失败返回null）
  static Future<Map?> load(String path) async {
    try{
      if(await Paths.exists(path)){
        return await ExternalStorage.loadJsonMap(path);
      }
    }catch(e,st){
      Log.error('failed to load config: $path, error: $e, $st');
    }
    return null;
  }

  /// 将配置Map保存到本地路径
  /// [info] 配置Map
  /// [path] 文件路径
  /// 返回是否保存成功
  static Future<bool> save(Map info, String path) async {
    try{
      int size = await ExternalStorage.saveJsonMap(info, path);
      if (size > 0) {
        return true;
      }
    }catch (e, st) {
      Log.error('failed to save file: $path, error: $e, $st');
    }
    assert(false, 'failed to save file: $path');
    return false;
  }
}