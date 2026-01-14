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

/*
 *  有限状态说明：
 *  ~~~~~~~~~~~~~
 *
 *             //===============\\          (启动)          //=============\\
 *             ||               || ------------------------> ||             ||
 *             ||    默认状态    ||                           ||  准备状态   ||
 *             ||    Default    || <------------------------ ||  Preparing  ||
 *             \\===============//         (超时)           \\=============//
 *                                                               |       |
 *             //===============\\                               |       |
 *             ||               || <-----------------------------+       |
 *             ||    错误状态    ||          (错误)                 (已连接
 *             ||     Error     || <-----------------------------+   或绑定)
 *             \\===============//                               |       |
 *                 A       A                                     |       |
 *                 |       |            //===========\\          |       |
 *                 (错误) +----------- ||           ||          |       |
 *                 |                    ||  过期状态  || <--------+       |
 *                 |       +----------> ||  Expired  ||          |       |
 *                 |       |            \\===========//          |       |
 *                 |       (超时)           |         (超时)       |
 *                 |       |                   |                 |       V
 *             //===============\\     (已发送)  |             //=============\\
 *             ||               || <-----------+             ||             ||
 *             ||  维护状态     ||                           ||    就绪状态  ||
 *             ||  Maintaining  || ------------------------> ||    Ready    ||
 *             \\===============//       (已接收)          \\=============//
 *
 */

import 'package:startrek/fsm.dart';
import 'package:startrek/startrek.dart';

/// 连接状态机（继承fsm的BaseMachine，实现连接状态自动管理）
class ConnectionStateMachine
    extends BaseMachine<ConnectionStateMachine, ConnectionStateTransition, ConnectionState>
    implements MachineContext{
  ConnectionStateMachine(Connection connection) : _connectionRef = WeakReference(connection){
    // 初始化所有状态
    ConnectionStateBuilder builder = createStateBuilder();
    builder = createStateBuilder();
    addState(builder.getDefaultState());       // 默认状态
    addState(builder.getPreparingState());     // 准备状态
    addState(builder.getReadyState());         // 就绪状态
    addState(builder.getExpiredState());       // 过期状态
    addState(builder.getMaintainingState());   // 维护状态
    addState(builder.getErrorState());         // 错误状态
  }

  /// 弱引用关联的链接(避免内存泄漏)
  final WeakReference<Connection> _connectionRef;

  /// 获取关联的连接
  Connection? get connection => _connectionRef.target;

  /// 实现上下文: 状态机自身作为上下文
  @override
  ConnectionStateMachine get context => this;

  /// 创建状态构建起(可被子类重写扩展)
  ConnectionStateBuilder createStateBuilder() => ConnectionStateBuilder(ConnectionStateTransitionBuilder());
}

/// 连接状态代理（状态变更回调，继承fsm的MachineDelegate）
abstract interface class ConnectionStateDelegate implements MachineDelegate<ConnectionStateMachine,ConnectionStateTransition,ConnectionState>{}

/// 链接状态枚举(定义6种核心状态)
enum ConnectionStateOrder{
  init,         // 默认状态（未启动/超时）
  preparing,    // 准备状态（正在连接/绑定）
  ready,        // 就绪状态（近期有响应）
  maintaining,  // 维护状态（已发送心跳，等待响应）
  expired,      // 过期状态（长时间无响应，需维护）
  error,        // 错误状态（连接丢失）
}

/// 连接状态（继承fsm的BaseState，封装状态基础行为）
class ConnectionState extends BaseState<ConnectionStateMachine, ConnectionStateTransition>{
  ConnectionState(ConnectionStateOrder order) : super(order.index) {
    name = order.name;
  }

  /// 状态名称（便于日志/调试）
  late final String name;
  /// 进入该状态的时间（用于超时判断）
  DateTime? _enterTime;

  /// 获取进入状态的时间
  DateTime? get enterTime => _enterTime;

  /// 重写toString，返回状态名称
  @override
  String toString() => name;

  /// 重写相等判断：按状态索引判断
  @override
  bool operator ==(Object other) {
    if (other is ConnectionState) {
      if (identical(this, other)) {
        // 同一对象
        return true;
      }
      return index == other.index;
    } else if (other is ConnectionStateOrder) {
      return index == other.index;
    } else {
      return false;
    }
  }

  /// 重写哈希值：使用状态索引
  @override
  int get hashCode => index;

  /// 进入状态时记录时间
  @override
  Future<void> onEnter(State<ConnectionStateMachine, ConnectionStateTransition>? previous,
      ConnectionStateMachine ctx, DateTime now) async {
    _enterTime = now;
  }

  /// 退出状态时清空时间
  @override
  Future<void> onExit(State<ConnectionStateMachine, ConnectionStateTransition>? next,
      ConnectionStateMachine ctx, DateTime now) async {
    _enterTime = null;
  }

  /// 暂停状态（空实现，可子类扩展）
  @override
  Future<void> onPause(ConnectionStateMachine ctx, DateTime now) async {}

  /// 恢复状态（空实现，可子类扩展）
  @override
  Future<void> onResume(ConnectionStateMachine ctx, DateTime now) async {}

}

/// 状态构建器
class ConnectionStateBuilder{
  ConnectionStateBuilder(this.stb);

  /// 转换规则构建器
  final ConnectionStateTransitionBuilder stb;

  /// 创建默认状态(Default): 添加“Default ->Preparing” 转换规则
  getDefaultState(){
    ConnectionState state = ConnectionState(ConnectionStateOrder.init);
    state.addTransition(stb.getDefaultPreparingTransition());
    return state;
  }

  /// 创建准备状态（Preparing）：添加“Preparing→Ready”和“Preparing→Default”转换规则
  getPreparingState() {
    ConnectionState state = ConnectionState(ConnectionStateOrder.preparing);
    state.addTransition(stb.getPreparingReadyTransition());
    state.addTransition(stb.getPreparingDefaultTransition());
    return state;
  }

  /// 创建就绪状态（Ready）：添加“Ready→Expired”和“Ready→Error”转换规则
  getReadyState() {
    ConnectionState state = ConnectionState(ConnectionStateOrder.ready);
    state.addTransition(stb.getReadyExpiredTransition());
    state.addTransition(stb.getReadyErrorTransition());
    return state;
  }

  /// 创建过期状态（Expired）：添加“Expired→Maintaining”和“Expired→Error”转换规则
  getExpiredState() {
    ConnectionState state = ConnectionState(ConnectionStateOrder.expired);
    state.addTransition(stb.getExpiredMaintainingTransition());
    state.addTransition(stb.getExpiredErrorTransition());
    return state;
  }

  /// 创建维护状态（Maintaining）：添加“Maintaining→Ready”“Maintaining→Expired”“Maintaining→Error”转换规则
  getMaintainingState() {
    ConnectionState state = ConnectionState(ConnectionStateOrder.maintaining);
    state.addTransition(stb.getMaintainingReadyTransition());
    state.addTransition(stb.getMaintainingExpiredTransition());
    state.addTransition(stb.getMaintainingErrorTransition());
    return state;
  }

  /// 创建错误状态（Error）：添加“Error→Default”转换规则
  getErrorState() {
    ConnectionState state = ConnectionState(ConnectionStateOrder.error);
    state.addTransition(stb.getErrorDefaultTransition());
    return state;
  }

}