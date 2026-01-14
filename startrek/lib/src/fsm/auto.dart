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

/// 自动状态机（继承基础状态机，集成节拍器实现自动运行）
/// C: 状态机上下文类型，T: 状态转换类型，S: 状态类型
abstract class AutoMachine<
  C extends MachineContext,
  T extends BaseTransition<C>,
  S extends BaseState<C, T>
>
    extends BaseMachine<C, T, S> {
  @override
  Future<bool> start() async {
    // 调用父类start 方法启动状态机
    bool ok = await super.start();
    // 获取全局节拍器实例，将当前状态机添加为Ticker(触发自动tick)
    PrimeMetronome timer = PrimeMetronome();
    timer.addTicker(this);
    return ok;
  }

  @override
  Future<bool> stop() async {
    // 从节拍器中移除当前状态机，停止自动tick
    PrimeMetronome timer = PrimeMetronome();
    timer.removeTicker(this);
    // 调用父类stop方法停止状态机
    return await super.stop();
  }

  @override
  Future<bool> pause() async {
    // 暂停时移除节拍器绑定，停止自动tick
    PrimeMetronome timer = PrimeMetronome();
    timer.removeTicker(this);
    // 调用父类pause方法暂停状态机
    return await super.pause();
  }

  @override
  Future<bool> resume() async {
    // 调用父类resume方法恢复状态机
    bool ok = await super.resume();
    // 恢复后重新绑定节拍器，继续自动tick
    PrimeMetronome timer = PrimeMetronome();
    timer.addTicker(this);
    return ok;
  }
}
