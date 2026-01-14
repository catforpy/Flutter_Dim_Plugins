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

/// 基础状态转换（包含目标状态的索引）
/// C: 状态机上下文类型
abstract class BaseTransition<C extends MachineContext>
    implements StateTransition<C> {
  BaseTransition(this.target);

  final int target; // 目标状态的索引
}

/// 基础状态（包含状态转换列表）
/// C: 状态机上下文类型，T: 状态转换类型
abstract class BaseState<C extends MachineContext, T extends StateTransition<C>>
    implements State<C, T> {
  BaseState(this.index);

  final int index; // 当前状态的索引
  final List<T> _transitions = []; // 当前状态下的所有转换规则

  /// 添加状态转换规则
  void addTransition(T trans) {
    assert(!_transitions.contains(trans), '转换规则已存在:$trans');
    _transitions.add(trans);
  }

  @override
  T? evaluate(C ctx, DateTime now) {
    for (var trans in _transitions) {
      if (trans.evaluate(ctx, now)) {
        // 满足条件，返回该转换规则(用于切换到目标状态)
        return trans;
      }
    }
    // 无满足条件的转换规则，保持当前状态
    return null;
  }
}

/// 状态机状态枚举
/// ~~~~~~~~~~~~~~
enum _Status {
  stopped, // 已停止
  running, // 运行中
  paused, // 已暂停
}

/// 基础状态机（实现状态管理、状态切换核心逻辑）
/// C: 状态机上下文类型，T: 状态转换类型，S: 状态类型
abstract class BaseMachine<
  C extends MachineContext,
  T extends BaseTransition<C>,
  S extends BaseState<C, T>
>
    implements Machine<C, T, S> {
  final List<S?> _states = []; // 所有状态列表(按索引存储)
  int _current = -1; // 当前状态的索引（-1表示无当前状态）

  _Status _status = _Status.stopped; // 状态机自身的运行状态

  // 弱引用状态机代理(避免内存泄漏)
  WeakReference<MachineDelegate<C, T, S>>? _delegateRef;

  // 获取/设置状态机代理
  MachineDelegate<C, T, S>? get delegate => _delegateRef?.target;
  set delegate(MachineDelegate<C, T, S>? delegate) {
    _delegateRef = delegate == null ? null : WeakReference(delegate);
  }

  // 受保护方法： 获取状态机上下文(由子类实现)
  C get context; // 状态机自身作为上下文

  //
  //  状态管理
  //
  /// 添加状态到状态机（按索引存储，索引不足时填充null）
  S? addState(S newState) {
    int index = newState.index;
    assert(index >= 0, '状态索引错误: $index');
    if (index < _states.length) {
      // 索引已存在
      S? oldState = _states[index];
      _states[index] = newState;
      return oldState;
    }
    // 索引超出当前列表长度
    int spaces = index - _states.length;
    for (int i = 0; i < spaces; ++i) {
      _states.add(null);
    }
    // 将新状态添加到列表末尾
    _states.add(newState);
    return null;
  }

  /// 根据索引获取状态
  S? getState(int index) => _states[index];

  // 受保护方法：获取默认状态（索引0的状态）
  S? get defaultState => _states[0];

  // 受保护方法：根据转换规则获取目标状态
  S? getTargetState(T trans) => _states[trans.target]; // 从转换规则中获取目标索引，在获取对应状态
  /// 获取当前状态
  @override
  S? get currentState => _current < 0 ? null : _states[_current];

  // 私有方法：设置当前状态（仅通过索引修改）
  set currentState(S? newState) => _current = newState?.index ?? -1;

  /// 退出当前状态并进入新状态（核心状态切换逻辑）
  ///
  /// @param newState - 新状态
  /// @param now      - 当前时间
  Future<bool> _changeState(S? newState, DateTime now) async {
    S? oldState = currentState;
    if (oldState == null) {
      if (newState == null) {
        // 新旧状态均为null,无需切换
        return false;
      }
    } else if (oldState == newState) {
      // 新旧状态相同,无需切换
      return false;
    }

    C ctx = context;
    MachineDelegate<C, T, S>? callback = this.delegate;

    //
    //  状态切换前的事件
    //
    if (callback != null) {
      // 准备切换到新状态(代理可通过上下文获取旧状态)
      await callback.enterState(newState, ctx, now);
    }
    if (oldState != null) {
      // 旧状态退出当前回调
      await oldState.onExit(newState, ctx, now);
    }

    //
    //  执行状态切换
    //
    currentState = newState;

    //
    // 状态切换后的事件
    //
    if (newState != null) {
      // 新状态进入后的回调
      await newState.onEnter(oldState, ctx, now);
    }
    if (callback != null) {
      // 状态切换完成后的回调(代理可通过上下文获取新状态)
      await callback.exitState(oldState, ctx, now);
    }

    return true;
  }

  //
  // 状态机操作(启动/停止/暂停/恢复)
  //

  @override
  Future<bool> start() async {
    /// 从默认状态启动状态机
    if (_status != _Status.stopped) {
      // 非停止状态(运行中/暂停)，无法重新启动
      return false;
    }
    DateTime now = DateTime.now();
    // 切换到默认状态(索引0)
    bool ok = await _changeState(defaultState, now);
    assert(ok, '切换到默认状态失败');
    _status = _Status.running;
    return ok;
  }

  @override
  Future<bool> stop() async {
    /// 停止状态机并将当前状态置为null
    if (_status == _Status.stopped) {
      // 已停止，无法重复停止
      return false;
    }
    _status = _Status.stopped;
    DateTime now = DateTime.now();
    // 强制切换到null状态
    return await _changeState(null, now);
  }

  @override
  Future<bool> pause() async {
    // 暂停状态机(当前状态不变)
    if (_status != _Status.running) {
      // 非运行状态(暂停/停止)，无法暂停
      return false;
    }
    DateTime now = DateTime.now();
    C ctx = context;
    S? current = currentState;
    //
    // 暂停前的事件
    //
    await current?.onPause(ctx, now);
    //
    // 标记状态为暂停
    //
    _status = _Status.paused;
    //
    // 暂停后的事件
    //
    await delegate?.pauseState(current, ctx, now);
    return true;
  }

  @override
  Future<bool> resume() async {
    /// 恢复状态机（保持当前状态）
    if (_status != _Status.paused) {
      // 非暂停状态（运行中/停止），无法恢复
      return false;
    }
    DateTime now = DateTime.now();
    C ctx = context;
    S? current = currentState;
    //
    //  恢复前的事件
    //
    await delegate?.resumeState(current, ctx, now);
    //
    //  标记状态机为运行中
    //
    _status = _Status.running;
    //
    //  恢复后的事件
    //
    await current?.onResume(ctx, now);
    return true;
  }

  //
  //  节拍器触发的tick方法（状态检查核心）
  //
  @override
  Future<void> tick(DateTime now, Duration elapsed) async {
    // 驱动状态机向前运行
    if (_status != _Status.running) {
      // 非运行状态（暂停/停止），不检查状态转换
      return;
    }
    S? state = currentState;
    if (state != null) {
      C ctx = context;
      // 检查当前状态的所有转换规则，获取满足条件的转换
      T? trans = state.evaluate(ctx, now);
      if (trans != null) {
        // 获取转换目标状态
        state = getTargetState(trans);
        assert(state != null, '转换目标状态错误: $trans');
        // 执行状态切换
        await _changeState(state, now);
      }
    }
  }
}
