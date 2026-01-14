/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
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

import 'package:mutex/mutex.dart';

import 'package:dim_client/common.dart';
import 'package:dim_client/ok.dart';


///
///  数据访问任务：封装带缓存的数据库读写操作，保证并发安全
///


/// 数据库访问任务抽象类：封装带内存缓存的读写操作，通过互斥锁保证并发安全
/// [K] 缓存键类型
/// [V] 缓存值类型
abstract class DbTask<K, V> with Logging {
  /// 构造方法
  /// [mutexLock] 互斥锁（保证并发安全）
  /// [cachePool] 内存缓存池
  /// [cacheExpires] 缓存过期时间（秒，默认3600）
  /// [cacheRefresh] 缓存刷新时间（秒，默认128）
  DbTask(this.mutexLock, this.cachePool, {
    double? cacheExpires, double? cacheRefresh
  }){
    // 初始化缓存过期时间（默认1小时）
    _cacheExpires = cacheExpires ?? 3600;
    // 初始化缓存刷新时间(默认128秒)
    _cacheRefresh = cacheRefresh ?? 128;
    // 断言：过期时间和刷新时间必须大于0
    assert(_cacheExpires > 0, 'cache expires duration error: $_cacheExpires');
    assert(_cacheRefresh > 0, 'cache refresh duration error: $_cacheRefresh');
  }

  // 互斥锁：保证并发操作的线程安全
  final Mutex mutexLock;
  // 内存缓存池：存储键值对缓存
  final CachePool<K, V> cachePool;
  // 缓存过期时间（秒）
  late final double _cacheExpires;
  // 缓存刷新时间（秒）
  late final double _cacheRefresh;

  /// 缓存键（子类需实现）
  K get cacheKey;

  // 读取数据（子类需实现：从数据库读取）
  Future<V?> readData();

  // 写入数据（子类需实现：写入数据库）
  Future<bool> writeData(V value);

  /// 保存数据：写入数据库并更新缓存
  /// [value] 要保存的数据
  /// 返回保存是否成功
  Future<bool> save(V value) async {
    bool ok;
    // 加锁保证并发安全
    await mutexLock.acquire();
    try{
      // 写入数据库
      ok = await writeData(value);
      if(ok){
        // 保存成功，更新内存缓存
        cachePool.updateValue(cacheKey, value, _cacheExpires);
      }
    }finally{
      // 解锁
      mutexLock.release();
    }
    return ok;
  }

  /// 加载数据：优先从缓存读取，缓存未命中则从数据库加载并更新缓存
  /// 返回加载的数据（null表示无数据）
  Future<V?> load() async {
    double now = TimeUtils.currentTimeSeconds;
    CachePair<V>? pair;
    CacheHolder<V>? holder;
    V? value;
    ///
    ///  1. 检查内存缓存（无锁快速检查）
    ///
    pair = cachePool.fetch(cacheKey,now: now);
    holder = pair?.holder;
    value = pair?.value;
    if(value != null){
      // 缓存命中，直接返回
      return value;
    }else if(holder == null){
      // 缓存不存在，首次查询
    }else if(holder.isAlive(now: now)){
      // 缓存存在但已过期，且holder未失效（表示值确实为空），无需查询数据库
      return null;
    }
    ///
    ///  2. 加锁查询数据库
    ///
    await mutexLock.acquire();
    try{
      // 加锁后再次检查缓存（避免等待锁期间缓存已更新）
      pair = cachePool.fetch(cacheKey,now: now);
      holder = pair?.holder;
      value = pair?.value;
      if (value != null) {
        // 缓存已更新，直接返回
        return value;
      } else if (holder == null) {
        // 缓存仍不存在，准备查询
      } else if (holder.isAlive(now: now)) {
        // 值确实为空，返回null
        return null;
      } else {
        // holder已过期，更新过期时间（避免其他线程重复查询）
        holder.renewal(_cacheRefresh, now: now);
      }
      // 从数据库加载数据
      value = await readData();
      // 更新内存缓存
      cachePool.updateValue(cacheKey, value, _cacheExpires,now: now);
    }finally{
      mutexLock.release();
    }
    ///
    ///  3. 返回加载的数据
    ///
    return value;
  }
}

/// 数据缓存工具类：封装缓存池和互斥锁，简化缓存操作
/// [K] 缓存键类型
/// [V] 缓存值类型
class DataCache<K, V> with Logging{
  /// 构造方法
  /// [poolName] 缓存池名称（用于从CacheManager获取缓存池）
  DataCache(String poolName)
      : cachePool = CacheManager().getPool(poolName);

  /// 内存缓存池
  final CachePool<K,V> cachePool;
  /// 互斥锁：保证缓存操作的并发安全
  final Mutex mutexLock = Mutex();
}