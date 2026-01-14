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

/// 缓存查询结果的包装类
/// 作用：一次性返回缓存值和对应的CacheHolder（方便上层判断过期状态）
/// 泛型V：缓存值的类型
class CachePair <V> {
  /// 构造方法
  /// [value]：缓存的实际值（可null）
  /// [holder]：缓存值的包装类（包含过期信息）
  CachePair(this.value, this.holder);

  /// 缓存的实际值
  final V? value;
  /// 缓存值的包装类（元信息）
  final CacheHolder<V> holder;
}

/// 单类别缓存池（Key-Value结构）
/// 作用：管理同一类别的缓存（如用户信息、消息列表），封装增删查、过期清理
/// 泛型K：缓存Key的类型
/// 泛型V：缓存Value的类型
class CachePool <K, V> {

  /// 缓存映射表: key = 业务Key,value = cacheHolder(包装后的缓存值)
  final Map<K,CacheHolder<V>> _holderMap = {};

  /// 对外暴露：获取缓存池所有的key(只读)
  Iterable<K> get keys => _holderMap.keys;

  /// 更新指定Key对应的CacheHolder
  /// [key]：缓存Key
  /// [holder]：新的CacheHolder实例
  /// 返回：存入的CacheHolder实例（方便链式调用）
  CacheHolder<V> updateHolder(K key, CacheHolder<V> holder) {
    _holderMap[key] = holder;
    return holder;
  }

  /// 快捷方法：更新指定Key的缓存值（自动创建CacheHolder）
  /// [key]：缓存Key
  /// [value]：新的缓存值（可null）
  /// [life]：缓存生命周期（单位：秒）
  /// [now]：当前时间戳（单位：秒，默认取系统当前时间）
  /// 返回：创建的CacheHolder实例
  CacheHolder<V> updateValue(K key, V? value, double life, {double? now}) =>
    updateHolder(key, CacheHolder(value, life,now: now));

  /// 删除指定Key的缓存
  /// [key]：缓存Key
  /// [now]：当前时间戳（单位：秒，传值则返回删除前的缓存信息）
  /// 返回：删除前的缓存信息（CachePair），未传now则返回null
  CachePair<V>? erase(K key, {double? now}) {
    CachePair<V>? old;
    if(now != null){
      // 传了now,现货区删除前的缓存信息
      old = fetch(key,now:now);
    }
    // 从映射表删除该Key
    _holderMap.remove(key);
    return old;
  }

  /// 查询指定Key的缓存（包含状态判断）
  /// [key]：缓存Key
  /// [now]：当前时间戳（单位：秒，默认取系统当前时间）
  /// 返回：CachePair（包含值和Holder），Key不存在则返回null；
  ///       注意：即使缓存已过期，也会返回CachePair，但value为null
  CachePair<V>? fetch(K key, {double? now}) {
    // 获取缓存
    CacheHolder<V>? holder = _holderMap[key];
    if (holder == null) {
      // Key不存在，返回null
      return null;
    }else if(holder.isAlive(now: now)){
      // 缓存存活，返回值+Holder
      return CachePair(holder.value, holder);
    }else{
      // 缓存已过期，返回null值+Holder（上层可通过Holder判断状态）
      return CachePair(null, holder);
    }
  }

  /// 清理缓存池中已废弃的缓存（超过deprecated时间）
  /// [now]：当前时间戳（单位：秒，默认取系统当前时间）
  /// 返回：清理的缓存数量
  int purge({double? now}){
    // 初始化当前时间
    now ??= Time.currentTimestamp;
    // 统计清理数量
    int count = 0;
    // 遍历所有key(注意：遍历的是快照，避免遍历时修改映射表)
    Iterable allKeys = keys;
    CacheHolder? holder;
    for(K key in allKeys){
      // 获取缓存Holder
      holder = _holderMap[key];
      if(holder == null || holder.isDeprecated(now: now)){
        // Holder不存在 或已废弃，删除该key
        _holderMap.remove(key);
        ++count;
      }
    }
    return count;
  }
}