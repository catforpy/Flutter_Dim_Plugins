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

import 'package:chewie/chewie.dart'; // Chewie视频播放封装库
import 'package:dim_flutter/src/ui/nav.dart';
import 'package:flutter/services.dart'; // Flutter系统服务（屏幕方向控制）
// import 'package:get/get.dart'; // GetX框架（屏幕尺寸获取）
import 'package:video_player/video_player.dart'; // 基础视频播放控制器

import 'package:dim_client/ok.dart'; // DIM客户端基础库

import '../common/platform.dart'; // 平台适配工具
import '../utils/html.dart'; // HTML/URI处理工具

import 'controls.dart'; // 自定义播放控制组件
import 'metronome.dart'; // 视频播放节拍器（速度/进度管理）


/// 视频播放器控制器 - 封装VideoPlayerController和ChewieController的生命周期管理
/// 负责视频播放、销毁、切换，以及直播URL处理等核心功能
// protected
class PlayerController {

  /// 标记控制器是否已销毁
  bool _destroyed = false;

  /// 基础视频播放控制器
  VideoPlayerController? _videoPlayerController;
  VideoPlayerController? get videoPlayerController => _videoPlayerController;
  
  /// 设置视频播放控制器（自动释放旧控制器）
  /// [controller] 新的VideoPlayerController实例
  Future<void> setVideoPlayerController(VideoPlayerController? controller) async {
    var old = _videoPlayerController;
    if (old != null && old != controller) {
      // 旧控制器存在且与新控制器不同，先暂停再释放
      if (old.value.isPlaying) {
        await old.pause();
      }
      await old.dispose();
    }
    _videoPlayerController = controller;
  }

  /// Chewie播放控制器（封装了UI控制层）
  ChewieController? _chewieController;
  ChewieController? get chewieController => _chewieController;
  
  /// 设置Chewie控制器（自动释放旧控制器）
  /// [controller] 新的ChewieController实例
  Future<void> setChewieController(ChewieController? controller) async {
    var old = _chewieController;
    if (old != null && old != controller) {
      // 旧控制器存在且与新控制器不同，先暂停再释放
      if (old.isPlaying) {
        await old.pause();
      }
      old.dispose();
    }
    _chewieController = controller;
  }

  /// 获取Chewie播放组件（懒创建）
  Chewie? get chewie {
    var controller = _chewieController;
    return controller == null ? null : Chewie(controller: controller);
  }

  /// 销毁播放器控制器（释放资源+恢复屏幕方向）
  Future<void> destroy() async {
    _destroyed = true;
    await closeVideo();
    // 恢复系统默认屏幕方向
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  /// 关闭当前视频（释放所有控制器）
  Future<void> closeVideo() async {
    await setVideoPlayerController(null);
    await setChewieController(null);
  }

  /// 打开并播放指定URL的视频/直播
  /// [url] 视频/直播URL（支持普通视频和直播格式）
  /// 返回：创建的ChewieController实例（销毁状态返回null）
  Future<ChewieController?> openVideo(Uri url) async {
    // Windows平台视频播放器补丁
    DevicePlatform.patchVideoPlayer();
    //
    //  0. 检查URL中是否包含直播标识
    //
    bool isLive = false;
    String? liveUrl = cutLiveUrlString(url.toString());
    if (liveUrl != null) {
      // 提取纯直播URL（移除#live标识）
      url = HtmlUri.parseUri(liveUrl) ?? url;
      isLive = true;
    }
    //
    //  1. 创建网络视频播放控制器
    //
    var videoPlayerController = VideoPlayerController.networkUrl(url);
    //
    //  2. 创建Chewie控制器（配置播放参数）
    //
    ChewieController chewieController = ChewieController(
      videoPlayerController: videoPlayerController,
      // autoPlay: isLive, // 直播自动播放（注释掉，改为手动播放）
      // zoomAndPan: true, // 缩放和平移（注释掉）
      looping: isLive, // 直播循环播放
      isLive: isLive, // 标记是否为直播
      showOptions: false, // 不显示选项菜单
      allowedScreenSleep: false, // 播放时禁止屏幕休眠
      customControls: const CustomControls(), // 自定义播放控制UI
      // fullScreenByDefault: true, // 不默认全屏
      // 退出全屏后的屏幕方向（根据设备尺寸适配）
      // deviceOrientationsAfterFullScreen: _deviceOrientations(),
      deviceOrientationsAfterFullScreen: appTool.deviceOrientationsAfterFullScreen
    );
    //
    //  3. 初始化并播放视频
    //
    await videoPlayerController.initialize();
    await chewieController.play();
    // 更新控制器引用
    await setVideoPlayerController(videoPlayerController);
    await setChewieController(chewieController);
    // 检查控制器是否已销毁（防止异步操作中控制器被销毁）
    if (_destroyed) {
      Log.warning('video controller destroyed.');
      await closeVideo();
      return null;
    }
    // 恢复上次播放位置
    var metronome = VideoPlayerMetronome();
    await metronome.seekLastPosition(videoPlayerController, chewieController);
    return chewieController;
  }

  // /// 根据设备尺寸确定退出全屏后的屏幕方向
  // /// 手机（宽/高<640）：仅竖屏；平板/桌面：支持所有方向
  // static List<DeviceOrientation> _deviceOrientations() {
  //   Size size = Get.size;
  //   if (size.width <= 0 || size.height <= 0) {
  //     Log.error('window size error: $size');
  //   } else if (size.width < 640 || size.height < 640) {
  //     Log.info('window size: $size, this is a phone');
  //     return [DeviceOrientation.portraitUp]; // 手机仅竖屏
  //   } else {
  //     Log.info('window size: $size, this is a tablet?');
  //   }
  //   return DeviceOrientation.values; // 平板/桌面支持所有方向
  // }

  /// 裁剪直播URL中的特殊标识（#live / #live/xxx.m3u8）
  /// [urlString] 原始URL字符串
  /// 返回：纯视频URL（无直播标识），非直播URL返回null
  static String? cutLiveUrlString(String urlString) {
    // 处理 "...#live" 格式
    if (urlString.endsWith('#live')) {
      return urlString.substring(0, urlString.length - 5);
    }
    // 处理 "...#live/stream.m3u8" 格式
    int pos = urlString.lastIndexOf('#live/');
    if (pos > 0) {
      return urlString.substring(0, pos);
    }
    // 非直播URL
    return null;
  }

}