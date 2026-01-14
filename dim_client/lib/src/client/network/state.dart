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

import 'package:stargate/fsm.dart';     // 状态机核心库
import 'package:stargate/stargate.dart';// 网关核心库
import 'package:stargate/startrek.dart';// 星际迷航（网络层）
import 'package:dimsdk/dimsdk.dart';    // DIM核心协议库

import 'session.dart';                 // 客户端会话类
import 'transition.dart';              // 会话状态转换类

/// 会话状态机（核心：驱动会话状态流转）
/// 设计模式：状态机模式 + 弱引用（避免内存泄漏）
/// 核心职责：
/// 1. 管理所有会话状态（Default/Connecting/Running等）；
/// 2. 定义状态转换规则；
/// 3. 关联会话实例，实时获取连接状态；
class SessionStateMachine
    extends AutoMachine<SessionStateMachine, SessionStateTransition, SessionState>
    implements MachineContext {
  
  /// 构造方法
  /// [session] - 客户端会话实例（弱引用）
  SessionStateMachine(ClientSession session) : _sessionRef = WeakReference(session) {
    // 初始化状态构建器（创建所有会话状态）
    SessionStateBuilder builder = createStateBuilder();
    // 注册所有会话状态
    addState(builder.getDefaultState());      // 默认状态
    addState(builder.getConnectingState());   // 连接中
    addState(builder.getConnectedState());    // 已连接
    addState(builder.getHandshakingState());  // 握手中
    addState(builder.getRunningState());      // 运行中（就绪）
    addState(builder.getErrorState());        // 错误状态
  }

  /// 会话实例的弱引用（避免内存泄漏）
  final WeakReference<ClientSession> _sessionRef;

  /// 获取会话实例（从弱引用中提取）
  ClientSession? get session => _sessionRef.target;

  /// 获取会话密钥（快捷方法）
  String? get sessionKey => session?.sessionKey;

  /// 获取会话用户ID（快捷方法）
  ID? get sessionID => session?.identifier;
  
  /// 获取状态机上下文（自身）
  @override
  SessionStateMachine get context => this;

  /// 创建状态构建器（扩展点：可自定义状态）
  // protected
  SessionStateBuilder createStateBuilder() =>
      SessionStateBuilder(SessionStateTransitionBuilder());

  /// 获取当前网络连接状态（PorterStatus）
  PorterStatus get status {
    ClientSession? cs = session;
    if (cs == null) {
      // 会话已释放 → 错误状态
      return PorterStatus.error;
    }
    // 从网关获取对应远程地址的Porter
    CommonGate gate = cs.gate;
    Porter? docker = gate.getPorter(remote: cs.remoteAddress);
    if (docker == null) {
      // 无Porter → 错误状态
      return PorterStatus.error;
    }
    // 返回Porter当前状态
    return docker.status;
  }
}

/// 会话状态代理（回调接口）
/// 核心：会话状态变更时触发回调
abstract interface class SessionStateDelegate
    implements MachineDelegate<SessionStateMachine, SessionStateTransition, SessionState> {}

/// 会话状态枚举（定义所有状态类型）
enum SessionStateOrder {
  init,        // 初始状态（Default）
  connecting,  // 连接中
  connected,   // 已连接
  handshaking, // 握手中（登录中）
  running,     // 运行中（握手成功，可发送消息）
  error,       // 错误状态（连接失败/异常）
}

/// 会话状态类（封装单个状态的属性和行为）
/// 核心：
/// 1. 关联状态枚举（SessionStateOrder）；
/// 2. 定义状态进入/退出/暂停/恢复的行为；
/// 3. 重写相等性判断（按状态索引）；
class SessionState extends BaseState<SessionStateMachine, SessionStateTransition> {
  /// 构造方法
  /// [order] - 状态枚举
  SessionState(SessionStateOrder order) : super(order.index) {
    // 设置状态名称（与枚举名称一致）
    name = order.name;
  }

  /// 状态名称（如"connecting"、"running"）
  late final String name;
  /// 状态进入时间（用于判断状态是否过期）
  DateTime? _enterTime;

  /// 获取状态进入时间
  DateTime? get enterTime => _enterTime;

  /// 重写toString（返回状态名称）
  @override
  String toString() => name;

  /// 重写相等性判断（核心：按状态索引比较）
  @override
  bool operator ==(Object other) {
    if (other is ConnectionState) {
      if (identical(this, other)) {
        // 同一对象 → 相等
        return true;
      }
      return index == other.index;
    } else if (other is ConnectionStateOrder) {
      // 与连接状态枚举比较 → 按索引
      return index == other.index;
    } else {
      // 其他类型 → 不相等
      return false;
    }
  }

  /// 重写哈希值（使用状态索引）
  @override
  int get hashCode => index;

  /// 状态进入回调（记录进入时间）
  @override
  Future<void> onEnter(State<SessionStateMachine, SessionStateTransition>? previous,
      SessionStateMachine ctx, DateTime now) async {
    _enterTime = now;
  }

  /// 状态退出回调（清空进入时间）
  @override
  Future<void> onExit(State<SessionStateMachine, SessionStateTransition>? next,
      SessionStateMachine ctx, DateTime now) async {
    _enterTime = null;
  }

  /// 状态暂停回调（空实现，可扩展）
  @override
  Future<void> onPause(SessionStateMachine ctx, DateTime now) async {
  }

  /// 状态恢复回调（空实现，可扩展）
  @override
  Future<void> onResume(SessionStateMachine ctx, DateTime now) async {
  }
}

/// 会话状态构建器（工厂类）
/// 核心：创建所有会话状态，并为每个状态绑定转换规则
class SessionStateBuilder {
  /// 构造方法
  /// [stb] - 状态转换构建器（提供转换规则）
  SessionStateBuilder(this.stb);

  /// 状态转换构建器
  final SessionStateTransitionBuilder stb;

  /// 创建默认状态（Init）
  getDefaultState() {
    SessionState state = SessionState(SessionStateOrder.init);
    // 绑定转换规则：Default → Connecting
    state.addTransition(stb.getDefaultConnectingTransition());
    return state;
  }

  /// 创建连接中状态（Connecting）
  getConnectingState() {
    SessionState state = SessionState(SessionStateOrder.connecting);
    // 绑定转换规则：Connecting → Connected
    state.addTransition(stb.getConnectingConnectedTransition());
    // 绑定转换规则：Connecting → Error
    state.addTransition(stb.getConnectingErrorTransition());
    return state;
  }

  /// 创建已连接状态（Connected）
  getConnectedState() {
    SessionState state = SessionState(SessionStateOrder.connected);
    // 绑定转换规则：Connected → Handshaking
    state.addTransition(stb.getConnectedHandshakingTransition());
    // 绑定转换规则：Connected → Error
    state.addTransition(stb.getConnectedErrorTransition());
    return state;
  }

  /// 创建握手中状态（Handshaking）
  getHandshakingState() {
    SessionState state = SessionState(SessionStateOrder.handshaking);
    // 绑定转换规则：Handshaking → Running
    state.addTransition(stb.getHandshakingRunningTransition());
    // 绑定转换规则：Handshaking → Connected
    state.addTransition(stb.getHandshakingConnectedTransition());
    // 绑定转换规则：Handshaking → Error
    state.addTransition(stb.getHandshakingErrorTransition());
    return state;
  }

  /// 创建运行中状态（Running）
  getRunningState() {
    SessionState state = SessionState(SessionStateOrder.running);
    // 绑定转换规则：Running → Default
    state.addTransition(stb.getRunningDefaultTransition());
    // 绑定转换规则：Running → Error
    state.addTransition(stb.getRunningErrorTransition());
    return state;
  }

  /// 创建错误状态（Error）
  getErrorState() {
    SessionState state = SessionState(SessionStateOrder.error);
    // 绑定转换规则：Error → Default
    state.addTransition(stb.getErrorDefaultTransition());
    return state;
  }
}