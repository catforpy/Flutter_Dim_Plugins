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

import 'package:startrek/nio.dart';

/// 可中断通道：支持异步关闭/中断的通道
abstract interface class InterruptibleChannel implements NIOChannel {}

/// 可中断通道的基础实现类
/// 封装通道异步关闭/中断的底层逻辑，子类需实现implCloseChannel
abstract class AbstractInterruptibleChannel implements InterruptibleChannel {
  /// 通道状态：是否打开
  bool _open = true;

  /// 判断通道是否关闭(!_open)
  @override
  bool get isClosed => !_open;

  /// 关闭通道：确保只关闭一次
  @override
  Future<void> close() async {
    if (_open) {
      _open = false;
      await implCloseChannel();
    }
  }

  /// 实际关闭通道的实现方法（子类重写）
  /// 要求：若有线程阻塞在通道的I/O操作，需立即返回（抛异常/正常返回）
  Future<void> implCloseChannel();
}

/// 可被Selector多路复用的通道
/// 使用前需通过register方法注册到Selector，返回SelectionKey表示注册关系
/// 注册后需通过取消SelectionKey注销，通道关闭时自动取消所有Key
/// 同一通道最多注册到一个Selector
/// 支持阻塞/非阻塞模式：注册到Selector前需设为非阻塞
abstract class SelectableChannel extends AbstractInterruptibleChannel {
  /// 配置通道的阻塞模式
  /// @param block - true:阻塞，false:非阻塞
  /// @return 当前通道（支持链式调用）
  /// 已注册到Selector的通道不能切换回阻塞模式
  SelectableChannel? configureBlocking(bool block);

  /// 判断通道是否为阻塞模式（新创建的通道默认阻塞）
  bool get isBlocking;
}

/// 可选择通道的基础实现类
/// 维护阻塞模式状态，封装配置阻塞模式的逻辑
abstract class AbstractSelectableChannel extends SelectableChannel {
  /// 阻塞模式状态（默认true）
  bool _blocking = true;

  /// 获取当前阻塞模式
  @override
  bool get isBlocking => _blocking;

  /// 配置阻塞模式：检查通道状态 + 调用实际实现
  @override
  SelectableChannel? configureBlocking(bool block) {
    if (isClosed) {
      assert(false, '通道是关闭的');
      return null;
    } else if (_blocking == block) {
      // 模式未变化，直接返回
      return this;
    }
    // 调用子类的实际实现
    implConfigureBlocking(block);
    _blocking = block;
    return this;
  }

  /// 配置阻塞模式的实际实现（子类重写）
  /// 仅在模式变化时调用
  void implConfigureBlocking(bool block);
}
