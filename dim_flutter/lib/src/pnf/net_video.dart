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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../ui/icons.dart';
import '../video/player.dart';
import '../video/playing.dart';

import 'gallery.dart';
import 'image.dart';
import 'loader.dart';
import 'net_base.dart';


/// 网络视频工厂（单例）：管理视频视图的创建和缓存
class NetworkVideoFactory {
  factory NetworkVideoFactory() => _instance;
  static final NetworkVideoFactory _instance = NetworkVideoFactory._internal();
  NetworkVideoFactory._internal();

  /// 创建视频视图
  /// [content] 视频内容
  /// [width/height] 视图尺寸
  /// [onVideoShare] 视频分享回调
  /// 返回视频视图
  PortableNetworkView getVideoView(VideoContent content,
      {double? width, double? height, OnVideoShare? onVideoShare}) {
    // 从视频内容解析PNF对象
    PortableNetworkFile? pnf = PortableNetworkFile.parse(content.toMap());
    Uri? url = pnf?.url;
    if (url == null || pnf == null) {
      // PNF解析失败，抛出异常
      throw FormatException('PNF error: $content');
    }
    // 创建视频加载器
    _PortableVideoLoader loader = _PortableVideoLoader.from(pnf);
    // 创建并返回视频视图
    return _PortableVideoView(loader, width: width, height: height, onVideoShare: onVideoShare,);
  }
}

/// 便携网络视频视图：用于展示PNF类型的视频内容
class _PortableVideoView extends PortableNetworkView {
  /// 构造方法
  /// [loader] 视频加载器
  /// [width/height] 视图尺寸
  /// [onVideoShare] 视频分享回调
  const _PortableVideoView(super.loader, {this.width, this.height, this.onVideoShare});

  /// 获取视频URL
  Uri? get url => pnf?.url;

  /// 视图宽度
  final double? width;
  /// 视图高度
  final double? height;

  /// 视频分享回调
  final OnVideoShare? onVideoShare;

  @override
  State<StatefulWidget> createState() => _PortableVideoState();

  /// 获取无视频封面时的占位Widget
  /// [width/height] 占位尺寸
  /// 返回占位Widget
  static Widget getNoImage({double? width, double? height}) {
    width ??= 160;
    height ??= 90;
    return Container(
      width: width,
      height: height,
      color: CupertinoColors.black,
    );
  }
}

/// 便携网络视频视图状态类：处理视频封面展示和播放按钮逻辑
class _PortableVideoState extends PortableNetworkState<_PortableVideoView> {

  @override
  Widget build(BuildContext context) {
    // 将通用加载器强转为视频加载器
    var loader = widget.loader as _PortableVideoLoader;
    // 获取进度指示器（播放按钮/错误提示）
    Widget? indicator = loader.getProgress(context, widget);
    if (indicator == null) {
      // 无指示器，直接显示视频封面
      return loader.getImage(widget);
    }
    // 获取PNF对象
    var pnf = widget.pnf ?? loader.pnf;
    // 获取视频标题和封面
    String? title = pnf.getString('title');
    String? cover = pnf.getString('snapshot');
    // 叠加显示封面、标题和指示器
    return Stack(
      alignment: AlignmentDirectional.center,
      // fit: StackFit.passthrough,
      children: [
        // 底层显示视频封面
        loader.getImage(widget),
        // 无封面时显示标题
        if (cover == null && title != null)
          _titleWidget(title),
        // 上层显示播放按钮/错误提示
        indicator,
      ],
    );
  }

  /// 构建视频标题Widget
  /// [text] 原始标题文本
  /// 返回标题Widget
  Widget _titleWidget(String text) {
    String name;
    String title = text;
    // 移除封面参数（如果有）
    int pos = title.indexOf('; cover=');
    if (pos > 0) {
      title = title.substring(0, pos);
    }
    // 拆分名称和副标题（格式："名称 - 副标题"）
    pos = title.indexOf(' - ');
    if (pos > 0) {
      name = title.substring(0, pos).trim();
      title = title.substring(pos + 3).trim();
    } else {
      name = title.trim();
      title = '';
    }
    logInfo('video title: "$text" => "$name" + "$title"');
    // 显示标题文本
    return Text('$name\n\n$title',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: CupertinoColors.systemYellow,
        fontSize: 12,
      ),
    );
  }

}

/// 便携网络视频加载器：继承自文件加载器，处理视频封面和播放逻辑
class _PortableVideoLoader extends PortableFileLoader with Logging {
  /// 构造方法
  /// [pnf] 便携网络文件对象
  _PortableVideoLoader(super.pnf);

  /// 视频封面提供者缓存
  ImageProvider<Object>? _snapshot;

  /// 获取视频封面提供者：优先从缓存获取，无则从PNF的snapshot字段创建
  ImageProvider<Object>? get imageProvider {
    var image = _snapshot;
    image ??= _snapshot = Gallery.getSnapshotProvider(pnf.toMap());
    return image;
  }

  /// 构建视频封面Widget
  /// [widget] 视频视图
  /// 返回封面Widget
  Widget getImage(_PortableVideoView widget) {
    double? width = widget.width;
    double? height = widget.height;
    var image = imageProvider;
    if (image == null) {
      // 无封面，显示黑色占位
      return _PortableVideoView.getNoImage(width: width, height: height);
    } else if (width == null && height == null) {
      // 无尺寸限制，直接显示封面
      return ImageUtils.image(image,);
    } else {
      // 有尺寸限制，指定尺寸显示封面
      return ImageUtils.image(image, width: width, height: height, fit: BoxFit.cover,);
    }
  }

  /// 获取视频进度指示器（播放按钮/错误提示）
  /// [ctx] 上下文
  /// [widget] 视频视图
  /// 返回指示器Widget
  Widget? getProgress(BuildContext ctx, _PortableVideoView widget) {
    var pnf = widget.pnf ?? super.pnf;
    var url = pnf.url;
    if (url == null) {
      // 无URL，显示错误提示
      logError('video error: $pnf');
      return _showError('Video error', null, CupertinoColors.systemRed);
    }
    var password = pnf.password;
    if (password != null && password.algorithm != Password.PLAIN) {
      // 非明文密码，不支持下载，显示错误提示
      logError('video error: $pnf');
      return _showError('Download not supported', null, CupertinoColors.systemRed);
    }
    // 创建播放按钮
    var icon = const Icon(AppIcons.playVideoIcon, color: CupertinoColors.white);
    var playingItem = MediaItem(pnf.toMap());
    var button = IconButton(
      icon: icon,
      // 点击播放按钮打开视频播放器
      onPressed: () => VideoPlayerPage.openVideoPlayer(ctx, playingItem, onShare: widget.onVideoShare),
    );
    // 包装播放按钮为圆角样式
    return ClipRRect(
      borderRadius: const BorderRadius.all(
        Radius.elliptical(16, 16),
      ),
      child: Container(
        color: CupertinoColors.tertiaryLabel,
        child: button,
      ),
    );
  }

  /// 构建错误提示Widget
  /// [text] 错误文本
  /// [icon] 错误图标
  /// [color] 文本颜色
  /// 返回错误提示Widget
  Widget _showError(String text, IconData? icon, Color color) => Container(
    color: CupertinoColors.secondaryLabel,
    padding: const EdgeInsets.all(8),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text,
          style: TextStyle(color: color,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    ),
  );

  //
  //  工厂方法
  //
  /// 从PNF创建视频加载器
  /// [pnf] 便携网络文件对象
  /// 返回视频加载器
  static _PortableVideoLoader from(PortableNetworkFile pnf) {
    _PortableVideoLoader loader = _PortableVideoLoader(pnf);
    // if (pnf.url != null && pnf.data == null) {
    //   SharedFileUploader().addDownloadTask(loader);
    // }
    return loader;
  }

}