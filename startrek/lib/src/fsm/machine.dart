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

/// 状态机上下文接口
/// ~~~~~~~~~~~~~~~~~~~~~
abstract interface class MachineContext {}

/// 状态转换接口
/// ~~~~~~~~~~~~~~~~
///
/// @param <C> - 上下文类型
abstract interface class StateTransition<C extends MachineContext> {
  /// 评估当前是否满足转换条件
  ///
  /// @param ctx     - 状态机上下文
  /// @param now     - 当前时间
  /// @return 满足条件返回true，否则返回false
  bool evaluate(C ctx, DateTime now);
}

/// 有限状态接口
/// ~~~~~~~~~~~~
///
/// @param <C> - 上下文类型
/// @param <T> - 状态转换类型
abstract interface class State<
  C extends MachineContext,
  T extends StateTransition<C>
> {
  /// 由状态机的tick()调用，评估当前状态的所有转换规则
  ///
  /// @param ctx     - 状态机上下文
  /// @param now     - 当前时间
  /// @return 满足条件的转换规则，无则返回null（保持当前状态）
  T? evaluate(C ctx, DateTime now);

  //-------- 状态事件回调

  /// 进入新状态后调用
  ///
  /// @param previous - 上一个状态
  /// @param ctx      - 状态机上下文
  /// @param now      - 当前时间
  Future<void> onEnter(State<C, T>? previous, C ctx, DateTime now);

  /// 退出旧状态前调用
  ///
  /// @param next    - 下一个状态
  /// @param ctx     - 状态机上下文
  /// @param now     - 当前时间
  Future<void> onExit(State<C, T>? next, C ctx, DateTime now);

  /// 暂停当前状态前调用
  ///
  /// @param ctx - 状态机上下文
  /// @param now - 当前时间
  Future<void> onPause(C ctx, DateTime now);

  /// 恢复当前状态后调用
  ///
  /// @param ctx - 状态机上下文
  /// @param now - 当前时间
  Future<void> onResume(C ctx, DateTime now);
}

/// 状态机代理接口（状态切换事件回调）
/// ~~~~~~~~~~~~~~~~~~~~~~
///
/// @param <S> - 状态类型
/// @param <C> - 上下文类型
/// @param <T> - 状态转换类型
abstract interface class MachineDelegate<
  C extends MachineContext,
  T extends StateTransition<C>,
  S extends State<C, T>
> {
  /// 进入新状态前调用（可通过上下文获取当前旧状态）
  ///
  /// @param next     - 新状态
  /// @param ctx      - 状态机上下文
  /// @param now      - 当前时间
  Future<void> enterState(S? next, C ctx, DateTime now);

  /// 退出旧状态后调用（可通过上下文获取当前新状态）
  ///
  /// @param previous - 旧状态
  /// @param ctx      - 状态机上下文
  /// @param now      - 当前时间
  Future<void> exitState(S? previous, C ctx, DateTime now);

  /// 暂停当前状态后调用
  ///
  /// @param current  - 当前状态
  /// @param ctx      - 状态机上下文
  /// @param now      - 当前时间
  Future<void> pauseState(S? current, C ctx, DateTime now);

  /// 恢复当前状态前调用
  ///
  /// @param current  - 当前状态
  /// @param ctx      - 状态机上下文
  /// @param now      - 当前时间
  Future<void> resumeState(S? current, C ctx, DateTime now);
}

/// 状态机核心接口（继承Ticker，支持节拍器驱动）
/// ~~~~~~~~~~~~~
///
/// @param <S> - 状态类型
/// @param <C> - 上下文类型
/// @param <T> - 状态转换类型
abstract interface class Machine<
  C extends MachineContext,
  T extends StateTransition<C>,
  S extends State<C, T>
>
    implements Ticker {
  /// 获取当前状态
  S? get currentState;

  /// 启动状态机（切换到默认状态）
  Future<bool> start();

  /// 停止状态机（将当前状态置为null）
  Future<bool> stop();

  /// 暂停状态机（当前状态不变）
  Future<bool> pause();

  /// 恢复状态机（保持当前状态）
  Future<bool> resume();
}
