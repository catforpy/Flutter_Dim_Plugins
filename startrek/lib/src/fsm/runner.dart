/* license: https://mit-license.org
 *
 *  ObjectKey : Object & Key kits
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

/// 处理器接口（定义单次处理逻辑）
abstract interface class Processor {
  /// 执行处理逻辑
  ///
  /// @return 无任务可处理时返回false，有任务处理返回true
  Future<bool> process();
}

/// 处理器接口（定义生命周期：初始化/处理/清理）
abstract interface class Handler {
  /// 初始化（处理前准备）
  Future<void> setup();

  /// 处理循环（核心逻辑）
  Future<void> handle();

  /// 清理（处理完成后）
  Future<void> finish();
}

/// 可运行接口（定义线程执行入口）
abstract interface class Runnable {
  /// 在线程中执行
  Future<void> run();
}

/// 基础运行器（整合Runnable、Handler、Processor，封装循环执行逻辑）
abstract class Runner implements Runnable, Handler, Processor {
  // 帧率常量（控制循环休眠间隔）
  // ~~~~~~~~~~~~~~~~~
  // (1) 人眼每秒可处理10-12帧静态图像，动态补偿功能也会欺骗我们；
  // (2) 帧率低于12fps时，可快速区分静态图像和动画；
  // (3) 帧率达到16-24fps时，大脑会认为是连续运动的场景（电影效果）；
  // (4) 24fps时有"运动模糊"感，60fps时画面最流畅清晰。
  static Duration INTERVAL_SLOW = Duration(
    microseconds: Duration.microsecondsPerSecond ~/ 10,
  ); // 慢：100毫秒
  static Duration INTERVAL_NORMAL = Duration(
    microseconds: Duration.microsecondsPerSecond ~/ 25,
  ); // 正常：40毫秒
  static Duration INTERVAL_FAST = Duration(
    microseconds: Duration.microsecondsPerSecond ~/ 60,
  ); // 快：16毫秒

  Runner(this.interval) {
    assert(interval.inMicroseconds > 0, '间隔时间错误: $interval');
  }

  final Duration interval; //循环休眠间隔

  bool _running = false; //运行状态标记

  // 获取运行状态
  bool get isRunning => _running;

  // 停止运行期
  Future<void> stop() async => _running = false;

  @override
  Future<void> run() async {
    // 初始化
    await setup();
    try {
      // 执行处理循环
      await handle();
    } finally {
      // 无论是否异常，最终执行清理
      await finish();
    }
  }

  @override
  Future<void> setup() async {
    // 初始化时标记为运行中
    _running = true;
  }

  @override
  Future<void> finish() async {
    // 运行结束后标记为停止
    _running = false;
  }

  @override
  Future<void> handle() async {
    // 循环执行处理逻辑，直到停止
    while (isRunning) {
      if (await process()) {
        // process() 返回 true 表示有任务处理，返回 false 表示无任务处理
      } else {
        // process()返回false：无任务可处理，休眠指定间隔
        await idle();
      }
    }
  }

  // 受保护方法：休眠（子类可重写）
  Future<void> idle() async => await sleep(interval);

  // 静态方法：休眠指定时长
  static Future<void> sleep(Duration duration) async =>
      await Future.delayed(duration);
}
