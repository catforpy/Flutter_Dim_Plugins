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

/// 时间工具类
/// 提供时间戳与DateTime对象的转换、当前时间获取等功能
abstract class TimeUtils{
  /// 获取当前时间（DateTime对象）
  ///  返回：系统当前时间
  static DateTime get currentTime => DateTime.now();

  /// 获取当前时间戳（毫秒级）
  /// 返回：从1970-01-01 00:00:00 UTC到现在的毫秒数
  static int get currentTimeMilliseconds => currentTime.millisecondsSinceEpoch;

  /// 获取当前时间戳（微秒级）
  /// 返回：从1970-01-01 00:00:00 UTC到现在的微秒数
  static int get currentTimeMicroseconds => currentTime.microsecondsSinceEpoch;

  /// 获取当前时间戳（秒级，浮点型）
  /// 返回：从1970-01-01 00:00:00 UTC到现在的秒数（保留微秒精度）
  static double get currentTimeSeconds => currentTimeMicroseconds / 1000000.0;

  /// 获取当前时间戳（别名，与currentTimeSeconds一致）
  /// 返回：从1970-01-01 00:00:00 UTC到现在的秒数（浮点型）
  static double get currentTimestamp => currentTimeSeconds;

  /// 将任意类型的时间戳转换为DateTime对象
  /// [timestamp] 支持类型：DateTime、double、int、String
  /// 返回：对应的DateTime对象，不支持的类型返回null
  static DateTime? getTime(Object? timestamp){
    double? seconds;
    if(timestamp == null){
      // 空值直接返回Null
      return null;
    }else if(timestamp is DateTime){
      // 已是DateTime对象，直接返回
      return timestamp;
    }else if(timestamp is double){
      // 浮点型秒数，直接赋值
      seconds = timestamp;
    }else if(timestamp is num){   // 整型（int）
      // 整型转换为浮点型秒数
      // assert(false, 'not a double value: timestamp');
      seconds = timestamp.toDouble();
    }else if(timestamp is String){ 
      // 字符串转换为浮点型秒数
      seconds = double.parse(timestamp);
    }else{
      // 不支持的类型，断言并返回null
      assert(false, 'unknown timestamp: $timestamp');
      return null;
    }
    // 秒数转换为微妙级，再创建DateTime对象
    double ms = seconds * 1000000;
    return DateTime.fromMicrosecondsSinceEpoch(ms.toInt());
  }

  /// 将任意类型的时间转换为秒级时间戳（浮点型）
  /// [time] 支持类型：DateTime、double、int、String
  /// 返回：对应的秒级时间戳，不支持的类型返回null
  static double? getTimestamp(Object? time) {
    if (time == null) {
      // 空值直接返回null
      return null;
    } else if (time is DateTime) {
      // DateTime对象转换为微秒数，再转为秒级浮点型
      return time.microsecondsSinceEpoch / 1000000.0;
    } else if (time is double) {
      // 已是浮点型秒数，直接返回
      return time;
    } else if (time is num) {  // 整型（int）
      // 整型转换为浮点型秒数
      // assert(false, 'not a double value: time');
      return time.toDouble();
    } else if (time is String) {
      // 字符串转换为浮点型秒数
      return double.parse(time);
    } else {
      // 不支持的类型，断言并返回null
      assert(false, 'unknown time: $time');
      return null;
    }
  }
}