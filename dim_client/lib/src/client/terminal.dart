/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2025 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2025 Albert Moky
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

import 'package:dimsdk/dimsdk.dart';
import 'package:lnc/log.dart';
import 'package:stargate/skywalker.dart' show Runner;
import 'package:stargate/startrek.dart';

import '../common/dbi/session.dart';
import '../common/facebook.dart';

import 'messenger.dart';
import 'network/session.dart';
import 'network/state.dart';

/// 设备信息混入类
/// 提供设备相关信息和用户代理字符串生成
mixin DeviceMixin {
  /// 获取语言（如：zh-CN）
  String get language;

  /// 获取应用显示名称（如：DIM）
  String get displayName;

  /// 获取应用版本名（如：1.0.1）
  String get versionName;

  /// 获取系统版本（如：4.0）
  String get systemVersion;

  /// 获取系统型号（如：HMS）
  String get systemModel;

  /// 获取系统设备名（如：hammerhead）
  String get systemDevice;

  /// 获取设备品牌（如：HUAWEI）
  String get deviceBrand;

  /// 获取设备主板名（如：hammerhead）
  String get deviceBoard;

  /// 获取设备制造商（如：HUAWEI）
  String get deviceManufacturer;

  /// 生成用户代理字符串
  /// 格式：DIMP/1.0 (Linux; U; Android 4.1; zh-CN) DIMCoreKit/1.0 (Terminal, like WeChat) DIM-by-GSP/1.0.1
  String get userAgent {
    String model = systemModel;
    String device = systemDevice;
    String sysVersion = systemVersion;
    String lang = language;

    String appName = displayName;
    String appVersion = versionName;

    return "DIMP/1.0 ($model; U; $device $sysVersion; $lang)"
        " DIMCoreKit/1.0 (Terminal, like WeChat) $appName-by-MOKY/$appVersion";
  }
}

/// 终端核心类
/// 整合会话管理、设备信息、状态机委托，实现客户端核心逻辑
abstract class Terminal extends Runner with DeviceMixin, Logging
    implements SessionStateDelegate {
  /// 构造方法
  /// [facebook]：用户/群组信息管理
  /// [database]：会话数据库
  Terminal(this.facebook, this.database)
      : super(ACTIVE_INTERVAL);

  /// 活跃检查间隔（60秒）
  static Duration ACTIVE_INTERVAL = Duration(seconds: 60);

  /// 会话数据库接口
  final SessionDBI database;
  /// Facebook实例
  final CommonFacebook facebook;

  /// 客户端消息器（核心通信组件）
  ClientMessenger? _messenger;

  /// 最后在线时间
  DateTime? _lastOnlineTime;

  /// 获取消息器实例
  ClientMessenger? get messenger => _messenger;

  /// 获取客户端会话
  ClientSession? get session => _messenger?.session;

  //
  //  连接管理
  //

  /// 连接到指定节点
  /// [host]：节点主机
  /// [port]：节点端口
  /// 返回：客户端消息器
  Future<ClientMessenger> connect(String host, int port) async {
    //
    //  0. 检查旧会话
    //
    ClientMessenger? old = _messenger;
    if (old != null) {
      ClientSession session = old.session;
      if (session.isActive) {
        // 当前会话活跃
        Station station = session.station;
        logDebug('current station: $station');
        if (station.port == port && station.host == host) {
          // 目标相同，直接返回
          logWarning('active session connected to $host:$port .');
          return old;
        }
      }
      // 停止旧会话
      await session.stop();
      _messenger = null;
    }
    logInfo('connecting to $host:$port ...');
    //
    //  1. 创建新会话
    //
    Station station = createStation(host, port);
    ClientSession session = createSession(station);
    //
    //  2. 创建消息器
    //
    ClientMessenger transceiver = createMessenger(session, facebook);
    _messenger = transceiver;
    // 设置消息器弱引用
    session.messenger = transceiver;
    //
    //  3. 创建打包器和处理器
    //
    transceiver.packer = createPacker(facebook, transceiver);
    transceiver.processor = createProcessor(facebook, transceiver);
    //
    //  4. 登录当前用户
    //
    User? user = await facebook.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
    } else {
      session.setIdentifier(user.identifier);
    }
    return transceiver;
  }

  // 受保护方法：创建节点实例
  Station createStation(String host, int port) {
    Station station = Station.fromRemote(host, port);
    station.dataSource = facebook;
    return station;
  }

  // 受保护方法：创建客户端会话
  ClientSession createSession(Station station) {
    ClientSession session = ClientSession(database, station);
    session.start(this);
    return session;
  }

  // 受保护方法：创建消息打包器（抽象方法，由子类实现）
  Packer createPacker(CommonFacebook facebook, ClientMessenger messenger);

  // 受保护方法：创建消息处理器（抽象方法，由子类实现）
  Processor createProcessor(CommonFacebook facebook, ClientMessenger messenger);

  // 受保护方法：创建客户端消息器（抽象方法，由子类实现）
  ClientMessenger createMessenger(ClientSession session, CommonFacebook facebook);

  /// 登录指定用户
  /// [user]：用户ID
  /// 返回：是否登录成功
  bool login(ID user) {
    ClientSession? cs = session;
    if (cs == null) {
      return false;
    }
    cs.setIdentifier(user);
    return true;
  }

  //
  //  线程管理
  //

  /// 启动终端
  Future<void> start() async {
    if (isRunning) {
      await stop();
      await idle();
    }
    await run();
  }

  /// 结束终端（重载以停止会话）
  @override
  Future<void> finish() async {
    // 停止消息器中的会话
    ClientMessenger? transceiver = messenger;
    if (transceiver != null) {
      _messenger = null;
      ClientSession cs = transceiver.session;
      await cs.stop();
    }
    await super.finish();
  }

  /// 空闲等待（16秒）
  @override
  Future<void> idle() async =>
      await Runner.sleep(Duration(seconds: 16));

  /// 处理循环任务（保持在线）
  @override
  Future<bool> process() async {
    //
    //  1. 检查连接状态
    //
    if (session?.state?.index != SessionStateOrder.running.index) {
      // 握手未完成
      return false;
    } else if (session?.isReady != true) {
      // 会话未就绪
      return false;
    }
    //
    //  2. 检查在线超时
    //
    DateTime now = DateTime.now();
    if (needsKeepOnline(_lastOnlineTime, now)) {
      // 更新最后在线时间
      _lastOnlineTime = now;
    } else {
      // 未超时
      return false;
    }
    //
    //  3. 每5分钟发送在线报告
    //
    try {
      await keepOnline();
    } catch (e, st) {
      logError('Terminal error: $e, $st');
    }
    return false;
  }

  // 受保护方法：判断是否需要发送在线报告
  bool needsKeepOnline(DateTime? last, DateTime now) {
    if (last == null) {
      // 未登录
      return false;
    }
    // 每5分钟发送一次
    return last.add(Duration(seconds: 300)).isBefore(now);
  }

  // 受保护方法：保持在线状态
  Future<void> keepOnline() async {
    User? user = await facebook.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
    } else if (user.type == EntityType.STATION) {
      // 节点仅发送在线报告
      await messenger?.reportOnline(user.identifier);
    } else {
      // 普通用户发送登录命令
      await messenger?.broadcastLogin(user.identifier, userAgent);
    }
  }

  //
  //  状态机委托方法
  //

  /// 进入状态前回调
  @override
  Future<void> enterState(SessionState? next, SessionStateMachine ctx, DateTime now) async {
    // 预留扩展
  }

  /// 退出状态后回调
  @override
  Future<void> exitState(SessionState? previous, SessionStateMachine ctx, DateTime now) async {
    SessionState? current = ctx.currentState;
    if (current == null || current.index == SessionStateOrder.error.index) {
      // 错误状态，重置在线时间
      _lastOnlineTime = null;
      return;
    }
    if (current.index == SessionStateOrder.init.index ||
        current.index == SessionStateOrder.connecting.index) {
      // 初始化/连接中状态
      ID? user = ctx.sessionID;
      if (user == null) {
        logWarning('current user not set');
        return;
      }
      logInfo('connect for user: $user');
      // 检查远程地址
      SocketAddress? remote = session?.remoteAddress;
      if (remote == null) {
        logWarning('failed to get remote address: $session');
        return;
      }
      // 检查连接
      Porter? docker = await session?.gate.fetchPorter(remote: remote);
      if (docker == null) {
        logError('failed to connect: $remote');
      } else {
        logInfo('connected to: $remote');
      }
    } else if (current.index == SessionStateOrder.handshaking.index) {
      // 握手状态，启动握手
      await messenger?.handshake(null);
    } else if (current.index == SessionStateOrder.running.index) {
      // 运行状态，握手成功
      await messenger?.handshakeSuccess();
      // 更新最后在线时间
      _lastOnlineTime = now;
    }
  }

  /// 暂停状态回调
  @override
  Future<void> pauseState(SessionState? current, SessionStateMachine ctx, DateTime now) async {
    // 预留扩展
  }

  /// 恢复状态回调
  @override
  Future<void> resumeState(SessionState? current, SessionStateMachine ctx, DateTime now) async {
    // TODO: 重新登录时清理会话密钥
  }
}