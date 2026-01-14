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

import 'dart:ui'; // Flutter UI核心库（AppLifecycleState）

import 'package:dim_flutter/src/ui/nav.dart';
// import 'package:get/get.dart'; // GetX框架（国际化/状态管理）

import 'package:dim_client/ok.dart';     // DIM-SDK基础工具（日志/异步）
import 'package:dim_client/sdk.dart';    // DIM-SDK核心库（终端/会话/消息）
import 'package:dim_client/common.dart'; // DIM-SDK通用接口
import 'package:dim_client/client.dart'; // DIM-SDK客户端基类
import 'package:dim_client/ws.dart' hide Processor; // DIM-SDK WebSocket（隐藏冲突的Processor）

import '../common/constants.dart'; // 项目常量（通知名/状态枚举）
import '../models/station.dart';   // 服务器站点模型
import '../network/neighbor.dart'; // 邻居服务器网络逻辑
import 'compat/device.dart';      // 设备信息兼容层

import 'messenger.dart'; // 自定义消息发送器
import 'packer.dart';    // 自定义消息打包器
import 'processor.dart'; // 自定义内容处理器
import 'shared.dart';    // 全局变量/单例

/// 客户端核心类：继承DIM-SDK的Terminal基类，实现完整的客户端生命周期管理
/// 核心职责：
/// 1. 会话状态管理（连接/握手/运行/断开）
/// 2. 应用生命周期适配（前台/后台切换）
/// 3. 消息发送队列管理（待发送消息的缓存与发送）
/// 4. 设备/应用信息封装
/// 5. 服务器连接管理（重连/状态通知）
class Client extends Terminal {
  /// 构造方法：初始化客户端，传入身份管理（facebook）和数据存储（sdb）
  /// [facebook] - 身份管理核心（用户ID/密钥/文档）
  /// [sdb] - 安全数据库（存储敏感信息）
  Client(super.facebook, super.sdb);

  // ===================== 会话状态相关属性 =====================
  /// 获取当前会话状态（连接/握手/运行等）
  SessionState? get sessionState => session?.state;

  /// 获取会话状态的排序索引（用于状态判断）
  int get sessionStateOrder =>
      sessionState?.index ?? SessionStateOrder.init.index;
  
  /// 获取会话状态的本地化文本（用于UI展示）
  String? get sessionStateText {
    int order = sessionStateOrder;
    if (order == SessionStateOrder.init.index) {
      return i18nTranslator.translate('Waiting');  // 等待连接（GetX国际化）
    } else if (order == SessionStateOrder.connecting.index) {
      return i18nTranslator.translate('Connecting'); // 连接中
    } else if (order == SessionStateOrder.connected.index) {
      return i18nTranslator.translate('Connected');  // 已连接
    } else if (order == SessionStateOrder.handshaking.index) {
      return i18nTranslator.translate('Handshaking');// 握手中
    } else if (order == SessionStateOrder.running.index) {
      return null;  // 正常运行（无需显示状态）
    } else {
      reconnect(); // 异常状态自动重连
      return i18nTranslator.translate('Disconnected'); // 已断开
    }
  }

  /// 重连到邻居服务器：核心连接逻辑
  /// 返回：新创建的客户端消息发送器（null表示重连失败）
  Future<ClientMessenger?> reconnect() async {
    // 获取邻居服务器信息（负载均衡/就近连接）
    NeighborInfo? station = await getNeighborStation();
    if(station == null){
      logError('failed to get neighbor station');
      return null;
    }
    logWarning('connecting to station: $station');
    // 注释掉的代码：测试用固定服务器地址
    // return await connect('192.168.31.152', 9394);
    // return await connect('170.106.141.194', 9394);
    // return await connect('129.226.12.4', 9394);
    
    // 连接到动态获取的服务器
    return await connect(station.host, station.port);
  }

  // 注释掉的代码：自定义会话创建逻辑（使用SDK默认实现）
  // @override
  // ClientSession createSession(Station station) {
  //   ClientSession session = ClientSession(sdb, station);
  //   session.start(this);
  //   return session;
  // }

  /// 重写：创建自定义消息发送器（单例管理）
  /// [session] - 客户端会话
  /// [facebook] - 身份管理实例
  /// 返回：共享的消息发送器实例
  @override
  ClientMessenger createMessenger(ClientSession session, CommonFacebook facebook) {
    GlobalVariable shared = GlobalVariable();
    SharedMessenger messenger = SharedMessenger(session, facebook, shared.database);
    shared.messenger = messenger; // 存入全局变量，方便全局调用
    return messenger;
  }

  /// 重写：创建自定义消息打包器
  /// [facebook] - 身份管理实例
  /// [messenger] - 消息发送器
  /// 返回：共享的消息打包器实例
  @override
  Packer createPacker(CommonFacebook facebook, ClientMessenger messenger) {
    return SharedPacker(facebook, messenger);
  }

  /// 重写：创建自定义内容处理器
  /// [facebook] - 身份管理实例
  /// [messenger] - 消息发送器
  /// 返回：共享的内容处理器实例
  @override
  Processor createProcessor(CommonFacebook facebook, ClientMessenger messenger) {
    return SharedProcessor(facebook, messenger);
  }

  // ===================== 应用生命周期管理 =====================
  /// 应用进入后台：处理离线上报+暂停会话
  Future<void> enterBackground() async {
    ClientMessenger? transceiver = messenger;
    if (transceiver == null) {
      // 未连接服务器，直接返回
      logError('App Lifecycle::enterBackground | not connected yet');
      return;
    }
    logInfo("App Lifecycle::enterBackground | report offline before pause session");
    
    // 获取当前会话，检查登录状态
    ClientSession? cs = transceiver.session;
    ID? uid = cs.identifier;    // 当前登录用户ID
    if(uid != null){
      // 已登录，检查会话状态
      SessionState? state = cs.state;
      logInfo('session state: $state');
      if(state?.index == SessionStateOrder.running.index){
        // 会话正常运行：上报离线状态
        await transceiver.reportOffline(uid);
        // 等待512ms，确保上报命令发送完成
        await Runner.sleep(const Duration(milliseconds: 512));
      }
    }
    // 暂停会话（停止心跳/消息接收）
    await cs.pause();
  }

   /// 应用进入前台：恢复会话+上报在线状态
  Future<void> enterForeground() async {
    ClientMessenger? transceiver = messenger;
    if(transceiver == null){
      // 未连接服务器，直接返回
      logError('App Lifecycle::enterForeground | not connected yet');
      return;
    }
    logInfo("App Lifecycle::enterForeground | report online after resume session");
    ClientSession cs = transceiver.session;

    // 恢复会话（重启心跳/消息接收）
    await cs.resume();

    // 检查登录状态
    ID? uid = cs.identifier;
    if(uid != null){
      // 等待512ms，确保会话恢复完成
      await Runner.sleep(const Duration(milliseconds: 512));
      SessionState? state = cs.state;
      logInfo('session state: $state');
      if (state?.index == SessionStateOrder.running.index) {
        // 会话正常运行：上报在线状态
        await transceiver.reportOnline(uid);
      }
    }
  }

  /// 应用生命周期状态变更处理：分发到前台/后台逻辑
  /// [state] - Flutter应用生命周期状态
  Future<void> onAppLifecycleStateChanged(AppLifecycleState state) async {
    GlobalVariable shared = GlobalVariable();
    switch(state){
      case AppLifecycleState.resumed:
        // 应用回复到前台
        logWarning('AppLifecycleState::enterForeground $state bg=${shared.isBackground}');
        driveConnection(inBackground: false); // 更新连接的后台状态
        if (shared.isBackground != false) {
          shared.isBackground = false; // 更新全局后台标记
          await enterForeground();
        }
        break;
      // case AppLifecycleState.inactive:
      //   // 应用非活动状态（如来电），暂不处理
      //   break;
      case AppLifecycleState.paused:    // 应用暂停（退到后台）
      case AppLifecycleState.hidden:    // 应用隐藏
      case AppLifecycleState.detached:  // 应用脱离（销毁）
        logWarning('AppLifecycleState::enterBackground $state bg=${shared.isBackground}');
        if (shared.isBackground != true) {
          shared.isBackground = true; // 更新全局后台标记
          await enterBackground();
        }
        driveConnection(inBackground: true); // 更新连接的后台状态
        break;
      default:
        logInfo("AppLifecycleState::unknown state=$state bg=${shared.isBackground}");
        break;
    }
  }

  /// 驱动连接状态更新：设置连接的后台标记
  /// [inBackground] - 是否在后台
  /// 返回：是否更新成功
  bool driveConnection({required bool inBackground}) {
    ClientMessenger? transceiver = messenger;
    ClientSession? session = transceiver?.session;
    Connection? connection = session?.connection;
    
    if (connection is ActiveConnection) {
      // 活跃连接：更新后台状态
      logInfo('background connection: ${connection.inBackground} -> $inBackground');
      connection.inBackground = inBackground;
      return true;
    } else {
      // 连接异常：记录警告
      logWarning('connection error: $connection');
      return false;
    }
  }

  // ===================== 消息发送队列管理 =====================
  /// 待发送消息队列：Triplet<接收者ID, 消息内容, 优先级>
  /// 作用：缓存未发送的消息，会话就绪后批量发送
  final List<Triplet<ID, Content, int>> _outgoing = [];

  /// 添加待发送消息到队列
  /// [content] - 消息内容
  /// [receiver] - 接收者ID（必填）
  /// [priority] - 消息优先级（默认0，数值越高优先级越高）
  void addWaitingContent(Content content, {required ID receiver, int priority = 0}) =>
      _outgoing.add(Triplet(receiver, content, priority));

  /// 批量发送待发送队列中的消息
  /// [uid] - 发送者ID（当前登录用户）
  /// [messenger] - 消息发送器
  /// 返回：成功发送的消息数量
  Future<int> _sendWaitingContents(ID uid, ClientMessenger messenger) async {
    ID receiver;
    Content content;
    int prior;
    Triplet<ID, Content, int> triplet;
    Pair<InstantMessage, ReliableMessage?> res;
    int success = 0;

    // 循环发送队列中的所有消息
    while (_outgoing.isNotEmpty) {
      triplet = _outgoing.removeAt(0); // 取出队列头部消息（FIFO）
      receiver = triplet.first;       // 接收者ID
      content = triplet.second;       // 消息内容
      prior = triplet.third;          // 优先级

      logInfo('[safe channel] send content: $receiver, $content');
      // 发送消息：返回即时消息+可靠消息对
      res = await messenger.sendContent(
        content, 
        sender: uid, 
        receiver: receiver, 
        priority: prior
      );
      // 可靠消息非空表示发送成功
      if (res.second != null) {
        success += 1;
      }
    }
    return success;
  }

  /// 重写：客户端核心处理逻辑（SDK主循环调用）
  /// 作用：检查并发送待发送队列中的消息
  /// 返回：是否有消息发送成功
  @override
  Future<bool> process() async {
    // 队列为空：执行父类默认逻辑
    if (_outgoing.isEmpty) {
      return await super.process();
    }

    // 检查会话状态：确保已连接+已登录+会话正常运行
    ClientMessenger? transceiver = messenger;
    if (transceiver == null) {
      // 未连接服务器，发送失败
      return false;
    }
    ClientSession session = transceiver.session;
    ID? uid = session.identifier;          // 当前登录用户ID
    SessionState? state = session.state;   // 当前会话状态

    // 未登录或会话未正常运行：发送失败
    if (uid == null || state?.index != SessionStateOrder.running.index) {
      return false;
    }

    // 批量发送待发送消息
    int success = await _sendWaitingContents(uid, transceiver);
    return success > 0;
  }

  // ===================== 状态机委托 =====================
  /// 重写：会话状态退出时的处理逻辑
  /// [previous] - 上一个状态
  /// [ctx] - 状态机上下文
  /// [now] - 状态变更时间
  @override
  Future<void> exitState(SessionState? previous, SessionStateMachine ctx, DateTime now) async {
    await super.exitState(previous, ctx, now);
    SessionState? current = ctx.currentState;
    // 记录状态变更日志
    logInfo('server state changed: $previous => $current');
    
    // 发送会话状态变更通知（UI层监听该通知刷新状态）
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kServerStateChanged, this, {
      'previous': previous,
      'current': current,
    });
  }

  // ===================== 设备/应用信息封装（DeviceMixin） =====================
  /// 设备信息实例（单例）
  final DeviceInfo _deviceInfo = DeviceInfo();
  /// 应用包信息实例（单例）
  final AppPackageInfo _packageInfo = AppPackageInfo();

  /// 应用包名
  String get packageName => _packageInfo.packageName;

  /// 应用显示名称（重写父类）
  @override
  String get displayName => _packageInfo.displayName;

  /// 应用版本名称（重写父类）
  @override
  String get versionName => _packageInfo.versionName;

  /// 应用构建号
  String get buildNumber => _packageInfo.buildNumber;

  /// 系统语言（重写父类）
  @override
  String get language => _deviceInfo.language;

  /// 系统版本（重写父类）
  @override
  String get systemVersion => _deviceInfo.systemVersion;

  /// 设备型号（重写父类）
  @override
  String get systemModel => _deviceInfo.systemModel;

  /// 设备代号（重写父类）
  @override
  String get systemDevice => _deviceInfo.systemDevice;

  /// 设备品牌（重写父类）
  @override
  String get deviceBrand => _deviceInfo.deviceBrand;

  /// 主板型号（重写父类）
  @override
  String get deviceBoard => _deviceInfo.deviceBoard;

  /// 设备制造商（重写父类）
  @override
  String get deviceManufacturer => _deviceInfo.deviceManufacturer;
}