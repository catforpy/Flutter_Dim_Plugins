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

import 'dart:async'; // 定时器相关

import 'package:flutter/material.dart'; // Flutter Material组件
import 'package:video_player/video_player.dart'; // 基础视频控制器

import 'package:chewie/chewie.dart'; // Chewie核心库

import 'package:chewie/src/notifiers/player_notifier.dart'; // 播放器状态通知器
import 'package:chewie/src/material/material_progress_bar.dart'; // 进度条组件
import 'package:chewie/src/helpers/utils.dart'; // 工具函数（时长格式化等）
import 'package:chewie/src/center_play_button.dart'; // 中央播放按钮

import 'package:provider/provider.dart'; // 状态管理

import 'package:dim_client/ok.dart'; // DIM基础库（日志等）
import 'package:dim_client/ws.dart' show Ticker; // 节拍器接口

import '../utils/keyboard.dart'; // 键盘事件处理
import 'metronome.dart'; // 视频播放节拍器


/// 自定义视频播放控制组件 - 替代Chewie默认控制栏
/// 支持键盘控制、播放速度调节、直播标识、自定义进度条等功能
class CustomControls extends StatefulWidget {
  const CustomControls({super.key});

  @override
  State<StatefulWidget> createState() => _CustomControlsState();

}

class _CustomControlsState extends State<CustomControls>
    with SingleTickerProviderStateMixin, Logging implements Ticker {
  /// 播放器状态通知器（控制UI显隐）
  late PlayerNotifier notifier;
  /// 最新视频播放状态
  late VideoPlayerValue _latestValue;
  /// 记录上次音量（用于静音/恢复）
  double? _latestVolume;
  /// 控制栏自动隐藏定时器
  Timer? _hideTimer;
  /// 初始化显示定时器
  Timer? _initTimer;
  /// 字幕位置
  late var _subtitlesPosition = Duration.zero;
  /// 字幕开关状态
  bool _subtitleOn = false;
  /// 全屏/退出全屏后显示定时器
  Timer? _showAfterExpandCollapseTimer;
  /// 是否正在拖动进度条
  bool _dragging = false;
  /// 点击显示标记
  bool _displayTapped = false;
  /// 缓冲显示定时器
  Timer? _bufferingDisplayTimer;
  /// 是否显示缓冲指示器
  bool _displayBufferingIndicator = false;

  /// 控制栏高度
  final barHeight = 48.0 * 1.5;
  /// 边距大小
  final marginSize = 5.0;

  /// 视频播放控制器
  late VideoPlayerController controller;
  /// Chewie控制器
  ChewieController? _chewieController;

  /// 焦点节点（用于键盘事件）
  final FocusNode _focusNode = FocusNode();

  // 断言：_chewieController会在didChangeDependencies中初始化
  ChewieController get chewieController => _chewieController!;

  /// 节拍器回调 - 同步播放速度和进度
  @override
  Future<void> tick(DateTime now, Duration elapsed) async {
    var metronome = VideoPlayerMetronome();
    await metronome.touchPlayerControllers(controller, _chewieController);
  }

  @override
  void initState() {
    super.initState();
    // 获取播放器状态通知器
    notifier = Provider.of<PlayerNotifier>(context, listen: false);
    // 初始化节拍器
    var metronome = VideoPlayerMetronome();
    metronome.speedUp = false;
    metronome.addTicker(this);
    // 请求焦点（接收键盘事件）
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    // 播放出错时显示错误UI
    if (_latestValue.hasError) {
      return chewieController.errorBuilder?.call(
        context,
        chewieController.videoPlayerController.value.errorDescription!,
      ) ?? const Center(
        child: Icon(
          Icons.error,
          color: Colors.white,
          size: 42,
        ),
      );
    }
    // 构建核心控制UI
    Widget controls = Stack(
      children: [
        // 缓冲指示器
        if (_displayBufferingIndicator)
          const Center(
            child: CircularProgressIndicator(),
          )
        else
          _buildHitArea(), // 点击播放/暂停区域
        // 底部控制栏
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            // 字幕显示
            if (_subtitleOn)
              Transform.translate(
                offset: Offset(
                  0.0,
                  notifier.hideStuff ? barHeight * 0.8 : 0.0,
                ),
                child:
                _buildSubtitles(context, chewieController.subtitle!),
              ),
            _buildBottomBar(context), // 底部控制栏
          ],
        ),
      ],
    );
    // 添加焦点和键盘事件处理
    controls = Focus(
      focusNode: _focusNode,
      child: controls,
      onKeyEvent: (focusNode, event) => _keyEvent(event),
    );
    // 鼠标悬停/点击处理
    var metronome = VideoPlayerMetronome();
    return MouseRegion(
      onHover: (_) {
        _cancelAndRestartTimer(); // 鼠标悬停时重置隐藏定时器
      },
      child: GestureDetector(
        onTapDown: (details) {
          metronome.speedUp = true;
          _hideTimer?.cancel(); // 按下时取消隐藏
        },
        onTapUp: (details) {
          metronome.speedUp = false;
          _cancelAndRestartTimer(); // 松开时重置隐藏定时器
        },
        onTapCancel: () {
          metronome.speedUp = false;
          _cancelAndRestartTimer(); // 取消点击时重置隐藏定时器
        },
        onTap: () {
          metronome.speedUp = false;
          _cancelAndRestartTimer(); // 点击时重置隐藏定时器
        },
        onDoubleTap: () {
          _playPause(); // 双击播放/暂停
        },
        child: AbsorbPointer(
          absorbing: notifier.hideStuff, // 隐藏时不响应点击
          child: controls,
        ),
      ),
    );
  }

  /// 键盘事件处理
  KeyEventResult _keyEvent(KeyEvent event) {
    logInfo('key event: $event');
    _cancelAndRestartTimer(); // 按键时重置隐藏定时器
    var checker = RawKeyboardChecker();
    var key = checker.checkKeyEvent(event);
    logInfo('key: $key');
    if (key == null) {
      return KeyEventResult.ignored;
    } else if (key == RawKeyboardKey.arrowUp) {
      logInfo('volume up');
      volumeUp(); // 音量+
    } else if (key == RawKeyboardKey.arrowDown) {
      logInfo('volume down');
      volumeDown(); // 音量-
    } else if (key == RawKeyboardKey.arrowLeft) {
      logInfo('seek backward');
      seekBackward(); // 后退15秒
    } else if (key == RawKeyboardKey.arrowRight) {
      logInfo('seek forward');
      seekForward(); // 前进15秒
    } else if (key == RawKeyboardKey.enter || key == RawKeyboardKey.space) {
      logInfo('play/pause');
      _playPause(); // 播放/暂停
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// 调整播放位置
  /// [seconds] 调整秒数（正数前进，负数后退）
  Future<void> _changePosition({int seconds = 0}) async {
    var position = await controller.position;
    if (position == null) {
      return;
    } else if (_chewieController?.isLive == true) {
      logInfo('live video cannot seek position'); // 直播不能调整进度
      return;
    }
    await controller.seekTo(position + Duration(seconds: seconds));
  }
  /// 前进15秒
  Future<void> seekForward() async => await _changePosition(seconds: 15);
  /// 后退15秒
  Future<void> seekBackward() async => await _changePosition(seconds: -15);

  /// 调整音量
  /// [delta] 音量变化值（0.1/-0.1）
  Future<void> _changeVolume({required double delta}) async {
    var volume = controller.value.volume + delta;
    // 音量范围限制（0.0-1.0）
    if (volume > 1.0) {
      volume = 1.0;
    } else if (volume < 0.0) {
      volume = 0.0;
    }
    await controller.setVolume(volume);
  }
  /// 音量+
  Future<void> volumeUp() async => await _changeVolume(delta: 0.1);
  /// 音量-
  Future<void> volumeDown() async => await _changeVolume(delta: -0.1);

  @override
  void dispose() {
    // 移除节拍器回调
    var metronome = VideoPlayerMetronome();
    metronome.removeTicker(this);
    // 释放资源
    _dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 释放定时器和监听器
  void _dispose() {
    controller.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
  }

  @override
  void didChangeDependencies() {
    final oldController = _chewieController;
    // 从上下文获取ChewieController
    _chewieController = ChewieController.of(context);
    controller = chewieController.videoPlayerController;

    // 控制器变化时重新初始化
    if (oldController != chewieController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  /// 构建字幕显示组件
  Widget _buildSubtitles(BuildContext context, Subtitles subtitles) {
    if (!_subtitleOn) {
      return const SizedBox();
    }
    // 获取当前位置的字幕
    final currentSubtitle = subtitles.getByPosition(_subtitlesPosition);
    if (currentSubtitle.isEmpty) {
      return const SizedBox();
    }

    // 使用自定义字幕构建器
    if (chewieController.subtitleBuilder != null) {
      return chewieController.subtitleBuilder!(
        context,
        currentSubtitle.first!.text,
      );
    }

    // 默认字幕样式
    return Padding(
      padding: EdgeInsets.all(marginSize),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0x96000000), // 半透明黑色背景
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Text(
          currentSubtitle.first!.text.toString(),
          style: const TextStyle(
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// 构建底部控制栏（带动画透明度）
  AnimatedOpacity _buildBottomBar(
      BuildContext context,
      ) {
    // 图标颜色（固定白色）
    var iconColor = Colors.white;

    return AnimatedOpacity(
      opacity: notifier.hideStuff ? 0.0 : 1.0, // 隐藏时透明度0
      duration: const Duration(milliseconds: 300), // 动画时长
      child: Container(
        height: barHeight + (chewieController.isFullScreen ? 10.0 : 0), // 全屏时增加高度
        padding: EdgeInsets.only(
          left: 20,
          bottom: !chewieController.isFullScreen ? 10.0 : 0, // 非全屏时底部边距
        ),
        child: SafeArea(
          bottom: chewieController.isFullScreen, // 全屏时适配底部安全区
          minimum: chewieController.controlsSafeAreaMinimum,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    // 直播标识/播放进度
                    if (chewieController.isLive)
                      Expanded(child: Text('LIVE',
                        style: TextStyle(
                          color: iconColor,
                          decoration: TextDecoration.none,
                        ),
                      ))
                    else
                      _buildPosition(iconColor),
                    // 静音按钮
                    if (chewieController.allowMuting)
                      _buildMuteButton(controller, iconColor),
                    const Spacer(),
                    // 播放速度按钮（非直播）
                    if (!chewieController.isLive)
                      _buildSpeedButton(controller, iconColor, barHeight),
                    // 全屏按钮
                    if (chewieController.allowFullScreen)
                      _buildExpandButton(iconColor),
                  ],
                ),
              ),
              // 全屏时额外间距
              SizedBox(
                height: chewieController.isFullScreen ? 15.0 : 0,
              ),
              // 进度条（非直播）
              if (!chewieController.isLive)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(right: 20),
                    child: Row(
                      children: [
                        _buildProgressBar(),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建静音按钮
  GestureDetector _buildMuteButton(
      VideoPlayerController controller,
      Color? iconColor,
      ) {
    return GestureDetector(
      onTap: () {
        _cancelAndRestartTimer(); // 点击时重置隐藏定时器

        // 切换静音状态
        if (_latestValue.volume == 0) {
          controller.setVolume(_latestVolume ?? 0.5); // 恢复上次音量
        } else {
          _latestVolume = controller.value.volume; // 记录当前音量
          controller.setVolume(0.0); // 静音
        }
      },
      child: AnimatedOpacity(
        opacity: notifier.hideStuff ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: ClipRect(
          child: Container(
            height: barHeight,
            padding: const EdgeInsets.only(
              left: 6.0,
            ),
            child: Icon(
              _latestValue.volume > 0 ? Icons.volume_up : Icons.volume_off,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建播放速度按钮
  GestureDetector _buildSpeedButton(
      VideoPlayerController controller,
      Color? iconColor,
      double barHeight,
      ) {
    var metronome = VideoPlayerMetronome();
    // 获取当前播放速度
    double playbackSpeed = metronome.getPlaybackSpeed(chewieController.isLive);
    bool speedUp = metronome.speedUp;
    // 显示文本（加速时标红）
    String text = speedUp ? '>> X$playbackSpeed' : 'X$playbackSpeed';
    Color? color = speedUp ? Colors.red : iconColor;
    return GestureDetector(
      onTap: () => setState(() {
        // 切换播放速度
        metronome.changePlaybackSpeed();
        metronome.setPlaybackSpeed(controller, chewieController.isLive);
      }),
      child: Container(
        alignment: Alignment.center,
        height: barHeight,
        color: Colors.transparent,
        padding: const EdgeInsets.only(
          left: 6.0,
          right: 8.0,
        ),
        child: Text(text,
          style: TextStyle(
            fontSize: 16,
            color: color,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  /// 构建全屏/退出全屏按钮
  GestureDetector _buildExpandButton(Color? iconColor) {
    return GestureDetector(
      onTap: _onExpandCollapse, // 切换全屏状态
      child: AnimatedOpacity(
        opacity: notifier.hideStuff ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          height: barHeight + (chewieController.isFullScreen ? 15.0 : 0),
          margin: const EdgeInsets.only(right: 12.0),
          padding: const EdgeInsets.only(
            left: 8.0,
            right: 8.0,
          ),
          child: Center(
            child: Icon(
              chewieController.isFullScreen
                  ? Icons.fullscreen_exit // 退出全屏
                  : Icons.fullscreen,    // 进入全屏
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建点击播放/暂停区域
  Widget _buildHitArea() {
    final bool isFinished = _latestValue.position >= _latestValue.duration; // 是否播放完成
    final bool showPlayButton = !_dragging && !notifier.hideStuff; // 是否显示播放按钮

    return GestureDetector(
      onTap: () {
        if (_latestValue.isPlaying) {
          // 播放中：切换控制栏显隐
          if (_displayTapped) {
            setState(() {
              notifier.hideStuff = true;
            });
          } else {
            _cancelAndRestartTimer();
          }
        } else {
          // 暂停中：播放并隐藏控制栏
          _playPause();

          setState(() {
            notifier.hideStuff = true;
          });
        }
      },
      child: CenterPlayButton(
        backgroundColor: Colors.black54, // 半透明黑色背景
        iconColor: Colors.white,         // 白色图标
        isFinished: isFinished,         // 是否播放完成
        isPlaying: controller.value.isPlaying, // 是否正在播放
        show: showPlayButton,           // 是否显示按钮
        onPressed: _playPause,          // 点击回调
      ),
    );
  }

  /// 构建播放进度文本（当前时间/总时长）
  Widget _buildPosition(Color? iconColor) {
    final position = _latestValue.position; // 当前位置
    final duration = _latestValue.duration; // 总时长

    return RichText(
      text: TextSpan(
        text: '${formatDuration(position)} ', // 当前时间
        children: <InlineSpan>[
          TextSpan(
            text: '/ ${formatDuration(duration)}', // 总时长（浅色）
            style: TextStyle(
              fontSize: 14.0,
              color: iconColor?.withOpacity(.75),
              fontWeight: FontWeight.normal,
            ),
          )
        ],
        style: TextStyle(
          fontSize: 14.0,
          color: iconColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 取消并重启控制栏隐藏定时器
  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();

    setState(() {
      notifier.hideStuff = false; // 显示控制栏
      _displayTapped = true;
    });
  }

  /// 初始化控制器和监听器
  Future<void> _initialize() async {
    // 初始化字幕状态
    _subtitleOn = chewieController.subtitle?.isNotEmpty ?? false;
    // 添加播放状态监听器
    controller.addListener(_updateState);

    // 更新初始状态
    _updateState();

    // 自动播放时启动隐藏定时器
    if (controller.value.isPlaying || chewieController.autoPlay) {
      _startHideTimer();
    }

    // 初始化时显示控制栏
    if (chewieController.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            notifier.hideStuff = false;
          });
        }
      });
    }
  }

  /// 切换全屏/退出全屏
  void _onExpandCollapse() {
    setState(() {
      notifier.hideStuff = true; // 切换时隐藏控制栏

      chewieController.toggleFullScreen(); // 切换全屏状态
      // 切换后延迟显示控制栏
      _showAfterExpandCollapseTimer = Timer(
        const Duration(milliseconds: 300),
        _cancelAndRestartTimer,
      );
    });
  }

  /// 播放/暂停切换
  void _playPause() {
    final isFinished = _latestValue.position >= _latestValue.duration; // 是否播放完成

    setState(() {
      if (controller.value.isPlaying) {
        // 播放中：暂停
        notifier.hideStuff = false;
        _hideTimer?.cancel();
        controller.pause();
      } else {
        // 暂停中：播放
        _cancelAndRestartTimer();

        if (!controller.value.isInitialized) {
          // 未初始化：先初始化再播放
          controller.initialize().then((_) {
            controller.play();
          });
        } else {
          if (isFinished) {
            controller.seekTo(Duration.zero); // 播放完成：回到开头
          }
          controller.play(); // 播放
        }
      }
    });
  }

  /// 启动控制栏隐藏定时器
  void _startHideTimer() {
    // 获取隐藏延迟时间（使用默认值如果为负数）
    final hideControlsTimer = chewieController.hideControlsTimer.isNegative
        ? ChewieController.defaultHideControlsTimer
        : chewieController.hideControlsTimer;
    // 延迟隐藏控制栏
    _hideTimer = Timer(hideControlsTimer, () {
      if (mounted) {
        setState(() {
          notifier.hideStuff = true;
        });
      }
    });
  }

  /// 缓冲定时器超时回调 - 显示缓冲指示器
  void _bufferingTimerTimeout() {
    _displayBufferingIndicator = true;
    if (mounted) {
      setState(() {});
    }
  }

  /// 更新播放状态（监听器回调）
  void _updateState() {
    if (!mounted) return;

    // 处理缓冲指示器显示逻辑
    if (chewieController.progressIndicatorDelay != null) {
      if (controller.value.isBuffering) {
        // 开始缓冲：启动延迟显示定时器
        _bufferingDisplayTimer ??= Timer(
          chewieController.progressIndicatorDelay!,
          _bufferingTimerTimeout,
        );
      } else {
        // 停止缓冲：取消定时器并隐藏指示器
        _bufferingDisplayTimer?.cancel();
        _bufferingDisplayTimer = null;
        _displayBufferingIndicator = false;
      }
    } else {
      // 无延迟：直接根据缓冲状态显示
      _displayBufferingIndicator = _checkBuffering(controller);
      // _displayBufferingIndicator = controller.value.isBuffering;
    }

    // 更新状态变量
    setState(() {
      _latestValue = controller.value;
      _subtitlesPosition = controller.value.position;
    });
  }

  /// 构建进度条组件
  Widget _buildProgressBar() {
    return Expanded(
      child: MaterialVideoProgressBar(
        controller,
        onDragStart: () {
          setState(() {
            _dragging = true; // 开始拖动
          });

          _hideTimer?.cancel(); // 取消隐藏定时器
        },
        onDragUpdate: () {
          _hideTimer?.cancel(); // 拖动时取消隐藏定时器
        },
        onDragEnd: () {
          setState(() {
            _dragging = false; // 结束拖动
          });

          _startHideTimer(); // 重启隐藏定时器
        },
        // 进度条颜色配置
        colors: chewieController.materialProgressColors ??
            ChewieProgressColors(
              playedColor: Theme.of(context).colorScheme.secondary, // 已播放颜色
              handleColor: Theme.of(context).colorScheme.secondary, // 滑块颜色
              bufferedColor:
              Theme.of(context).colorScheme.background.withOpacity(0.5), // 缓冲颜色
              backgroundColor: Theme.of(context).disabledColor.withOpacity(.5), // 背景颜色
            ),
      ),
    );
  }

}

/// 检查真实缓冲状态（优化原生isBuffering判断）
/// 仅当当前位置接近缓冲末尾且无后续缓冲时才视为真缓冲
bool _checkBuffering(VideoPlayerController controller) {
  //
  //  检查控制器缓冲状态
  //
  if (!controller.value.isBuffering) {
    // 控制器标记未缓冲
    return false;
  }
  //
  //  检查当前位置是否在缓冲范围内
  //
  final position = controller.value.position; // 当前播放位置
  final buffered = controller.value.buffered; // 缓冲区间列表
  // 查找包含当前位置的缓冲区间
  final current = buffered.firstWhere(
        (range) => range.start <= position && position <= range.end,
    orElse: () => _zeroRange,
  );
  if (current == _zeroRange) {
    // 无缓冲区间：确实在缓冲
    return true;
  }
  // 检查当前缓冲区间剩余长度
  final end = current.end - _safeDistance; // 缓冲末尾前8秒
  if (position < end) {
    // 当前位置离缓冲末尾还有足够距离：非真缓冲
    return false;
  }
  // 查找下一个缓冲区间
  for (var item in buffered) {
    if (item.start == current.end) {
      // 有后续缓冲：非真缓冲
      return false;
    }
  }
  // 当前位置接近缓冲末尾且无后续缓冲：真缓冲
  return true;
}

/// 空缓冲区间常量
final _zeroRange = DurationRange(Duration.zero, Duration.zero);
/// 安全距离（8秒）- 小于此距离视为需要缓冲
const _safeDistance = Duration(seconds: 8);