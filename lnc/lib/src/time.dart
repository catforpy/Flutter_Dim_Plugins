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

/// 通用时间工具类（抽象类，仅包含静态方法/属性，无需实例化）
/// 作用：封装时间戳转换、当前时间获取、时间格式化等常用操作，适配缓存/日志等场景
abstract class Time{

  /// 获取当前时间（DateTime对象）
  /// 返回：本地时区的当前DateTime实例
  static DateTime get currentTime => DateTime.now();

  /// 获取当前时间戳（毫秒级）
  /// 说明：1秒 = 1000毫秒，值为从1970-01-01 00:00:00 UTC到当前时间的毫秒数
  static int get currentTimeMilliseconds => currentTime.millisecondsSinceEpoch;
  
  /// 获取当前时间戳（微秒级）
  /// 说明：1秒 = 1000000微秒，值为从1970-01-01 00:00:00 UTC到当前时间的微秒数
  static int get currentTimeMicroseconds => currentTime.microsecondsSinceEpoch;
  
  /// 【注释保留】兼容别名（millis = milliseconds）
  // static int get currentTimeMillis => currentTimeMilliseconds;
  
  /// 获取当前时间戳（秒级，浮点型）
  /// 说明：微秒数 ÷ 1000000 得到带小数的秒级时间戳（如1734681234.567）
  static double get currentTimeSeconds => currentTimeMicroseconds / 1000000.0;

  /// 获取当前时间戳（秒级，浮点型，别名）
  /// 说明：与currentTimeSeconds等价，语义更清晰（timestamp = 时间戳），适配缓存过期判断等场景
  static double get currentTimestamp => currentTimeSeconds;

  /// 获取格式化后的当前时间字符串（完整格式：yyyy-mm-dd HH:MM:SS）
  /// 示例：2025-12-20 15:30:45
  static String get now {
    DateTime time = DateTime.now();
    // 月份补零（如1月→01，12月→12）
    String m = _twoDigits(time.month);
    // 日期补零（如5日→05，20日→20）
    String d = _twoDigits(time.day);
    // 小时补零（如8点→08，18点→18）
    String h = _twoDigits(time.hour);
    // 分钟补零（如9分→09，59分→59）
    String min = _twoDigits(time.minute);
    // 秒数补零（如3秒→03，58秒→58）
    String sec = _twoDigits(time.second);
    // 拼接成标准格式字符串
    return '${time.year}-$m-$d $h:$min:$sec';
  }

  /// 私有工具方法：数字补零（确保输出两位字符串）
  /// [n]：需要补零的数字（如1、10、23）
  /// 返回：两位字符串（如1→"01"，10→"10"）
  static String _twoDigits(int n) {
    if (n >= 10) return "$n"; // 大于等于10，直接转字符串
    return "0$n";             // 小于10，前面补零
  }
}