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

import 'package:lnc/cache.dart';

import '../time.dart';

/// 缓存池全局管理器（单例模式）
/// 作用：管理多个命名的CachePool，支持批量清理所有池的过期缓存
class CacheManager {
  /// 工厂构造方法：返回单例实例
  factory CacheManager() => _instance;

  /// 静态单例实例（私有）
  static final CacheManager _instance = CacheManager._internal();

  /// 私有构造方法：防止外部实例化
  CacheManager._internal();

  /// 缓存池映射表: key = 池名称，value = CachePool实例
  final Map<String, dynamic> _poolMap = {};

  /// 根据名称获取缓存池（不存在则创建）
  /// [name]：缓存池名称（如"user_info"、"message_list"）
  /// 泛型K：缓存池的Key类型
  /// 泛型V：缓存池的Value类型
  /// 返回：指定名称的CachePool实例（单例，同一个名称返回同一个池）
  CachePool<K, V> getPool<K, V>(String name) {
    // 从映射表获取已有池
    CachePool<K, V>? pool = _poolMap[name];
    if (pool == null) {
      // 不存在则创建新池
      pool = CachePool();
      // 存入映射表
      _poolMap[name] = pool;
    }
    return pool;
  }

  /// 批量清理所有缓存池中的废弃缓存
  /// [now]：当前时间戳（单位：秒，默认取系统当前时间）
  /// 返回：总共清理的废弃缓存数量
  int purge(double? now) {
    // 初始化当前时间
    now ??= Time.currentTimestamp;
    // 统计清理总数
    int count = 0;
    CachePool? pool;
    // 遍历所有缓存池名称
    Iterable allKeys = _poolMap.keys;
    for (var key in allKeys) {
      // 获取缓存池实例
      pool = _poolMap[key];
      if (pool != null) {
        // 清理该池的废弃缓存，并累加数量
        count += pool.purge(now: now);
      }
    }
    return count;
  }
}
