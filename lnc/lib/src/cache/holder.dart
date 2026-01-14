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

import '../time.dart';

/// 缓存值的包装类（带过期/废弃时间元信息）
/// 泛型V：缓存值的类型
class CacheHolder <V> {
  /// 构造方法
  /// [cacheValue]：要缓存的实际值（可null）
  /// [cacheLifeSpan]：缓存的生命周期（单位：秒）
  /// [now]：当前时间戳（单位：秒，默认取系统当前时间）
  CacheHolder(V? cacheValue, double cacheLifeSpan, {double? now})
      : _value = cacheValue, _life = cacheLifeSpan{
        // 初始化当前时间(默认取系统当前时间戳)
        now ??= Time.currentTimestamp;
        // 计算过期时间：当前时间 + 生命周期（过期后仍可使用，但建议更新）
        _expired = now + cacheLifeSpan;
        // 计算废弃时间： 当前时间+ 生命周期*2 （废弃后直接删除）
        _deprecated = now + cacheLifeSpan * 2;
      }
  /// 缓存的实际值
  V? _value;

  /// 缓存的生命周期（单位：秒，固定值）
  final double _life;
  /// 缓存过期时间戳（单位：秒）：过期后仍可读取，但建议重新获取
  double _expired = 0;
  /// 缓存废弃时间戳（单位：秒）：废弃后直接从缓存池删除
  double _deprecated = 0;

  /// 对外暴露：获取缓存的实际值（只读）
  V? get value => _value;

  /// 更新缓存值，并重置过期/废弃时间
  /// [newValue]：新的缓存值（可null）
  /// [now]：当前时间戳（单位：秒，默认取系统当前时间）
  void updateValue(V? newValue, {double? now}) {
    // 更新缓存值
    _value = newValue;
    // 初始化当前时间
    now ??= Time.currentTimestamp;
    // 重置过期时间
    _expired = now + _life;
    // 重置废弃时间
    _deprecated = now + _life * 2;
  }

  /// 检查缓存是否“存活”（未过期）
  /// [now]：当前时间戳（单位：秒，默认取系统当前时间）
  /// 返回：true=存活（可直接使用），false=已过期（建议重新获取）
  bool isAlive({double? now}) {
    now ??= Time.currentTimestamp;
    return now < _expired;
  }

  /// 检查缓存是否“废弃”（超过废弃时间）
  /// [now]：当前时间戳（单位：秒，默认取系统当前时间）
  /// 返回：true=已废弃（需从缓存池删除），false=未废弃
  bool isDeprecated({double? now}) {
    now ??= Time.currentTimestamp;
    return now > _deprecated;
  }

  /// 缓存续期（临时延长过期时间，废弃时间不变）
  /// [duration]：临时续期时长（单位：秒，默认120秒）
  /// [now]：当前时间戳（单位：秒，默认取系统当前时间）
  void renewal(double? duration, {double? now}) {
    // 默认续期120秒
    duration ??= 120;
    // 初始化当前时间
    now ??= Time.currentTimestamp;
    // 延长过期时间（仅临时续期，不改变废弃时间）
    _expired = now + duration;
    // 废弃时间仍按原生命周期计算，不改变
    _deprecated = now + _life * 2;
  }
}