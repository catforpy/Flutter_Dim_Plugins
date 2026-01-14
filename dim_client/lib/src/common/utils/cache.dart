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

/// 内存缓存抽象接口
/// 定义缓存的基本操作：获取、存入、内存回收
abstract interface class MemoryCache<K, V> {
  /// 根据键获取缓存值
  /// [key] 缓存键
  /// 返回：缓存值，不存在则返回Null
  V? get(K key);

  /// 存入缓存值
  /// [key] 缓存键
  /// [value] 缓存值（null表示移除该键）
  void put(K key,V? value);

  /// 回收内存（清理部分缓存）
  /// 返回：实际清理的缓存条目数量
  int reduceMemory();
}

/// Thanos缓存实现类
/// 特色：reduceMemory方法会像灭霸一样"消灭"一半的缓存条目
class ThanosCache<K, V> implements MemoryCache<K, V> {
  /// 内部缓存存储容器
  final Map<K,V> _caches = {};

  @override
  V? get(K key) => _caches[key]; 

  @override
  void put(K key,V? value) => value == null
    ? _caches.remove(key)       // 值为null时移除该键
    : _caches[key] = value;     // 值非null时存入缓存

  @override
  int reduceMemory(){
    int finger = 0;   // 计数器，用于标记要删除的条目
    // 调用thanos方法清理一半缓存，更新计数器
    finger = thanos(_caches, finger);
    // 计数器右移一位 = 实际删除的条目数（因为每2个删1个）
    return finger >> 1;
  }
}

/// 灭霸清理方法
/// 核心逻辑：遍历Map，删除奇数位置的条目（每2个删1个）
/// [planet] 要清理的Map（比喻为灭霸的星球）
/// [finger] 初始计数器（比喻为灭霸的手指）
/// 返回：更新后的计数器值
int thanos(Map planet, int finger) {
  // 遍历Map，++finger为奇数时删除该条目（&1 ==1 等价于 %2 ==1）
  planet.removeWhere((key, value) => (++finger & 1) == 1);
  return finger; // 返回最终计数器值
}