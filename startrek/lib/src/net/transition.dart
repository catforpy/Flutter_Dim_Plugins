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

import 'package:startrek/fsm.dart';
import 'package:startrek/startrek.dart';

/// 连接状态转换规则（继承fsm的BaseTransition，封装转换条件）
class ConnectionStateTransition extends BaseTransition<ConnectionStateMachine> {
  ConnectionStateTransition(ConnectionStateOrder order, this.eval)
    : super(order.index);

  /// 转换条件判断函数
  final ConnectionStateEvaluate eval;

  /// 实现评估方法：调用自定义的eval函数
  @override
  bool evaluate(ConnectionStateMachine ctx, DateTime now) => eval(ctx, now);
}

/// 转换条件判断函数类型
typedef ConnectionStateEvaluate =
    bool Function(ConnectionStateMachine ctx, DateTime now);

/// 转换规则构建器（创建所有状态转换规则）
class ConnectionStateTransitionBuilder {
  /// Default -> Preparing: 链接已启动(未关闭)
  getDefaultPreparingTransition() =>
      ConnectionStateTransition(ConnectionStateOrder.preparing, (ctx, now) {
        Connection? conn = ctx.connection;
        // 链接已启动(未关闭)，切换到准备状态
        return !(conn == null || conn.isClosed);
      });

  /// Preparing → Ready：连接已存活（已连接/绑定）
  getPreparingReadyTransition() =>
      ConnectionStateTransition(ConnectionStateOrder.ready, (ctx, now) {
        Connection? conn = ctx.connection;
        // 连接已存活（已连接或已绑定），切换到就绪状态
        return conn != null && conn.isAlive;
      });

  /// Preparing → Default：连接已停止（关闭）
  getPreparingDefaultTransition() =>
      ConnectionStateTransition(ConnectionStateOrder.init, (ctx, now) {
        Connection? conn = ctx.connection;
        // 连接已停止（关闭），切换回默认状态
        return conn == null || conn.isClosed;
      });

  /// Ready → Expired：连接存活但长时间未接收数据
  getReadyExpiredTransition() =>
      ConnectionStateTransition(ConnectionStateOrder.expired, (ctx, now) {
        Connection? conn = ctx.connection;
        if (conn == null || !conn.isAlive) {
          return false;
        }
        TimedConnection timed = conn as TimedConnection;
        // 连接存活，但长时间未接收数据，切换到过期状态
        return !timed.isReceivedRecently(now);
      });

  /// Ready → Error：连接丢失（未存活）
  getReadyErrorTransition() =>
      ConnectionStateTransition(ConnectionStateOrder.error, (ctx, now) {
        Connection? conn = ctx.connection;
        // 连接丢失（未存活），切换到错误状态
        return conn == null || !conn.isAlive;
      });

  /// Expired → Maintaining：连接存活且近期发送过数据（已发心跳）
  getExpiredMaintainingTransition() =>
      ConnectionStateTransition(ConnectionStateOrder.maintaining, (ctx, now) {
        Connection? conn = ctx.connection;
        if (conn == null || !conn.isAlive) {
          return false;
        }
        TimedConnection timed = conn as TimedConnection;
        // 连接存活且近期发送过数据（已发心跳），切换到维护状态
        return timed.isSentRecently(now);
      });

  /// Expired → Error：连接丢失或超长时间未接收数据
  getExpiredErrorTransition() =>
      ConnectionStateTransition(ConnectionStateOrder.error, (ctx, now) {
        Connection? conn = ctx.connection;
        if (conn == null || !conn.isAlive) {
          return true;
        }
        TimedConnection timed = conn as TimedConnection;
        // 连接丢失，或超长时间未接收数据，切换到错误状态
        return timed.isNotReceivedLongTimeAgo(now);
      });

  /// Maintaining → Ready：连接存活且近期接收数据（心跳响应）
  getMaintainingReadyTransition() =>
      ConnectionStateTransition(ConnectionStateOrder.ready, (ctx, now) {
        Connection? conn = ctx.connection;
        if (conn == null || !conn.isAlive) {
          return false;
        }
        TimedConnection timed = conn as TimedConnection;
        // 连接存活且近期接收数据（收到心跳响应），切换回就绪状态
        return timed.isReceivedRecently(now);
      });

  /// Maintaining → Expired：连接存活但长时间未发送数据
  getMaintainingExpiredTransition() =>
      ConnectionStateTransition(ConnectionStateOrder.expired, (ctx, now) {
        Connection? conn = ctx.connection;
        if (conn == null || !conn.isAlive) {
          return false;
        }
        TimedConnection timed = conn as TimedConnection;
        // 连接存活但长时间未发送数据，切换回过期状态
        return !timed.isSentRecently(now);
      });

  /// Maintaining → Error：连接丢失或超长时间未接收数据
  getMaintainingErrorTransition() =>
      ConnectionStateTransition(ConnectionStateOrder.error, (ctx, now) {
        Connection? conn = ctx.connection;
        if (conn == null || !conn.isAlive) {
          return true;
        }
        TimedConnection timed = conn as TimedConnection;
        // 连接丢失，或超长时间未接收数据，切换到错误状态
        return timed.isNotReceivedLongTimeAgo(now);
      });

  /// Error → Default：连接存活且在错误状态期间接收过数据
  getErrorDefaultTransition() =>
      ConnectionStateTransition(ConnectionStateOrder.init, (ctx, now) {
        Connection? conn = ctx.connection;
        if (conn == null || !conn.isAlive) {
          return false;
        }
        TimedConnection timed = conn as TimedConnection;
        // 连接存活，且在错误状态期间接收过数据，切换回默认状态
        ConnectionState? current = ctx.currentState;
        DateTime? enter = current?.enterTime;
        DateTime? last = timed.lastReceivedTime;
        if (enter == null) {
          assert(false, '不应出现此情况');
          return true;
        }
        return last != null && enter.isBefore(last);
      });
}
