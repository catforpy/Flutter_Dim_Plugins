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
import 'package:stargate/startrek.dart';// 星际迷航（网络层）

import 'session.dart';                 // 客户端会话类
import 'state.dart';                   // 会话状态类

/// 会话状态转换类（核心：定义状态转换的判断逻辑）
/// 设计思路：每个转换规则对应一个判断函数（Evaluate），
///          满足条件时触发状态转换
class SessionStateTransition extends BaseTransition<SessionStateMachine> {
  /// 构造方法
  /// [order] - 目标状态枚举
  /// [eval] - 转换判断函数（满足条件返回true）
  SessionStateTransition(SessionStateOrder order, this.eval) : super(order.index);

  /// 转换判断函数（核心：决定是否触发转换）
  final SessionStateEvaluate eval;

  /// 执行转换判断（重写父类方法）
  @override
  bool evaluate(SessionStateMachine ctx, DateTime now) => eval(ctx, now);
}

/// 检查状态是否过期（超过30秒）
/// 核心：用于判断握手/连接是否超时
bool _isStateExpired(SessionState? state, DateTime now) {
  DateTime? enterTime = state?.enterTime;
  if(enterTime == null){
    // 无进入时间 → 未过期
    return false;
  }
  // 计算30秒前的时间
  DateTime recent = DateTime.now().subtract(Duration(seconds: 30));
  // 进入时间早于30秒前 → 过期
  return enterTime.isBefore(recent);
}

/// 状态转换判断函数类型
/// 参数：状态机上下文、当前时间
/// 返回值：是否满足转换条件
typedef SessionStateEvaluate = bool Function(SessionStateMachine ctx, DateTime now);

/// 会话状态转换构建器（工厂类）
/// 核心：创建所有状态转换规则，定义每个转换的触发条件
class SessionStateTransitionBuilder {
  /// 转换规则：Default → Connecting
  /// 触发条件：
  /// 1. 已设置用户ID（登录）；
  /// 2. 连接状态为preparing/ready（正在连接/已连接）；
  getDefaultConnectingTransition() => SessionStateTransition(
    SessionStateOrder.connecting, (ctx, now) {
      // 检查用户ID是否设置
      if (ctx.sessionID == null) {
        // 未登录 → 不转换
        return false;
      }
      // 检查连接状态
      PorterStatus status = ctx.status;
      return status == PorterStatus.preparing || status == PorterStatus.ready;
    },
  );

  /// 转换规则：Connecting → Connected
  /// 触发条件：连接状态为ready（已连接）
  getConnectingConnectedTransition() => SessionStateTransition(
    SessionStateOrder.connected, (ctx, now) {
      PorterStatus status = ctx.status;
      return status == PorterStatus.ready;
    },
  );

  /// 转换规则：Connecting → Error
  /// 触发条件：
  /// 1. 连接状态过期（超过30秒）；
  /// 2. 连接状态非preparing/ready（连接失败）；
  getConnectingErrorTransition() => SessionStateTransition(
    SessionStateOrder.error, (ctx, now) {
      if (_isStateExpired(ctx.currentState, now)) {
        // 连接超时 → 转换为错误
        return true;
      }
      PorterStatus status = ctx.status;
      return !(status == PorterStatus.preparing || status == PorterStatus.ready);
    },
  );

  /// 转换规则：Connected → Handshaking
  /// 触发条件：
  /// 1. 已设置用户ID；
  /// 2. 连接状态为ready（已连接）；
  /// 核心：连接成功后立即触发握手（登录）
  getConnectedHandshakingTransition() => SessionStateTransition(
    SessionStateOrder.handshaking, (ctx, now) {
      if (ctx.sessionID == null) {
        // 未登录 → 不转换（后续会转Error）
        return false;
      }
      PorterStatus status = ctx.status;
      return status == PorterStatus.ready;
    },
  );

  /// 转换规则：Connected → Error
  /// 触发条件：
  /// 1. 未设置用户ID；
  /// 2. 连接状态非ready（连接断开）；
  getConnectedErrorTransition() => SessionStateTransition(
    SessionStateOrder.error, (ctx, now) {
      if (ctx.sessionID == null) {
        // 未登录 → 转换为错误
        return true;
      }
      PorterStatus status = ctx.status;
      return status != PorterStatus.ready;
    },
  );

  /// 转换规则：Handshaking → Running
  /// 触发条件：
  /// 1. 已设置用户ID；
  /// 2. 连接状态为ready；
  /// 3. 会话密钥已设置（握手成功）；
  /// 核心：握手成功后进入运行状态（可发送消息）
  getHandshakingRunningTransition() => SessionStateTransition(
    SessionStateOrder.running, (ctx, now) {
      if (ctx.sessionID == null) {
        // 未登录 → 不转换
        return false;
      }
      PorterStatus status = ctx.status;
      if (status != PorterStatus.ready) {
        // 连接断开 → 不转换（后续转Error）
        return false;
      }
      // 会话密钥存在 → 握手成功
      return ctx.sessionKey != null;
    },
  );

  /// 转换规则：Handshaking → Connected
  /// 触发条件：
  /// 1. 已设置用户ID；
  /// 2. 连接状态为ready；
  /// 3. 会话密钥为空；
  /// 4. 握手状态过期（超过30秒）；
  /// 核心：握手超时 → 回到已连接状态，重新握手
  getHandshakingConnectedTransition() => SessionStateTransition(
    SessionStateOrder.connected, (ctx, now) {
      if (ctx.sessionID == null) {
        // 未登录 → 不转换
        return false;
      }
      PorterStatus status = ctx.status;
      if (status != PorterStatus.ready) {
        // 连接断开 → 不转换
        return false;
      }
      if (ctx.sessionKey != null) {
        // 握手成功 → 转Running
        return false;
      }
      // 握手超时 → 回到Connected
      return _isStateExpired(ctx.currentState, now);
    },
  );

  /// 转换规则：Handshaking → Error
  /// 触发条件：
  /// 1. 未设置用户ID；
  /// 2. 连接状态非ready（连接断开）；
  getHandshakingErrorTransition() => SessionStateTransition(
    SessionStateOrder.error, (ctx, now) {
      if (ctx.sessionID == null) {
        // 未登录 → 转换为错误
        return true;
      }
      PorterStatus status = ctx.status;
      return status != PorterStatus.ready;
    },
  );

  /// 转换规则：Running → Default
  /// 触发条件：
  /// 1. 连接状态为ready；
  /// 2. 会话未就绪（用户ID/密钥丢失）；
  /// 核心：登出/密钥丢失 → 回到初始状态
  getRunningDefaultTransition() => SessionStateTransition(
    SessionStateOrder.init, (ctx, now) {
      PorterStatus status = ctx.status;
      if (status != PorterStatus.ready) {
        // 连接断开 → 转Error
        return false;
      }
      ClientSession? session = ctx.session;
      return session?.isReady != true;
    },
  );

  /// 转换规则：Running → Error
  /// 触发条件：连接状态非ready（连接断开）
  getRunningErrorTransition() => SessionStateTransition(
    SessionStateOrder.error, (ctx, now) {
      PorterStatus status = ctx.status;
      return status != PorterStatus.ready;
    },
  );

  /// 转换规则：Error → Default
  /// 触发条件：连接状态非error（连接恢复）
  /// 核心：错误状态恢复 → 回到初始状态，重新连接
  getErrorDefaultTransition() => SessionStateTransition(
    SessionStateOrder.init, (ctx, now) {
      PorterStatus status = ctx.status;
      return status != PorterStatus.error;
    },
  );
}