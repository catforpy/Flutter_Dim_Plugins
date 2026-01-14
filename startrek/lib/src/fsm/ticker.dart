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

import 'package:object_key/object_key.dart';
import 'package:startrek/fsm.dart';

/// 节拍器驱动接口（定义tick回调）
abstract interface class Ticker {
  /// 驱动当前线程向前运行
  ///
  /// @param now     - 当前时间
  /// @param elapsed - 距离上一次tick的时长
  Future<void> tick(DateTime now, Duration elapsed);
}

/// 节拍器（继承Runner，驱动所有注册的Ticker对象）
class Metronome extends Runner {
  // 最小休眠间隔（至少等待1/60秒）
  static Duration minInterval = Duration(
    microseconds: Duration.microsecondsPerSecond ~/ 60,
  ); //16毫秒

  Metronome(super.interval);

  late DateTime _lastTime; // 上一次tick的时间

  final Set<Ticker> _allTickers = WeakSet(); //弱引用存储Ticker对象(避免内存泄漏)

  /// 添加Tciker到节拍器(会被自动触发tick)
  void addTicker(Ticker ticker) => _allTickers.add(ticker);

  /// 从节拍器移除Ticker（停止触发tick）
  void removeTicker(Ticker ticker) => _allTickers.remove(ticker);

  /// 启动节拍器
  Future<void> start() async {
    if (isRunning) {
      // 已运行，先停止休眠
      await stop();
      await idle();
    }
    run();
  }

  @override
  Future<void> setup() async {
    await super.setup();
    // 初始化上一次tick时间为当前时间
    _lastTime = DateTime.now();
  }

  @override
  Future<bool> process() async {
    // 赋值当前所有Ticker(避免遍历中修改集合)
    Set<Ticker> tickers = _allTickers.toSet();
    if (tickers.isEmpty) {
      // 无Ticker需要驱动，返回false休眠
      return false;
    }
    // 1.时间检查：计算距离上一次tick的时长，确保休眠足够间隔
    DateTime now = DateTime.now();
    Duration elapsed = now.difference(_lastTime);
    Duration waiting = interval - elapsed;
    if (waiting < minInterval) {
      // 最小休眠时间兜底
      waiting = minInterval;
    }
    // 休眠指定时长
    await Runner.sleep(waiting);
    // 修正当前时间和已流逝时长
    now = now.add(waiting);
    elapsed = elapsed + waiting;
    // 驱动所有Ticker执行tick
    for (Ticker item in tickers) {
      try {
        await item.tick(now, elapsed);
      } catch (e, st) {
        // 捕获异常，避免单个Ticker异常影响整体
        await onError(e, st, item);
      }
    }

    // 3.更新上一次tick时间
    _lastTime = now;
    //返回true 表示有任务处理
    return true;
  }

  // 受保护方法： 处理Ticker执行异常(子类可重写)
  Future<void> onError(
    dynamic error,
    dynamic stacktrace,
    Ticker ticker,
  ) async {}
}

/// 全局单例节拍器(懒加载)
class PrimeMetronome {
  // 工厂构造函数：返回单例实例
  factory PrimeMetronome() => _instance;

  // 静态单例实力
  static final PrimeMetronome _instance = PrimeMetronome._internal();

  // 私有构造函数：初始化节拍器
  PrimeMetronome._internal() {
    _metronome = Metronome(Runner.INTERVAL_SLOW);
    _metronome.start();
  }

  late final Metronome _metronome; // 内部节拍器

  /// 添加Ticker到全局节拍器
  void addTicker(Ticker ticker) => _metronome.addTicker(ticker);

  /// 从全局节拍器移除Ticker
  void removeTicker(Ticker ticker) => _metronome.removeTicker(ticker);
}
