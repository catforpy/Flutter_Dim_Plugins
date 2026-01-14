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

import 'package:chewie/chewie.dart'; // Chewie控制器
import 'package:video_player/video_player.dart'; // 视频控制器

import 'package:dim_client/ok.dart'; // DIM基础库（日志等）
import 'package:dim_client/ws.dart'; // WebSocket相关（节拍器）

import '../common/platform.dart'; // 平台适配


/// 视频播放节拍器 - 单例模式
/// 管理播放速度、播放位置记忆、跨平台速度适配等功能
class VideoPlayerMetronome with Logging {

  // 单例实现
  factory VideoPlayerMetronome() => _instance;
  static final VideoPlayerMetronome _instance = VideoPlayerMetronome._internal();
  
  /// 私有构造函数 - 初始化节拍器（1秒间隔）
  VideoPlayerMetronome._internal() {
    _metronome = Metronome(const Duration(milliseconds: 1000));
    /*await */_metronome.start(); // 启动节拍器（异步）
  }

  /// 底层节拍器（定时回调）
  late final Metronome _metronome;

  /// 添加节拍器回调
  void addTicker(Ticker ticker) => _metronome.addTicker(ticker);

  /// 移除节拍器回调
  void removeTicker(Ticker ticker) => _metronome.removeTicker(ticker);

  /// 播放位置缓存（URL -> 播放位置）
  final Map<String, Duration> _playingPositions = {};

  /// 基础播放速度（0.5/1.0/1.25/1.5/2.0）
  double _speed = 1.0;

  /// 加速标记（基础速度×2）
  bool speedUp = false;

  /// 获取当前播放速度
  /// [isLive] 是否为直播（直播强制1.0倍速）
  double getPlaybackSpeed(bool isLive) {
    if (isLive) {
      return 1.0; // 直播不支持变速
    } else if (speedUp) {
      return _speed * 2.0; // 加速模式：×2
    } else {
      return _speed; // 正常模式
    }
  }

  /// 切换播放速度（循环：1.0→1.25→1.5→2.0→0.5→1.0）
  void changePlaybackSpeed() {
    if (_speed < 1.0) {
      _speed = 1.0;
    } else if (_speed < 1.25) {
      _speed = 1.25;
    } else if (_speed < 1.5) {
      _speed = 1.5;
    } else if (_speed < 2.0) {
      _speed = 2.0;
    } else {
      _speed = 0.5;
    }
  }

  /// 设置播放速度到控制器
  /// [controller] 视频控制器 [isLive] 是否为直播
  void setPlaybackSpeed(VideoPlayerController controller, bool isLive) {
    double playbackSpeed = getPlaybackSpeed(isLive);
    controller.setPlaybackSpeed(playbackSpeed);
  }

  /// 保持播放速度（修复跨平台速度失效问题）
  /// [controller] 视频控制器 [isLive] 是否为直播
  void _keepPlaybackSpeed(VideoPlayerController controller, bool isLive) {
    // 直播或未播放：无需处理
    if (isLive || !controller.value.isPlaying) {
      return;
    }
    // 获取目标速度
    double playbackSpeed = getPlaybackSpeed(isLive);
    // 速度不一致：更新速度
    if (controller.value.playbackSpeed != playbackSpeed) {
      controller.setPlaybackSpeed(playbackSpeed);
    } else if (DevicePlatform.isAndroid) {
      // Android平台无需额外处理
    } else if (DevicePlatform.isWindows) {
      // Windows平台无需额外处理
    } else if (playbackSpeed != 1.0) {
      // iOS等平台：强制更新（修复速度失效问题）
      controller.setPlaybackSpeed(playbackSpeed);
    }
  }

  /// 存储播放位置（非直播）
  /// [url] 视频URL [position] 播放位置 [isLive] 是否为直播
  void _storePlaybackPosition(String url, Duration? position, bool isLive) {
    if (position == null) {
      return;
    } else if (isLive) {
      // 直播不存储位置
      // logDebug('no need to store position for live video: $url');
      return;
    }
    _playingPositions[url] = position;
  }

  /// 恢复上次播放位置
  /// [controller] 视频控制器 [chewie] Chewie控制器
  /// 返回：是否成功恢复位置
  Future<bool> seekLastPosition(VideoPlayerController controller, ChewieController chewie) async {
    String url = controller.dataSource; // 获取视频URL
    if (chewie.isLive) {
      logInfo('no need to seek position for live video: $url');
      return false;
    }
    // 获取上次播放位置
    Duration? position = _playingPositions[url];
    logInfo('last position: $position, $url');
    // 位置为空或小于16秒：不恢复
    if (position == null || position.inSeconds < 16) {
      return false;
    }
    // 恢复播放位置
    await controller.seekTo(position);
    return true;
  }

  /// 节拍器回调 - 同步播放速度和存储播放位置
  /// [controller] 视频控制器 [chewie] Chewie控制器
  Future<bool> touchPlayerControllers(VideoPlayerController controller, ChewieController? chewie) async {
    if (chewie == null) {
      assert(false, 'should not happen');
      return false;
    }
    // 保持播放速度（跨平台适配）
    bool isLive = chewie.isLive;
    _keepPlaybackSpeed(controller, isLive);
    // 存储当前播放位置
    String url = controller.dataSource;
    Duration? position = await controller.position;
    _storePlaybackPosition(url, position, isLive);
    return true;
  }
}