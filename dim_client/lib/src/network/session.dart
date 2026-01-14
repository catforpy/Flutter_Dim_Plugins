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

import 'dart:typed_data';

import 'package:lnc/log.dart';
import 'package:object_key/object_key.dart';
import 'package:stargate/skywalker.dart';
import 'package:stargate/stargate.dart';
import 'package:stargate/startrek.dart';
import 'package:dimsdk/dimsdk.dart';

import '../common/dbi/session.dart';
import '../common/messenger.dart';
import '../common/session.dart';

import 'keeper.dart';
import 'queue.dart';

/// 基础会话类（抽象类）
/// 继承自Runner，实现Session和PorterDelegate接口
/// 负责管理单个会话的连接、消息队列、状态等
abstract class BaseSession extends Runner
    with Logging
    implements Session, PorterDelegate {
  /// 构造方法
  /// [_db]：会话数据库接口
  /// [remote]：远程地址
  BaseSession(this._db, {required SocketAddress remote})
    : super(Runner.INTERVAL_SLOW) {
    _remoteAddress = remote;
    _queue = MessageQueue();
  }

  /// 网关管理器单例
  static final GateKeeper keeper = GateKeeper();

  /// 获取网关实例
  CommonGate get gate => keeper.gate;

  /// 会话数据库接口
  final SessionDBI _db;

  /// 远程地址
  late final SocketAddress _remoteAddress;

  /// 消息队列
  late final MessageQueue _queue;

  /// 会话激活状态
  bool _active = false;

  /// 最后激活时间（更新状态的时间）
  DateTime? _lastActiveTime; // last update time

  /// 会话关联的用户ID
  ID? _identifier;

  /// 消息收发器（弱引用，防止内存泄漏）
  WeakReference<CommonMessenger>? _transceiver;

  /// 实现Session接口：获取数据库接口
  @override
  SessionDBI get database => _db;

  /// 实现Session接口：获取远程地址
  @override
  SocketAddress get remoteAddress => _remoteAddress;

  /// 实现Session接口：获取会话激活状态
  @override
  bool get isActive => _active;

  /// 实现Session接口：设置会话激活状态
  /// [flag]：激活标记
  /// [when]：状态更新时间（null表示当前时间）
  /// 返回：是否成功设置（状态未变化/时间无效则返回false）
  @override
  bool setActive(bool flag, DateTime? when) {
    if (_active == flag) {
      // 状态未变化，返回false
      return false;
    }
    DateTime? last = _lastActiveTime;
    if (when == null) {
      when = DateTime.now();
    } else if (last != null && !when.isAfter(last)) {
      // 更新时间不晚于最后激活时间，返回false
      return false;
    }
    // 更新激活状态和最后激活时间
    _active = flag;
    _lastActiveTime = when;
    return true;
  }

  /// 实现Session接口：获取关联的用户ID
  @override
  ID? get identifier => _identifier;

  /// 实现Session接口：设置关联的用户ID
  /// [user]：用户ID
  /// 返回：是否成功设置（ID未变化则返回false）
  @override
  bool setIdentifier(ID? user) {
    if (_identifier == null) {
      if (user == null) {
        return false;
      }
    } else if (identifier == user) {
      return false;
    }
    // 更新用户ID
    _identifier = user;
    return true;
  }

  /// 获取消息收发器（从弱引用中获取）
  CommonMessenger? get messenger => _transceiver?.target;

  /// 设置消息收发器（弱引用）
  set messenger(CommonMessenger? transceiver) =>
      _transceiver = transceiver == null ? null : WeakReference(transceiver);

  /// 实现Session接口：将消息包加入队列
  /// [rMsg]：可靠消息
  /// [data]：消息二进制数据
  /// [priority]：发送优先级
  /// 返回：是否加入成功（false表示重复）
  @override
  bool queueMessagePackage(
    ReliableMessage rMsg,
    Uint8List data, {
    int priority = 0,
  }) => queueAppend(rMsg, PlainDeparture(data, priority, false));

  /// 保护方法：将消息加入队列
  /// [rMsg]：可靠消息
  /// [ship]：出发数据包
  /// 返回：是否加入成功
  // protected
  bool queueAppend(ReliableMessage rMsg, Departure ship) =>
      _queue.append(rMsg, ship);

  /// 实现Runner接口：初始化会话
  @override
  Future<void> setup() async {
    await super.setup();
    // 添加自身为网关管理器的监听器
    keeper.addListener(this);
    // await keeper.connect(remote: remoteAddress);
    // 重新连接远程地址
    await keeper.reconnect(remote: remoteAddress);
  }

  /// 实现Runner接口：结束会话
  @override
  Future<void> finish() async {
    // await keeper.disconnect(remote: remoteAddress);
    // 移除自身作为网关管理器的监听器
    keeper.removeListener(this);
    await super.finish();
  }

  /// 重连时间戳（防止频繁重连）
  int _reconnectTime = 0;

  /// 实现Runner接口：处理会话逻辑（核心方法）
  @override
  Future<bool> process() async {
    // 获取对应远程地址的Porter（通信端口）
    Porter? docker = gate.getPorter(remote: remoteAddress);
    if (docker == null) {
      int now = DateTime.now().millisecondsSinceEpoch;
      if (now < _reconnectTime) {
        // 未到重连时间，返回false
        return false;
      }
      logInfo('fetch docker: $remoteAddress');
      // 尝试获取Porter
      docker = await gate.fetchPorter(remote: remoteAddress);
      if (docker == null) {
        logError('gate error: $remoteAddress');
        // 设置8秒后重试
        _reconnectTime = now + 8000;
        return false;
      }
    }
    // 处理入站/出栈消息
    try {
      bool busy = await keeper.process();
      if (busy) {
        // 有消息处理，返回true
        return true;
      }
    } catch (e, st) {
      logError('gate process error: $e, $st');
      return false;
    }
    if (!isActive) {
      // 会话未激活，返回false
      _queue.purge();
      return false;
    }
    // 获取吓一条待发送消息
    MessageWrapper? wrapper = _queue.next();
    if (wrapper == null) {
      // 队列为空，清理空队列并返回false
      _queue.purge();
      return false;
    }
    // 检查消息是否为空（已发送成功的消息会被置空）
    ReliableMessage? msg = wrapper.message;
    if (msg == null) {
      // 消息已发送，返回true
      return true;
    }
    // 尝试发送消息
    bool ok = await docker.sendShip(wrapper);
    if (!ok) {
      logError('docker error: $_remoteAddress, $docker');
    }
    return true;
  }

  //
  //  Transmitter（发送器接口实现）
  //

  /// 发送消息内容
  /// [content]：消息内容
  /// [sender]：发送者ID
  /// [receiver]：接收者ID
  /// [priority]：发送优先级
  /// 返回：即时消息和可靠消息对
  @override
  Future<Pair<InstantMessage, ReliableMessage?>> sendContent(
    Content content, {
    required ID? sender,
    required ID receiver,
    int priority = 0,
  }) async => await messenger!.sendContent(
    content,
    sender: sender,
    receiver: receiver,
    priority: priority,
  );

  /// 发送即时消息
  /// [iMsg]：即时消息
  /// [priority]：发送优先级
  /// 返回：可靠消息（null表示失败）
  @override
  Future<ReliableMessage?> sendInstantMessage(
    InstantMessage iMsg, {
    int priority = 0,
  }) async => await messenger!.sendInstantMessage(iMsg, priority: priority);

  /// 发送可靠消息
  /// [rMsg]：可靠消息
  /// [priority]：发送优先级
  /// 返回：是否发送成功
  @override
  Future<bool> sendReliableMessage(ReliableMessage rMsg, {
    int priority = 0,
  }) async => await messenger!.sendReliableMessage(rMsg, priority: priority);

  //
  //  Docker Delegate（PorterDelegate接口实现）
  //

  /// Porter状态变更回调
  @override
  Future<void> onPorterStatusChanged(PorterStatus previous, PorterStatus current, Porter porter) async {
    logInfo('docker status changed: $previous => $current, $porter');
  }

  /// Porter收到消息回调
  @override
  Future<void> onPorterReceived(Arrival ship, Porter porter) async {
    logDebug('docker received a ship: $ship, $porter');
  }

  /// Porter发送消息成功回调
  @override
  Future<void> onPorterSent(Departure ship, Porter porter) async {
    // TODO: remove sent message from local cache（待实现：从本地缓存移除已发送的消息）
  }

  /// Porter发送消息失败回调
  @override
  Future<void> onPorterFailed(IOError error, Departure ship, Porter porter) async {
    logError('docker failed to send ship: $ship, $porter');
  }

  /// Porter发送消息出错回调
  @override
  Future<void> onPorterError(IOError error, Departure ship, Porter porter) async {
    logError('docker error while sending ship: $ship, $porter');
  }
}
