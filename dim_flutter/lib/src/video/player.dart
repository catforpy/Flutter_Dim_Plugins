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
// import 'package:get/get.dart';

import 'package:dim_client/ok.dart';
import 'package:dim_client/ok.dart' as lnc;
import 'package:dim_client/ws.dart' show Runner;
import 'package:dim_client/pnf.dart' hide NotificationNames;

import '../common/constants.dart';
import '../screens/cast.dart';
import '../screens/device.dart';
import '../screens/picker.dart';
import '../ui/icons.dart';
import '../ui/nav.dart';
import '../ui/styles.dart';

import 'controller.dart';
import 'playing.dart';
import 'tvbox.dart';

/// 视频播放器页面组件
/// 支持普通视频播放和直播流播放两种模式
class VideoPlayerPage extends StatefulWidget {
  /// 构造函数
  /// [playingItem] - 要播放的媒体项
  /// [tvBox] - 直播盒子（直播模式使用）
  /// [onShare] - 分享回调函数
  const VideoPlayerPage(this.playingItem, this.tvBox, {this.onShare, super.key,});

  /// 当前播放的媒体项
  final MediaItem playingItem;
  /// 直播盒子（用于直播频道管理）
  final TVBox? tvBox;

  /// 获取播放地址
  Uri? get url => playingItem.url;

  /// 获取视频标题，为空时返回默认值
  String get title {
    String text = playingItem.title;
    return text.isNotEmpty ? text :  i18nTranslator.translate('Video Player');
  }

  /// 获取视频封面地址
  Uri? get cover => playingItem.cover;
  /// 获取文件名
  String? get filename => playingItem.filename;

  /// 分享回调
  final OnVideoShare? onShare;

  /// 主题色（白色）
  final Color color = CupertinoColors.white;
  /// 背景色（黑色）
  final Color bgColor = CupertinoColors.black;

  /// 打开普通视频播放器
  /// [context] - 上下文
  /// [playingItem] - 要播放的媒体项
  /// [onShare] - 分享回调
  static void openVideoPlayer(BuildContext context, MediaItem playingItem, {
    OnVideoShare? onShare,
  }) => appTool.showPage(
    context: context,
    builder: (context) => VideoPlayerPage(playingItem, null, onShare: onShare,),
  );

  /// 打开直播播放器
  /// [context] - 上下文
  /// [livesUrl] - 直播源地址
  /// [onShare] - 分享回调
  static void openLivePlayer(BuildContext context, Uri livesUrl, {
    OnVideoShare? onShare,
  }) => appTool.showPage(
    context: context,
    builder: (context) => VideoPlayerPage(MediaItem(null),
      TVBox(livesUrl, {'url': livesUrl.toString()},),
      onShare: onShare,
    ),
  );

  /// 创建状态对象
  @override
  State<StatefulWidget> createState() => _VideoAppState();
}

/// 视频播放器页面状态类
/// 实现了日志功能和通知观察者接口
class _VideoAppState extends State<VideoPlayerPage> with Logging implements lnc.Observer {
  /// 构造函数，初始化时注册通知监听
  _VideoAppState() {
    // 获取通知中心实例
    var nc = lnc.NotificationCenter();
    // 注册视频播放通知监听
    nc.addObserver(this, NotificationNames.kVideoPlayerPlay);
  }

  /// 播放器控制器
  final PlayerController _playerController = PlayerController();

  /// 播放错误信息
  String? _error;

  /// 组件销毁时的清理工作
  @override
  void dispose() {
    // 移除通知监听
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kVideoPlayerPlay);
    // 销毁播放器控制器
    _playerController.destroy();
    super.dispose();
  }

  /// 接收通知回调
  /// [notification] - 收到的通知
  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    // 处理视频播放通知
    if (name == NotificationNames.kVideoPlayerPlay) {
      // 从通知中解析播放地址和标题
      Uri? url = userInfo?['url'] ?? userInfo?['URL'];
      String? title = userInfo?['title'];
      if (url == null || title == null) {
        assert(false, 'video play info error: $userInfo');
      } else {
        // 切换播放的视频
        await _changeVideo(url, title);
      }
    }
  }

  /// 切换播放的视频
  /// [url] - 新视频地址
  /// [title] - 新视频标题
  Future<void> _changeVideo(Uri url, String title) async {
    // 关闭当前视频
    await _playerController.closeVideo();
    // 获取文件名
    var filename = Paths.filename(url.path);
    // 清空错误信息
    _error = null;
    // 更新播放项信息
    widget.playingItem.refresh({
      'url': url.toString(),
      'URL': url.toString(),
      'title': title,
      'filename': filename,
    });
    // 隐藏直播盒子
    widget.tvBox?.hidden = true;
    // 更新UI
    if (mounted) {
      setState(() {});
    }
    // 短暂延迟后打开新视频
    await Runner.sleep(const Duration(milliseconds: 128));
    openVideo(url);
  }

  /// 打开并播放指定地址的视频
  /// [url] - 视频地址
  void openVideo(Uri url) {
    logInfo('[Video Player] remote url: $url');
    // 打开视频并创建播放器
    _playerController.openVideo(url).then((chewie) {
      // 自动开始播放，更新UI
      if (mounted) {
        setState(() {});
      }
    }).onError((error, stackTrace) {
      // 播放出错，更新错误信息和UI
      if (mounted) {
        setState(() => _error = '$error');
      }
    });
  }

  /// 加载直播频道列表
  /// [tvBox] - 直播盒子实例
  void loadLives(TVBox tvBox) {
    // 刷新直播频道数据
    tvBox.refresh().then((genres) {
      // 频道加载完成，更新UI显示频道按钮
      if (mounted) {
        setState(() {});
      }
    }).onError((error, stackTrace) {
      // 加载出错，更新错误信息和UI
      if (mounted) {
        setState(() => _error = '$error');
      }
    });
  }

  /// 初始化状态
  @override
  void initState() {
    super.initState();
    // 准备视频播放器控制器
    var m3u8 = widget.url;
    if (m3u8 != null) {
      openVideo(m3u8);
    }
    // 准备直播盒子
    var tvBox = widget.tvBox;
    if (tvBox != null) {
      loadLives(tvBox);
    }
    // 准备屏幕管理器，添加投屏发现器
    var man = ScreenManager();
    man.addDiscoverer(CastScreenDiscoverer());
  }

  /// 构建UI界面
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    // 背景色设置为黑色
    backgroundColor: widget.bgColor,
    // 导航栏
    navigationBar: CupertinoNavigationBar(
      backgroundColor: widget.bgColor,
      // 标题
      middle: Text(widget.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: widget.color,
        ),
      ),
      // 右侧操作按钮
      trailing: _trailing(context),
    ),
    // 主内容区域
    child: _body(),
  );

  /// 构建主内容区域
  Widget _body() {
    // 获取播放器组件
    Widget? chewie = _playerController.chewie;
    // 构建主视图（播放器/加载中/直播加载）
    Widget? main = chewie ?? _loadingVideo() ?? _loadingLives();
    if (main != null) {
      main = Center(
        child: main,
      );
    }
    // 构建直播频道列表视图
    Widget? lives = widget.tvBox?.view;
    if (lives != null) {
      lives = Container(
        alignment: Alignment.topRight,
        child: lives,
      );
      // 透明度动画
      lives = AnimatedOpacity(
        opacity: widget.tvBox?.hidden != false ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 512),
        child: lives,
      );
      // 滑动动画
      lives = AnimatedSlide(
        offset: widget.tvBox?.hidden != false ? const Offset(1, 0) : Offset.zero,
        duration: const Duration(milliseconds: 512),
        child: lives,
      );
    }
    // 组合视图
    return Stack(
      children: [
        if (main != null)
          main,
        if (lives != null)
          lives,
      ],
    );
  }

  /// 构建导航栏右侧操作按钮
  /// [context] - 上下文
  Widget? _trailing(BuildContext context) {
    // 投屏按钮
    Widget? castBtn = _castButton(context);
    // 分享按钮
    Widget? shareBtn = _shareButton();
    // 直播频道按钮
    Widget? livesBtn = _livesButton();
    // 组合按钮
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (castBtn != null)
          castBtn,
        if (shareBtn != null)
          shareBtn,
        if (livesBtn != null)
          livesBtn,
      ],
    );
  }

  /// 构建直播频道按钮
  Widget? _livesButton() {
    var tvbox = widget.tvBox;
    if (tvbox == null) {
      return null;
    }
    var channelGroups = tvbox.lives;
    if (channelGroups == null || channelGroups.isEmpty) {
      return null;
    }
    // 频道列表按钮
    return IconButton(
      icon: Icon(
        AppIcons.livesIcon,
        size: Styles.navigationBarIconSize,
        // 根据隐藏状态切换颜色
        color: tvbox.hidden ? widget.color : Colors.blue,
      ),
      onPressed: () {
        // 切换直播频道列表显示/隐藏状态
        setState(() {
          tvbox.hidden = !tvbox.hidden;
        });
      },
    );
  }

  /// 构建投屏按钮
  /// [context] - 上下文
  Widget? _castButton(BuildContext context) {
    var chewie = _playerController.chewieController;
    if (chewie == null) {
      return null;
    }
    var m3u8 = widget.url;
    if (m3u8 == null) {
      logError('playing URL not exists: ${widget.playingItem}');
      return null;
    }
    // 投屏按钮
    return IconButton(
      icon: Icon(
        AppIcons.airPlayIcon,
        size: Styles.navigationBarIconSize,
        color: widget.color,
      ),
      onPressed: () {
        // 暂停播放
        chewie.pause();
        // 打开投屏选择器
        AirPlayPicker.open(context, m3u8);
      },
    );
  }

  /// 构建分享按钮
  Widget? _shareButton() {
    OnVideoShare? onShare = widget.onShare;
    if (onShare == null) {
      return null;
    }
    var chewie = _playerController.chewieController;
    if (chewie == null) {
      return null;
    }
    var m3u8 = widget.url;
    if (m3u8 == null) {
      logError('playing URL not exists: ${widget.playingItem}');
      return null;
    }
    // 分享按钮
    return IconButton(
      icon: Icon(
        AppIcons.shareIcon,
        size: Styles.navigationBarIconSize,
        color: widget.color,
      ),
      onPressed: () => onShare(widget.playingItem),
    );
  }

  /// 构建直播加载中视图
  Widget? _loadingLives() {
    Widget indicator;
    Widget message;
    // 文本样式
    TextStyle textStyle = TextStyle(
      color: widget.color,
      fontSize: 14,
      decoration: TextDecoration.none,
    );
    // 检查直播盒子
    var tvBox = widget.tvBox;
    if (tvBox == null) {
      logWarning('TV box not found: $tvBox');
      return null;
    }
    var livesUrl = tvBox.livesUrl;
    String urlString = livesUrl.toString();
    var channelGroups = tvBox.lives;
    if (channelGroups == null) {
      // 加载中状态
      indicator = CupertinoActivityIndicator(color: widget.color,);
      message = Text(
        i18nTranslator.translate('Loading "@url"',
        params: {
          'url': urlString,
        }),
        style: textStyle,
      );
    } else if (channelGroups.isEmpty) {
      // 加载失败状态
      indicator = const Icon(AppIcons.unavailableIcon, color: CupertinoColors.systemRed,);
      message = Text(
        i18nTranslator.translate('Failed to load "@url".',
        params: {
          'url': urlString,
        }),
        style: textStyle,
      );
    } else {
      // 加载完成，返回null
      return null;
    }
    // 组合加载视图
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        indicator,
        Container(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
          child: message,
        ),
      ],
    );
  }

  /// 构建视频加载中视图
  Widget? _loadingVideo() {
    Widget indicator;
    Widget message;
    // 文本样式
    TextStyle textStyle = TextStyle(
      color: widget.color,
      fontSize: 14,
      decoration: TextDecoration.none,
    );
    // 检查播放项
    var m3u8 = widget.url;
    if (m3u8 == null) {
      logWarning('playing URL not found: ${widget.playingItem}');
      return null;
    }
    String urlString = m3u8.toString();
    urlString = PlayerController.cutLiveUrlString(urlString) ?? urlString;
    if (_error == null) {
      // 加载中状态
      indicator = CupertinoActivityIndicator(color: widget.color,);
      message = Text(
        i18nTranslator.translate('Loading "@url"',
        params: {
          'url': urlString,
        }),
        style: textStyle,
      );
    } else {
      // 加载失败状态
      indicator = const Icon(AppIcons.unavailableIcon, color: CupertinoColors.systemRed,);
      message = Text(
        i18nTranslator.translate('Failed to load "@url".',
        params: {
          'url': urlString,
        }),
        style: textStyle,
      );
    }
    // 组合加载视图
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        indicator,
        Container(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
          child: message,
        ),
      ],
    );
  }
}