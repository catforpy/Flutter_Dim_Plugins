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



/// 重复查询频率检查器
/// 用于限制相同Key的查询频率，避免重复请求
class FrequencyChecker <K> {
  /// 构造方法
  /// [lifeSpan] 有效期时长（超过此时长则认为过期，可以重新查询）
  FrequencyChecker(Duration lifeSpan) : _expires = lifeSpan;

  /// 存储每个key的过期时间
  final Map<K,DateTime> _records = {};

  /// 每个key的默认有效期
  final Duration _expires;

  /// 检查Key是否过期（常规检查）
  /// [key] 要检查的键
  /// [now] 当前时间
  /// 返回：true=已过期（可以查询），false=未过期（禁止重复查询）
  bool _checkExpired(K key, DateTime now){
    // 获取该key的过期事件
    DateTime? expired = _records[key];
    if(expired != null && expired.isAfter(now)){
      // 记录存在且未过期 -> 禁止查询
      return false;
    }
    // 记录不存在或已过期 -> 更新过期时间并允许查询
    _records[key] = now.add(_expires);
    return true;
  }

  /// 强制更新Key的过期时间
  /// [key] 要更新的键
  /// [now] 当前时间
  /// 返回：始终返回true（表示允许查询）
  bool _forceExpired(K key, DateTime now){
    // 强制更新过期事件，忽略原有记录
    _records[key] = now.add(_expires);
    return true;
  }

  /// 对外暴露的过期检查方法
  /// [key] 要检查的键
  /// [now] 自定义当前时间（默认使用系统当前时间）
  /// [force] 是否强制更新过期时间（true=忽略原有状态，强制允许查询）
  /// 返回：true=可以查询，false=禁止重复查询
  bool isExpired(K key, {DateTime? now, bool force = false}){
    // 初始化当前时间（默认使用系统时间）
    now ??= DateTime.now();
    // 根据force参数选择检查方式
    if(force){
      // 强制模式：更新过期时间并允许查询
      return _forceExpired(key, now);
    }else{
      // 常规模式：检查是否过期
      return _checkExpired(key, now);
    }
  }
}

/// 最近时间检查器
/// 用于记录Key的最近操作时间，判断时间是否有效
class RecentTimeChecker<K> {
  /// 存储每个key的最近操作事件
  final Map<K,DateTime> _times = {};

  /// 设置Key的最后操作时间
  /// [key] 要设置的键
  /// [now] 要记录的时间（null会触发断言错误）
  /// 返回：true=时间更新成功，false=传入时间早于已有记录
  bool setLastTime(K key,DateTime? now){
    if(now == null){
      // 断言：时间不能为空（调试模式下触发）
      assert(false, 'recent time empty: $key');
      return false;
    }
    // TODO: 时钟校准（待实现）

    // 获取该key的最后操作时间
    DateTime? last = _times[key];
    // 首次记录或传入时间晚于最后记录时间 -> 更新并返回true
    if(last == null || last.isBefore(now)){
      _times[key] = now;
      return true;
    }
    // 传入时间遭遇最后记录时间 -> 不更新并返回false
    return false;
  }

  /// 检查Key是否过期（时间有效性检查）
  /// [key] 要检查的键
  /// [now] 当前时间（null时直接返回true）
  /// 返回：true=已过期（最后操作时间晚于当前时间），false=未过期
  bool isExpired(K key, DateTime? now){
    if(now == null){
      // 注释： 原断言被注释，空时间直接返回true
      // assert(false,'recent time empty: $key);
      return true;
    }
    // 获取该key 的最后操作时间
    DateTime? last = _times[key];
    // 最后操作时间存在 且晚于当前时间 -> 判断为过期
    return last != null && last.isAfter(now);
  }
}