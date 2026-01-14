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

import 'package:flutter/material.dart';

import 'package:dim_client/ok.dart';

import '../client/client.dart';
import '../client/shared.dart';
import '../common/platform.dart';
import '../ui/styles.dart';
import '../widgets/alert.dart';
import '../widgets/browser.dart';
import '../widgets/browser_deps.dart'; // 🔥 复用原有BrowserDeps接口
import '../widgets/gaussian.dart';

/// 最新版本管理器（单例）：负责解析版本信息、判断更新级别、展示更新提示
class NewestManager with Logging {
  factory NewestManager({BrowserDeps? deps}) => _instance._init(deps);
  static final NewestManager _instance = NewestManager._internal();
  NewestManager._internal();

  /// 🔥 注入BrowserDeps接口（默认使用GetX实现）
  late final BrowserDeps _deps;

  /// 初始化依赖（单例模式兼容依赖注入）
  NewestManager _init(BrowserDeps? deps){
    _deps = deps ?? getxBrowserDeps;    // 复用原有全局变量
    return this;
  }

  /// 最新版本信息
  Newest? _latest;

  /// 更新提醒级别（0=无需更新，1=可更新，2=建议更新，3=强制更新）
  int _remind = 0;
  // 提醒级别常量
  static const int kCanUpgrade = 1;     // 可更新
  static const int kShouldUpgrade = 2;  // 建议更新
  static const int kMustUpgrade = 3;    // 强制更新

  /// 应用分发渠道（AppStore/GooglePlay等）
  String store = 'AppStore';  // AppStore, GooglePlay, ...

  /// 解析配置中的最新版本信息
  /// [info] 配置Map
  /// 返回解析后的Newest实例
  Newest? parse(Map? info) {
    Newest? newest = _latest;
    if (newest != null) {
      return newest;
    } else if (info == null) {
      return null;
    }
    // 提取newest分支
    var child = info['newest'];
    if(child is Map){
      info = child;
    }else{
      // 不是Map类型，可能是URL?返回null
      return null;
    }
    // 根据操作系统和分发渠道筛选版本信息
    var os = DevicePlatform.operatingSystem;
    var ver = os.toLowerCase();
    var cid = store.toLowerCase();
    /// 'android-amazon' > 'android'（优先匹配渠道+系统）
    info = info['$ver-$cid'] ?? info[ver] ?? info;
    logInfo('got newest for channel "$os-$store": $info');
    if(info is Map){
      _latest = newest = Newest.from(info);
    }
    // 判断更新级别
    if(newest != null){
      GlobalVariable shared = GlobalVariable();
      Client client = shared.terminal;
      if (newest.mustUpgrade(client)) {
        _remind = kMustUpgrade;
      } else if (newest.shouldUpgrade(client)) {
        _remind = kShouldUpgrade;
      } else if (newest.canUpgrade(client)) {
        _remind = kCanUpgrade;
      } else {
        _remind = 0;
      }
    }
    return newest;
  }

  /// 检查更新并展示提示
  /// [context] 上下文
  /// 返回是否展示了更新提示
  bool checkUpdate(BuildContext context) {
    Newest? newest = _latest;
    int level = _remind;
    if (newest == null) {
      return false;
    } else if (level > 0) {
      // 展示提示后重置提醒级别
      _remind = 0;
    } else {
      return false;
    }
    // 🔥 替换GetX多语言为接口调用
    String notice = _deps.translate('Please update app (@version, build @build).', params: {
      'version': newest.version,
      'build': newest.build.toString(),
    });
    // 根据更新级别展示不同提示
    if (level == kShouldUpgrade) {
      // 建议更新：可选择是否更新
      // 🔥 替换Alert.confirm为接口兼容的弹窗（或复用_deps.showAlert+自定义确认弹窗）
      showDialog(
        context: context, 
        builder: (ctx) => AlertDialog(
          title: Text(_deps.translate('Upgrade')),
          content: Text(notice),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: Text(_deps.translate('Cannel')),
            ),
            TextButton(
              onPressed: (){
                Navigator.pop(ctx);
                // 🔥 替换Browser.launch为接口调用
                _deps.launchURL(ctx, Uri.parse(newest.url));
              }, 
              child: Text(_deps.translate('Update')),
            )
          ],
        )
      );
    }else if(level == kMustUpgrade){
      // 强制更新：锁定界面，必须更新
      FrostedGlassPage.lock(context, 
        title: _deps.translate('Upgrade'), // 🔥 替换GetX多语言
        body: RichText(
          text: TextSpan(
            text: notice,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: Styles.colors.secondaryTextColor,
              decoration: TextDecoration.none,
            ),
          ),
        ), 
        tail: TextButton(
          onPressed: () => _deps.launchURL(context, Uri.parse(newest.url)), // 🔥 替换Browser.launch
          child: Text(_deps.translate('Download'), style: TextStyle(
            color: Styles.colors.criticalButtonColor,
            decoration: TextDecoration.underline,
            decorationColor: Styles.colors.criticalButtonColor,
          ),),
        )
      );
    }
    return true;
  }
}

/// 最新版本信息类：存储版本号、构建号、下载地址
class Newest {
  Newest({required this.version,required this.build,required this.url});

  /// 版本号（如1.0.0）
  final String version;
  /// 构建号（如100）
  final int build;
  /// 下载地址
  final String url;

  /// 判断是否必须更新（主版本号不一致）
  /// [client] 当前客户端
  /// 返回是否必须更新
  bool mustUpgrade(Client client){
    if(int.parse(client.buildNumber) >= build){
      // 构建号更好，无需更新
      return false;
    }
    String clientVersion = client.versionName;
    int pos = clientVersion.indexOf(r'.');
    if(pos <= 0){
      // 版本号格式错误
      return false;
    }
    // 主版本号不一致则必须更新
    clientVersion = clientVersion.substring(0,pos + 1);
    return !version.startsWith(clientVersion);
  }

  /// 判断是否建议更新（次版本号不一致）
  /// [client] 当前客户端
  /// 返回是否建议更新
  bool shouldUpgrade(Client client) {
    if (int.parse(client.buildNumber) >= build) {
      // 构建号更高，无需更新
      return false;
    }
    String clientVersion = client.versionName;
    int pos = clientVersion.lastIndexOf(r'.');
    if (pos <= 0) {
      // 版本号格式错误
      return false;
    }
    // 次版本号不一致则建议更新
    clientVersion = clientVersion.substring(0, pos + 1);
    return !version.startsWith(clientVersion);
  }

  /// 判断是否可以更新（构建号更低）
  /// [client] 当前客户端
  /// 返回是否可以更新
  bool canUpgrade(Client client) =>
      int.parse(client.buildNumber) < build;

  /// 从Map解析Newest实例
  /// [info] 版本信息Map
  /// 返回Newest实例（字段不全则返回null）
  static Newest? from(Map info) {
    String? version = info['version'];
    int? build = info['build'];
    String? url = info['url'] ?? info['URL'];
    if (version == null || build == null || url == null) {
      return null;
    } else if (!url.contains('://')) {
      assert(false, 'client download URL error: $info');
      return null;
    }
    return Newest(version: version, build: build, url: url);
  }
}