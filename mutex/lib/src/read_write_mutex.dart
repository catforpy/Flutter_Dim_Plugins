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

part of mutex;

//################################################################
/// 【内部类】锁请求的封装（对外不可见）
/// 每个获取锁的操作都会创建该对象，需等待时加入等待队列
class _ReadWriteMutexRequest {
  /// 构造函数：标记请求类型
  /// [isRead]：true=读锁请求，false=写锁请求
  _ReadWriteMutexRequest({required this.isRead});

  /// 锁类型标记：true=读锁，false=写锁
  final bool isRead; // true = 读锁请求; false = 写锁请求

  /// 异步完成器：锁获取成功时，通过该对象通知等待的任务
  final Completer<void> completer = Completer<void>();
}

//################################################################
/// 读写锁（ReadWriteMutex）
/// 核心规则：
/// 1. 读锁：多个可并发持有（支持多任务同时读）；
/// 2. 写锁：仅一个可持有（写时禁止所有读/写，读时禁止写）；
/// 3. 调度规则：FIFO（先进先出），避免锁饥饿（某个请求永远抢不到锁）。
///
/// 便捷使用示例：
///     m = ReadWriteMutex();
///     // 写锁保护（独占执行）
///     await m.protectWrite(() async {
///        // 写操作临界区
///     });
///     // 读锁保护（并发执行）
///     await m.protectRead(() async {
///         // 读操作临界区
///     });
///
/// 手动管理锁示例：
///     m = ReadWriteMutex();
///     // 获取写锁
///     await m.acquireWrite();
///     try {
///       // 写操作临界区
///       assert(m.isWriteLocked);
///     } finally {
///       m.release();
///     }
///     // 获取读锁
///     await m.acquireRead();
///     try {
///       // 读操作临界区
///       assert(m.isReadLocked);
///     } finally {
///       m.release();
///     }
class ReadWriteMutex {
  //================================================================
  // 成员变量
  /// 等待队列：存储所有未获取到锁的请求（FIFO 顺序）
  final _waiting = <_ReadWriteMutexRequest>[];

  /// 锁状态：-1 = 写锁持有; 0 = 无锁; >0 = 读锁持有数量
  int _state = 0;

  //================================================================
  // 只读属性
  /// 判断是否有任意锁（读/写）已获取且未释放
  bool get isLocked => (_state != 0);

  /// 判断是否有写锁已获取且未释放
  bool get isWriteLocked => (_state == -1);

  /// 判断是否有一个或多个读锁已获取且未释放
  bool get isReadLocked => (0 < _state);

  //================================================================
  // 公共方法：获取锁
  /// 获取读锁
  /// 返回 Future：锁获取成功后完成
  /// 规则：无写锁时可获取（已有读锁也可叠加）
  /// 注意：手动调用需配合 release()，否则无法获取写锁
  Future acquireRead() => _acquire(isRead: true);

  /// 获取写锁
  /// 返回 Future：锁获取成功后完成
  /// 规则：无任何锁（读/写）时才能获取
  /// 注意：手动调用需配合 release()，否则所有请求都会阻塞
  Future acquireWrite() => _acquire(isRead: false);

  /// 释放锁
  /// 释放之前获取的读/写锁，释放后会唤醒等待队列中可执行的请求
  /// 无锁时调用会抛出 [StateError]
  void release() {
    if (_state == -1) {
      // 释放写锁：状态置 0
      _state = 0;
    } else if (0 < _state) {
      // 释放读锁：持有数量减 1
      _state--;
    } else if (_state == 0) {
      // 无锁可释放，抛异常
      throw StateError('no lock to release');
    } else {
      // 理论上不会走到这里，断言提醒异常状态
      assert(false, 'invalid state');
    }

    // 释放后遍历等待队列，唤醒可执行的请求（读锁可批量唤醒）
    while (_waiting.isNotEmpty) {
      final nextJob = _waiting.first; // 取队列第一个请求
      if (_jobAcquired(nextJob)) {
        _waiting.removeAt(0); // 唤醒成功，从队列移除
      } else {
        // 第一个请求无法唤醒（如要写锁但当前有读锁），后续也无法唤醒，退出循环
        assert(_state < 0 || !nextJob.isRead,
            'unexpected: next job cannot be acquired');
        break;
      }
    }
  }

  /// 便捷方法：自动获取读锁执行临界区，执行后释放锁
  /// [criticalSection]：返回 Future 的异步临界区函数
  /// 返回值：临界区函数的执行结果（Future<T>）
  /// 特性：异常时仍会释放锁
  Future<T> protectRead<T>(Future<T> Function() criticalSection) async {
    await acquireRead();
    try {
      return await criticalSection();
    } finally {
      release();
    }
  }

  /// 便捷方法：自动获取写锁执行临界区，执行后释放锁
  /// [criticalSection]：返回 Future 的异步临界区函数
  /// 返回值：临界区函数的执行结果（Future<T>）
  /// 特性：异常时仍会释放锁
  Future<T> protectWrite<T>(Future<T> Function() criticalSection) async {
    await acquireWrite();
    try {
      return await criticalSection();
    } finally {
      release();
    }
  }

  //================================================================
  // 内部方法
  /// 【内部】统一处理读/写锁的获取逻辑
  /// [isRead]：true=读锁，false=写锁
  /// 返回 Future：锁获取成功后完成
  Future<void> _acquire({required bool isRead}) {
    // 创建新的锁请求
    final newJob = _ReadWriteMutexRequest(isRead: isRead);

    // 判断是否能立即获取锁：
    // - 等待队列非空（需排队）；
    // - 或当前状态不允许获取（如要写锁但已有读锁）
    if (_waiting.isNotEmpty || !_jobAcquired(newJob)) {
      _waiting.add(newJob); // 加入等待队列末尾
    }

    // 返回请求的 Future，等待锁获取成功
    return newJob.completer.future;
  }

  /// 【内部】判断请求是否能立即获取锁
  /// [job]：待判断的锁请求
  /// 返回值：true=能获取，false=不能
  /// 规则：
  /// - 读锁：无锁 或 已有读锁 → 可获取；
  /// - 写锁：仅无锁 → 可获取；
  /// 能获取时会完成请求的 completer 并更新状态
  bool _jobAcquired(_ReadWriteMutexRequest job) {
    assert(-1 <= _state); // 断言：状态必须合法（-1/0/正数）
    if (_state == 0 || (0 < _state && job.isRead)) {
      // 更新状态：读锁数量+1，写锁置-1
      _state = (job.isRead) ? (_state + 1) : -1;
      job.completer.complete(); // 通知请求：锁已获取
      return true;
    } else {
      return false;
    }
  }
}