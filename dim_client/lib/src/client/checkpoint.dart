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

import 'package:dimsdk/dimsdk.dart';

/// 消息签名池，用于检测重复消息
/// 核心功能：缓存消息签名+接收者组合，避免处理重复消息
class SigPool {
  /// 缓存过期事件（1小时，单位：毫秒）
  static int kExpires = 3600 * 1000;

  /// 缓存映射表：key=签名:接收者地址，value=时间戳
  final Map<String, int> _caches = {};

  /// 下次清理过期缓存的时间戳
  int _nextTime = 0;

  /// 清理过期的缓存记录
  /// [now]：当前时间
  /// 返回：是否执行了清理操作
  bool purge(DateTime now) {
    // 检查是否到清理时间
    if (now.millisecondsSinceEpoch < _nextTime) {
      return false;
    }
    // 重新获取当前时间（避免传入的now不是最新）
    now = DateTime.now();
    int timestamp = now.millisecondsSinceEpoch;
    if (timestamp < _nextTime) {
      return false;
    } else {
      // 设置下次清理时间（5分钟后）
      _nextTime = timestamp + 300 * 1000;
    }
    // 计算过期时间戳（当前时间 - 1小时）
    int expired = timestamp - kExpires;
    // 移除所有过期的缓存项
    _caches.removeWhere((key, value) => value < expired);
    return true;
  }

  /// 检查消息是否重复
  /// [msg]：待检查的可靠消息
  /// 返回：true=重复，false=不重复
  bool duplicated(ReliableMessage msg) {
    // 获取消息签名
    String? sig = msg.getString('signature');
    if (sig == null) {
      assert(false, 'message error: $msg');
      return true;
    } else {
      // 截取签名最后16个字符（缩短key长度）
      sig = getSig(sig, 16);
    }
    // 获取接收者地址
    String address = msg.receiver.address.toString();
    // 生成缓存key：签名:地址
    String tag = '$sig:$address';
    // 检查缓存是否存在
    if (_caches.containsKey(tag)) {
      return true;
    }
    // 缓存不存在，添加新记录
    DateTime? when = msg.time;
    when ??= DateTime.now();
    _caches[tag] = when.millisecondsSinceEpoch;
    return false;
  }

  /// 截取签名的最后N个字符（用于缩短缓存key）
  /// [signature]：完整签名
  /// [maxLen]：最大长度
  /// 返回：截取后的签名（或原签名，如果长度不足）
  static String? getSig(String? signature, int maxLen) {
    assert(maxLen > 0);
    int len = signature?.length ?? 0;
    return len <= maxLen ? signature : signature?.substring(len - maxLen);
  }
}

/// 消息重复检查器（单例）
/// 封装SigPool，提供简洁的重复消息检测接口
class Checkpoint {
  /// 单例工厂方法
  factory Checkpoint() => _instance;

  /// 单例实例
  static final Checkpoint _instance = Checkpoint._internal();

  /// 私有构造方法
  Checkpoint._internal();

  /// 签名池实例
  final SigPool _pool = SigPool();

  /// 检查消息是否重复
  /// [msg]：待检查的可靠消息
  /// 返回：true=重复，false=不重复
  bool duplicated(ReliableMessage msg) {
    // 检查重复
    bool repeated = _pool.duplicated(msg);
    // 获取消息时间，清理过期缓存
    DateTime? now = msg.time;
    if (now != null) {
      _pool.purge(now);
    }
    return repeated;
  }

  /// 获取消息的短签名（8位）
  /// [msg]：可靠消息
  /// 返回：8位短签名
  String? getSig(ReliableMessage msg) {
    String? sig = msg.getString('signature');
    return SigPool.getSig(sig, 8);
  }
}
