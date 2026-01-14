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

import 'package:dim_flutter/src/dim_ui.dart';
import 'package:flutter/cupertino.dart';

import 'package:dim_client/sdk.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/ok.dart' as lnc;
import 'package:dim_client/pnf.dart' hide NotificationNames;

import '../channels/manager.dart';
import '../common/constants.dart';
import '../ui/icons.dart';

import '../ui/styles.dart';
import 'net_base.dart';


/// 网络音频工厂（单例）：管理音频视图的创建和缓存，避免重复创建
class NetworkAudioFactory {
  factory NetworkAudioFactory() => _instance;
  static final NetworkAudioFactory _instance = NetworkAudioFactory._internal();
  NetworkAudioFactory._internal();

  /// 音频视图缓存：URL -> 音频视图（弱引用）
  final Map<Uri, _PortableAudioView> _views = WeakValueMap();

  /// 创建音频视图
  /// [content] 音频内容
  /// [color] 文本/图标颜色
  /// [backgroundColor] 背景颜色
  /// 返回音频视图
  PortableNetworkView getAudioView(AudioContent content, {Color? color, Color? backgroundColor}) {
    // 从音频内容解析PNF对象
    PortableNetworkFile? pnf = PortableNetworkFile.parse(content.toMap());
    if (pnf == null) {
      // PNF解析失败，抛出异常
      throw FormatException('PNF error: $content');
    }
    Uri? url = pnf.url;
    // 获取文件加载器
    var loader = PortableNetworkFactory().getLoader(pnf);
    if (url == null) {
      // 无URL，直接创建音频视图
      return _PortableAudioView(loader, color: color, backgroundColor: backgroundColor,);
    }
    // 有URL，从缓存获取视图（无则创建）
    _PortableAudioView? view = _views[url];
    if (view == null) {
      view = _PortableAudioView(loader, color: color, backgroundColor: backgroundColor,);
      _views[url] = view;
    }
    return view;
  }
}

/// 便携网络音频视图：用于展示PNF类型的音频内容，支持播放/暂停
class _PortableAudioView extends PortableNetworkView {
  /// 构造方法
  /// [loader] 音频加载器
  /// [color] 文本/图标颜色
  /// [backgroundColor] 背景颜色
  _PortableAudioView(super.loader, {this.color, this.backgroundColor});

  /// 文本/图标颜色
  final Color? color;
  /// 背景颜色
  final Color? backgroundColor;

  /// 音频播放信息（状态和缓存路径）
  final _AudioPlayInfo _info = _AudioPlayInfo();

  /// 获取音频URL
  Uri? get url => pnf?.url;

  /// 获取音频缓存文件路径（优先从缓存获取）
  Future<String?> get cacheFilePath async {
    String? path = _info.cacheFilePath;
    if (path == null) {
      // 缓存无路径，从加载器获取
      path = await loader.cacheFilePath;
      if (path != null && await Paths.exists(path)) {
        // 路径存在，缓存路径
        _info.cacheFilePath = path;
      }
    }
    return path;
  }

  @override
  State<StatefulWidget> createState() => _PortableAudioState();

}

/// 音频播放信息：存储缓存路径和播放状态
class _AudioPlayInfo {
  /// 音频缓存文件路径
  String? cacheFilePath;
  /// 是否正在播放
  bool playing = false;
}

/// 便携网络音频视图状态类：处理音频播放控件展示和播放逻辑
class _PortableAudioState extends PortableNetworkState<_PortableAudioView> {
  /// 构造方法：注册播放完成通知监听
  _PortableAudioState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kPlayFinished);
  }

  @override
  void dispose() {
    // 移除通知监听，避免内存泄漏
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kPlayFinished);
    super.dispose();
  }

  /// 接收通知回调：处理播放完成通知
  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    super.onReceiveNotification(notification);
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kPlayFinished) {
      // 播放完成通知
      String? path = userInfo?['path'];
      if (path != await widget.cacheFilePath) {
        // 路径不匹配，忽略
        return;
      }
      // 路径匹配，更新播放状态为暂停
      if (mounted) {
        setState(() {
          widget._info.playing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 获取进度指示器（传输状态/播放状态）
    Widget? progress = getProgress();
    // 构建音频播放控件
    return Container(
      width: 200,
      color: widget.backgroundColor,
      padding: Styles.audioMessagePadding,
      child: GestureDetector(
        // 点击切换播放/暂停
        onTap: _togglePlay,
        child: Row(
          children: [
            // 播放/暂停按钮
            _button(progress),
            // 进度/时长文本（占满剩余空间）
            Expanded(
              flex: 1,
              child: progress ?? Text('${_duration ?? 0} s',
                textAlign: TextAlign.center,
                style: TextStyle(color: widget.color, ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 切换播放/暂停状态
  Future<void> _togglePlay() async {
    // 获取音频通道管理器
    ChannelManager man = ChannelManager();
    // 获取音频缓存路径
    String? path = await widget.cacheFilePath;
    if (widget._info.playing) {
      // 正在播放，停止播放
      await man.audioChannel.stopPlay(path);
      if (mounted) {
        // 更新播放状态为暂停
        setState(() {
          widget._info.playing = false;
        });
      }
    } else if (path != null) {
      // 暂停状态且有路径，开始播放
      if (mounted) {
        // 更新播放状态为播放中
        setState(() {
          widget._info.playing = true;
        });
      }
      await man.audioChannel.startPlay(path);
    }
  }

  /// 获取音频时长（从PNF的duration字段解析）
  String? get _duration {
    return widget.pnf?.getDouble('duration', 0)?.toStringAsFixed(3);
  }

  /// 构建播放/暂停按钮
  /// [progress] 进度指示器（非空时显示等待图标）
  /// 返回按钮Widget
  Widget _button(Widget? progress) => progress != null
      ? Icon(AppIcons.waitAudioIcon, color: widget.color, ) // 等待/传输中图标
      : widget._info.playing
      ? Icon(AppIcons.playingAudioIcon, color: widget.color) // 播放中图标
      : Icon(AppIcons.playAudioIcon, color: widget.color); // 暂停图标

  /// 获取进度指示器Widget：根据文件传输状态返回对应的进度提示
  /// 返回进度指示器（null表示传输完成）
  Widget? getProgress() {
    String text; // 进度文本
    IconData? icon; // 进度图标
    Color? color = widget.color; // 进度颜色
    var loader = widget.loader;
    // 获取当前文件传输状态
    PortableNetworkStatus pns = loader.status;
    if (pns == PortableNetworkStatus.success) {
      // 传输成功，无进度指示器
      return null;
    } else if (pns == PortableNetworkStatus.init) {
      // 初始状态：等待中
      text = i18nTranslator.translate('Waiting');
    } else if (pns == PortableNetworkStatus.waiting) {
      // 等待状态：等待中
      text = i18nTranslator.translate('Waiting');
    } else if (pns == PortableNetworkStatus.encrypting) {
      // 加密中状态
      text = i18nTranslator.translate('Encrypting');
      icon = AppIcons.encryptingIcon;
    } else if (pns == PortableNetworkStatus.uploading) {
      // 上传中状态：显示上传进度百分比
      double len = loader.total.toDouble();
      double value = len > 0 ? loader.count * 100.0 / len : 0.0;
      text = '${value.toStringAsFixed(1)}%';
    } else if (pns == PortableNetworkStatus.downloading) {
      // 下载中状态
      double len = loader.total.toDouble();
      double value = len > 0 ? loader.count * 100.0 / len : 0.0;
      if (value < 100.0) {
        // 下载进度未完成，显示百分比
        text = '${value.toStringAsFixed(1)}%';
      } else {
        // 下载完成，解密中
        text = 'Decrypting';
        icon = AppIcons.decryptingIcon;
      }
    } else if (pns == PortableNetworkStatus.decrypting) {
      // 解密中状态
      text = 'Decrypting';
      icon = AppIcons.decryptingIcon;
    } else if (pns == PortableNetworkStatus.error) {
      // 错误状态：显示错误文本和图标，颜色改为红色
      text = 'Error';
      icon = AppIcons.decryptErrorIcon;
      color = CupertinoColors.systemRed;
    } else {
      // 未知状态，断言报错
      assert(false, 'status error: $pns');
      return null;
    }
    // 构建进度指示器（文本+图标/加载动画）
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text,
          style: TextStyle(color: color,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(
          width: 4,
        ),
        icon == null
            ? CupertinoActivityIndicator(color: color) // 加载动画
            : Icon(icon, color: color), // 状态图标
      ],
    );
  }

}