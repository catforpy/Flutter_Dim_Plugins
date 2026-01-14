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

/// 互斥锁（Mutex）
///
/// [protect] 方法是便捷方法：执行临界区代码前自动获取锁，执行后自动释放锁，
/// 能确保锁始终被释放，避免死锁。
///
/// 使用示例：
///     m = Mutex();
///     await m.protect(() async {
///       // 临界区代码（同一时间仅一个任务执行）
///     });
///
/// 也可手动管理锁（需自行保证释放）：
///     m = Mutex();
///     await m.acquire();
///     try {
///       // 临界区代码
///     } finally {
///       m.release(); // 必须释放，否则其他任务永远拿不到锁
///     }
class Mutex {
  // 内部实现：复用读写锁的写锁能力（写锁天然独占，满足互斥需求）
  final ReadWriteMutex _rwMutex = ReadWriteMutex();

  /// 只读属性：判断是否有锁已获取且未释放
  bool get isLocked => (_rwMutex.isLocked);

  /// 获取互斥锁
  /// 返回 Future：锁获取成功后完成
  /// 注意：手动调用时必须配合 release() 使用，否则会导致死锁
  Future acquire() => _rwMutex.acquireWrite();

  /// 释放互斥锁
  /// 需在 acquire() 成功后调用，无锁时调用会抛出 StateError
  void release() => _rwMutex.release();

  /// 便捷方法：自动加锁执行临界区，执行后自动释放锁
  /// [criticalSection]：返回 Future 的异步临界区函数
  /// 返回值：临界区函数的执行结果（Future<T>）
  /// 特性：即使临界区抛异常，锁也会通过 finally 保证释放
  Future<T> protect<T>(Future<T> Function() criticalSection) async {
    await acquire(); // 先获取锁
    try {
      return await criticalSection(); // 执行临界区代码
    } finally {
      release(); // 无论是否异常，最终释放锁
    }
  }
}