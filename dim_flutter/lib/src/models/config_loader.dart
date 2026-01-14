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

import 'package:flutter/services.dart';

import 'package:dim_client/sdk.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/pnf.dart';

import '../filesys/local.dart';
import 'config_branch.dart';

/// 配置加载器：负责配置的多源加载（缓存、资产、远程）和分支更新
class ConfigLoader with Logging {

  /// 更新配置中的List类型分支
  /// [config] 全局配置Map
  /// [name] 分支名称
  Future<void> _updateList(Map config, String name) async {
    var value = await ConfigBranch(config).fetchBranch(name);
    if(value != null){
      assert(value is List, 'config branch error: "$name" -> $value');
      config[name] = value;
    }
  }

  /// 更新配置中的Map类型分支
  /// [config] 全局配置Map
  /// [name] 分支名称
  Future<void> _updateMap(Map config, String name) async {
    var value = await ConfigBranch(config).fetchBranch(name);
    if(value != null){
      assert(value is Map, 'config branch error: "$name" -> $value');
      config[name] = value;
    }
  }

  /// 更新配置的核心分支（services/stations/uploads/newest）
  /// [config] 全局配置Map
  /// 返回更新后的配置Map
  Future<Map> _updateBranches(Map config) async {
    try {
      await _updateList(config, 'services');    // 更新服务机器人列表
      await _updateList(config, 'stations');    // 更新基站列表
      await _updateList(config, 'uploads');     // 更新上传API列表
      await _updateMap(config, 'newest');       // 更新最新版本信息
    } catch (e, st) {
      logError('failed to update config branches: $e, $st');
    }
    return config;
  }

  /// 从本地资产文件加载配置
  /// [assets] 资产路径（如：assets/config.json）
  /// 返回加载后的配置Map（失败返回空Map）
  Future<Map> loadAssetsFile(String assets) async {
    logInfo('loading config: $assets');
    try {
      // 从资产加载JSON字符串
      String json = await rootBundle.loadString(assets);
      var config = JSONMap.decode(json);
      if (config == null) {
        assert(false, 'config assets error: $assets -> $json');
      } else {
        // await _updateBranches(config); // 注释：暂不更新分支
        return config;
      }
    } catch (e, st) {
      logError('failed to load config from assets: $assets, error: $e, $st');
    }
    // 加载失败返回空Map
    return {};
  }

  /// 获取配置的本地缓存路径
  /// 返回缓存路径（如：caches/config.json）
  Future<String> _cachePath() async {
    String dir = await LocalStorage().cachesDirectory;
    return Paths.append(dir, 'config.json');
  }

  /// 从本地缓存加载配置
  /// 返回配置Map（缓存不存在返回null）
  Future<Map?> loadConfig() async {
    String path = await _cachePath();
    logInfo('loading config: $path');
    Map? config = await ConfigStorage.load(path);
    if (config != null) {
      // await _updateBranches(config); // 注释：暂不更新分支
      return config;
    }
    // assert(false, 'failed to load config: $path');
    return null;
  }

  /// 将配置保存到本地缓存
  /// [cnf] 配置Map
  /// 返回是否保存成功
  Future<bool> saveConfig(Map cnf) async {
    String path = await _cachePath();
    logInfo('saving config: $path');
    bool ok = await ConfigStorage.save(cnf, path);
    if (ok) {
      return true;
    }
    assert(false, 'failed to save config: $path');
    return false;
  }

  /// 从远程入口URL下载配置并更新分支
  /// [entrance] 远程配置入口URL
  /// 返回更新后的配置Map（失败返回null）
  Future<Map?> downloadConfig(String entrance) async {
    logInfo('downloading config: $entrance');
    var config = await ConfigServer.download(entrance);
    if (config is Map) {
      return await _updateBranches(config);
    }
    assert(false, 'failed to download config: $entrance');
    return null;
  }
}