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

import 'dart:io';
import 'dart:typed_data';

import 'package:startrek/nio.dart';
import 'package:startrek/pair.dart';
import 'package:startrek/startrek.dart';

/// 基础连接类
/// 核心实现：封装“通道 + 状态机”的连接逻辑，是 Porter 与 Channel 之间的桥梁
/// 实现 TimedConnection：记录收发时间，支持保活/过期判断；
/// 实现 ConnectionStateDelegate：监听状态机事件
class BaseConnection extends AddressPairObject
    implements Connection, TimedConnection, ConnectionStateDelegate {
  BaseConnection({super.remote, super.local});

  /// 链接代理的弱引用(回调上层事件：收/发/失败/状态变化)
  WeakReference<ConnectionDelegate>? _delegateRef;

  /// 通道的弱引用(关联底层Channel)
  WeakReference<Channel>? _channelRef;

  /// 最后发送时间（用于保活/过期判断）
  DateTime? _lastSentTime;

  /// 最后接收时间（用于保活/过期判断）
  DateTime? _lastReceivedTime;

  /// 连接状态机（管理连接的状态流转：准备中→就绪→过期→错误）
  ConnectionStateMachine? _fsm;

  // ====================== 代理管理 ======================
  /// 获取连接代理（上层回调）
  ConnectionDelegate? get delegate => _delegateRef?.target;

  /// 设置连接代理
  set delegate(ConnectionDelegate? gate) =>
      _delegateRef = gate == null ? null : WeakReference(gate);

  // ====================== 状态机管理 ======================
  /// 获取状态机（子类可访问）
  ConnectionStateMachine? get stateMachine => _fsm;

  /// 设置状态机(核心: 替换/停止旧状态机)
  Future<void> setStateMachine(ConnectionStateMachine? fsm) async {
    // 1.替换新状态机
    ConnectionStateMachine? old = _fsm;
    _fsm = fsm;
    // 2.停止旧状态机
    if (old == null || identical(old, fsm)) {
    } else {
      await old.stop();
    }
  }

  /// 创建状态机（子类可重写，定制状态流转逻辑）
  ConnectionStateMachine createStateMachine() {
    ConnectionStateMachine machine = ConnectionStateMachine(this);
    machine.delegate = this;
    return machine;
  }

  // ====================== 通道管理 ======================
  /// 获取关联的通道
  Channel? get channel => _channelRef?.target;

  /// 设置关联的通道（核心：替换/关闭旧通道）
  Future<void> setChannel(Channel? sock) async {
    // 1.替换新通道
    Channel? old = _channelRef?.target;

    if (sock != null) {
      _channelRef = WeakReference(sock);
    }

    // 2. 关闭九通道
    if (old == null || identical(old, sock)) {
    } else {
      try {
        await old.close();
      } catch (e) {
        //关闭异常不抛错，避免阻塞流程
      }
    }
  }

  // ====================== 状态判断（透传通道状态） ======================
  /// 判断连接是否关闭
  @override
  bool get isClosed {
    if (_channelRef == null) {
      // 初始化中，视为未关闭
      return false;
    }
    return channel?.isClosed != false;
  }

  /// 判断连接是否绑定（UDP 专用）
  @override
  bool get isBound => channel?.isBound == true;

  /// 判断连接是否连接（TCP 专用）
  @override
  bool get isConnected => channel?.isConnected == true;

  /// 判断连接是否存活（未关闭 + 已连接/已绑定）
  @override
  bool get isAlive => (!isClosed) && (isConnected || isBound);

  /// 判断连接是否可读
  @override
  bool get isAvailable => channel?.isAvailable == true;

  /// 判断连接是否可写
  @override
  bool get isVacant => channel?.isVacant == true;

  /// 重写 toString：便于调试（显示地址、通道）
  @override
  String toString() {
    String clazz = className;
    return '<$clazz remote="$remoteAddress" local="$localAddress">\n\t'
        '$channel\n</$clazz>';
  }

  /// 关闭连接（核心：停止状态机 + 关闭通道）
  @override
  Future<void> close() async {
    // 1. 停止状态机
    await setStateMachine(null);
    // 2. 关闭通道
    await setChannel(null);
  }

  // ====================== 连接启动 ======================
  /// 启动连接（从 Hub 获取通道 + 启动状态机）
  /// @param hub - 枢纽（提供通道创建能力）
  Future<void> start(Hub hub) async {
    // 1.从HUB获取通道
    await openChannel(hub);
    // 2.启动状态机
    await startMachine();
  }

  /// 启动状态机
  Future<void> startMachine() async {
    ConnectionStateMachine machine = createStateMachine();
    await setStateMachine(machine);
    await machine.start();
  }

  /// 从 Hub 打开通道（子类可重写，定制通道创建逻辑）
  Future<Channel?> openChannel(Hub hub) async {
    Channel? sock = await hub.open(remote: remoteAddress, local: localAddress);
    if (sock == null) {
      assert(
        false,
        'failed to open channel: remote=$remoteAddress, local=$localAddress',
      );
    } else {
      await setChannel(sock);
    }
    return sock;
  }

  // ====================== 数据收发 ======================
  /// 处理接收到的数据（核心：更新接收时间 + 回调上层）
  @override
  Future<void> onReceivedData(Uint8List data) async {
    _lastReceivedTime = DateTime.now(); // 更新最后接收时间
    await delegate?.onConnectionReceived(data, this);
  }

  /// 实际发送数据（子类可重写，定制发送逻辑）
  /// @param src - 待发送数据
  /// @param destination - 目标地址
  /// @return 发送字节数（-1 表示失败）
  Future<int> doSend(Uint8List src, SocketAddress? destination) async {
    Channel? sock = channel;
    if (sock == null || !sock.isAlive) {
      assert(false, 'socket channel lost: $sock');
      return -1;
    } else if (destination == null) {
      assert(false, 'remote address should not empty');
      return -1;
    }
    int sent = await sock.send(src, destination);
    if (sent > 0) {
      // 更新最后发送时间
      _lastSentTime = DateTime.now();
    }
    return sent;
  }

  /// 发送数据(对外接口:异常处理 + 回调上层)
  @override
  Future<int> sendData(Uint8List data) async {
    IOError? error;
    int sent = -1;
    try {
      sent = await doSend(data, remoteAddress);
      if (sent < 0) {
        throw SocketException(
          'failed to send data: ${data.length} byte(s) to $remoteAddress',
        );
      }
    } on IOException catch (ex) {
      // 捕获发送异常，记录错误并关闭通道
      error = IOError(ex);
      await setChannel(null);
    }

    // 回调上层 : 成功/失败
    if (error == null) {
      await delegate?.onConnectionSent(sent, data, this);
    } else {
      await delegate?.onConnectionFailed(error, data, this);
    }
    return sent;
  }

  // ====================== 状态机驱动 ======================
  /// 获取当前连接状态
  @override
  ConnectionState? get state => stateMachine?.currentState;

  /// 驱动连接状态机(由HUB定时调用)
  @override
  Future<void> tick(DateTime now, Duration elapsed) async {
    if (_channelRef == null) {
      // 未初始化，跳过
      return;
    }
    // 驱动状态机流转
    await stateMachine?.tick(now, elapsed);
  }

  // ====================== 保活/过期判断 ======================
  /// 获取最后发送时间
  @override
  DateTime? get lastSentTime => _lastSentTime;

  /// 获取最后接收时间
  @override
  DateTime? get lastReceivedTime => _lastReceivedTime;

  /// 判断是否最近发送过数据（用于保活）
  @override
  bool isSentRecently(DateTime now) {
    DateTime? lastTime = _lastSentTime;
    if (lastTime == null) {
      return false;
    }
    return lastTime.add(TimedConnection.EXPIRES).isAfter(now);
  }

  /// 判断是否最近接收过数据（用于保活）
  @override
  bool isReceivedRecently(DateTime now) {
    DateTime? lastTime = _lastReceivedTime;
    if (lastTime == null) {
      return false;
    }
    return lastTime.add(TimedConnection.EXPIRES).isAfter(now);
  }

  /// 判断是否长时间未接收数据（用于触发重连/关闭）
  @override
  bool isNotReceivedLongTimeAgo(DateTime now) {
    DateTime? lastTime = _lastReceivedTime;
    if (lastTime == null) {
      return false;
    }
    return lastTime.add(TimedConnection.EXPIRES * 8).isBefore(now);
  }

  // ====================== 状态机事件回调 ======================
  /// 进入新状态（子类可重写）
  @override
  Future<void> enterState(
    ConnectionState? next,
    ConnectionStateMachine ctx,
    DateTime now,
  ) async {}

  /// 退出旧状态（核心：状态变化回调 + 错误状态关闭通道）
  @override
  Future<void> exitState(
    ConnectionState? previous,
    ConnectionStateMachine ctx,
    DateTime now,
  ) async {
    ConnectionState? current = ctx.currentState;
    int index = current?.index ?? -1;
    // 状态从“住哪杯中“变为”就绪“：更新收发时间，避免立即过期
    if (index == ConnectionStateOrder.ready.index) {
      if (previous?.index == ConnectionStateOrder.preparing.index) {
        DateTime soon = now.subtract(TimedConnection.EXPIRES ~/ 2);
        DateTime? st = _lastSentTime;
        if (st == null || st.isBefore(soon)) {
          _lastSentTime = soon;
        }
        DateTime? rt = _lastReceivedTime;
        if (rt == null || rt.isBefore(soon)) {
          _lastReceivedTime = soon;
        }
      }
    }

    // 回调上层：状态变化
    await delegate?.onConnectionStateChanged(previous, current, this);
    // 状态变为“错误”：关闭通道
    if (index == ConnectionStateOrder.error.index) {
      await setChannel(null);
    }
  }

  /// 暂停当前状态（子类可重写）
  @override
  Future<void> pauseState(
    ConnectionState? current,
    ConnectionStateMachine ctx,
    DateTime now,
  ) async {}

  /// 恢复当前状态（子类可重写）
  @override
  Future<void> resumeState(
    ConnectionState? current,
    ConnectionStateMachine ctx,
    DateTime now,
  ) async {}
}
