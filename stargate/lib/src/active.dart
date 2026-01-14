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

import 'package:stargate/skywalker.dart';
import 'package:stargate/startrek.dart';

/// 客户端主动连接类（核心）
/// 核心职责：
/// 1. 管理客户端与服务器的主动连接生命周期；
/// 2. 后台线程循环检测连接状态，自动重连；
/// 3. 关联Hub（连接管理器），获取/更新Channel（通道）；
/// 设计思路：基于Runnable实现后台线程，结合ConnectionDriver实现连接驱动；
class ActiveConnection extends BaseConnection implements Runnable {
  /// 构造方法
  /// [remote] - 远程地址
  /// [local] - 本地地址
  ActiveConnection({super.remote, super.local});

  /// Hub的弱引用（避免循环强引用导致内存泄漏）
  WeakReference<Hub>? _hubRef;

  /// 是否处于后台状态（非活跃）
  bool inBackground = false;

  /// 判断连接是否已关闭（状态机为空则视为关闭）
  @override
  bool get isClosed => stateMachine == null;

  /// 启动连接（核心入口）
  /// [hub] - 连接管理器（Hub）
  @override
  Future<void> start(Hub hub) async {
    /// 保存Hub的弱引用
    _hubRef = WeakReference(hub);
    // 1.启动状态机（管理连接状态流转）
    await startMachine();
    // 2.启动后台线程(检测连接状态、自动重连)
    run();
  }

  /// 后台线程运行逻辑（核心：循环检测连接状态）
  @override
  Future<void> run() async {
    // 定义检测间隔(1秒)和后台休眠间隔(4秒)
    final Duration interval = Duration(milliseconds: 1024);
    final Duration sleeping = Duration(milliseconds: 4096);

    // 休眠1秒
    await Runner.sleep(interval);
    var driver = _ConnectionDriver(remote: remoteAddress);
    driver.setChannel(channel);

    //
    //  核心循环：持续检测连接状态
    //
    while (true) {
      // 每次循环休眠1秒
      await Runner.sleep(interval);
      // 从弱引用获取Hub（非空检查）
      Hub? hub = _hubRef?.target;
      if (hub == null) {
        //Hub为空->断言错误，退出循环
        assert(false, 'hub not found: $localAddress -> $remoteAddress');
        break;
      } else if (isClosed) {
        // 连接已关闭 -> 打印日志，退出循环
        logInfo('connection closed: $localAddress -> $remoteAddress');
        break;
      } else if (inBackground) {
        // 后台非活跃状态 → 延长休眠时间（4秒）
        logInfo(
          'connection in background: $localAddress -> $remoteAddress'
          ', connected: $isConnected',
        );
        await Runner.sleep(sleeping);
        continue;
      }

      //
      //  检查并重连（核心逻辑）
      //
      try {
        // 通过驱动获取新的Channel
        Channel? sock = await driver.drive(hub);
        if (sock != null) {
          // 获取到新Channel → 打印日志并更新连接的Channel
          logInfo('new socket channel: $sock, $this');
          await setChannel(sock);
        }
      } catch (e, st) {
        // 连接异常 → 记录日志并回调错误
        logError('connection error: $e, $st');
        var error = IOError(e);
        await delegate?.onConnectionError(error, this);
      }
    }
    // 循环结束 → 打印退出日志
    logInfo('connection exits: $remoteAddress');
  }

  // protected：打印信息日志
  void logInfo(String msg) {
    print('[ActiveConnection]         | $msg');
  }

  // protected：打印错误日志
  void logError(String msg) {
    print('[ActiveConnection]  ERROR  | $msg');
  }
}

/// 连接驱动类（核心：管理连接的重连逻辑）
/// 核心职责：
/// 1. 检测Channel的存活状态；
/// 2. 处理连接超时、重连间隔；
/// 3. 从Hub获取新的Channel，实现自动重连；
class _ConnectionDriver extends AddressPairObject {
  /// 构造方法
  _ConnectionDriver({super.remote});

  /// 连接过期间隔（128秒，毫秒）
  static int EXPIRED_INTERVAL = Duration(seconds: 128).inMilliseconds;

  /// 重连间隔（32秒，毫秒）
  static int RETRY_INTERVAL = Duration(seconds: 32).inMilliseconds;

  /// 过期时间戳（毫秒）
  int _expiredTime = 0;

  /// 重连时间戳（毫秒）
  int _retryTime = 0;

  /// Channel的弱引用（避免内存泄漏）
  WeakReference<Channel>? _channelRef;

  /// 设置Channel（更新弱引用）
  void setChannel(Channel? sock) {
    if (sock == null) {
      _channelRef = null;
    } else {
      _channelRef = WeakReference(sock);
    }
  }

  /// 移除Channel（从Hub中移除并关闭）
  // protected
  Future<Channel?> removeChannel(Channel sock, Hub hub) async {
    if (hub is BaseHub) {
      // BaseHub → 正常处理（原代码注释：断言错误，实际保留）
      // assert(false, 'hub error: $hub');
    } else {
      // 非BaseHub → 断言错误，返回null
      assert(false, 'hub error: $hub');
      return null;
    }
    // 从Hub中移除Channel
    Channel? cached = hub.removeChannel(
      sock,
      remote: sock.remoteAddress,
      local: sock.localAddress,
    );
    if (cached != null) {
      logWarning('remove cached channel: $cached');
    } else {
      logWarning('channel removed: $sock');
    }
    // 关闭移除/错误的Channel
    if (cached == null || identical(cached, sock)) {
    } else {
      await hub.closeChannel(cached);
    }
    await hub.closeChannel(sock);
    return cached;
  }

  /// 驱动连接（核心：检测并获取新Channel）
  Future<Channel?> drive(Hub hub) async {
    //获取当前时间戳(毫秒)
    int now = DateTime.now().millisecondsSinceEpoch;
    // 从弱引用获取当前Channel
    Channel? sock = _channelRef?.target;
    if (sock != null) {
      if (sock.isAlive) {
        // Channel存活 → 清空过期时间
        _expiredTime = 0;
      } else if (sock.isClosed) {
        // 连接丢失 → 移除Channel，清空过期时间
        logWarning('connection lost: $remoteAddress, $sock');
        await removeChannel(sock, hub);
        _channelRef = null;
        _expiredTime = 0;
      } else if (0 < _expiredTime && _expiredTime < now) {
        // 连接超时 → 移除Channel，清空过期时间
        logWarning('connect timeout: $remoteAddress, $sock');
        await removeChannel(sock, hub);
        _channelRef = null;
        _expiredTime = 0;
      }
      // 当前Channel有效 → 返回null（无需更新）
      return null;
    } else if (now < _retryTime) {
      // 未到重连时间 → 返回null
      return null;
    } else {
      // 到重连时间 → 更新重连时间戳
      _retryTime = now + RETRY_INTERVAL;
    }
    //
    //  尝试从Hub打开新的Channel
    //
    sock = await hub.open(remote: remoteAddress, local: localAddress);
    if (sock != null) {
      // 获取到新Channel → 记录日志，设置过期时间
      logInfo('open socket channel: $remoteAddress, $sock');
      _channelRef = WeakReference(sock);
      _expiredTime = now + EXPIRED_INTERVAL;
    } else {
      // 打开失败 → 记录错误
      logError('failed to open socket channel: $remoteAddress');
    }
    return sock;
  }

  // protected：打印警告日志
  void logWarning(String msg) {
    print('[ConnectionDriver] WARNING | $msg');
  }

  // protected：打印信息日志
  void logInfo(String msg) {
    print('[ConnectionDriver]         | $msg');
  }

  // protected：打印错误日志
  void logError(String msg) {
    print('[ConnectionDriver]  ERROR  | $msg');
  }
}
