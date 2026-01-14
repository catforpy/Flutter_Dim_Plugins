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

import 'package:dim_flutter/src/ui/nav.dart';
import 'package:dim_client/common.dart' as lib; // DIM客户端通用工具库




/// 时间工具类 - GetX架构下可直接运行，功能和原代码完全一致
abstract class TimeUtils {

  /// 获取当前时间（DateTime对象）
  static DateTime get currentTime => lib.TimeUtils.currentTime;

  /// 获取当前时间戳（毫秒）
  static int get currentTimeMilliseconds => currentTime.millisecondsSinceEpoch;
  /// 获取当前时间戳（微秒）
  static int get currentTimeMicroseconds => currentTime.microsecondsSinceEpoch;
  /// 获取当前时间戳（秒，浮点型）
  static double get currentTimeSeconds => currentTimeMicroseconds / 1000000.0;

  /// 获取当前时间戳（秒，UTC时间，浮点型）
  static double get currentTimestamp => currentTimeSeconds;

  /// 将时间戳转换为DateTime对象
  static DateTime? getTime(Object? timestamp) => lib.TimeUtils.getTime(timestamp);

  /// 将DateTime对象转换为时间戳
  static double? getTimestamp(Object? time) => lib.TimeUtils.getTimestamp(time);

  /// 格式化时间为可读字符串（GetX国际化完全可用）
  static String getTimeString(DateTime time) {
    time = time.toLocal();
    int timestamp = time.millisecondsSinceEpoch;
    DateTime now = currentTime;
    int midnight = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    int newYear = DateTime(now.year).millisecondsSinceEpoch;

    String hh = _twoDigits(time.hour);
    String mm = _twoDigits(time.minute);

    if (timestamp >= midnight) {
      // 👇 本质还是调用GetX的.tr，和你原来写'AM'.tr完全一样
      if (time.hour < 12) {
        return '${i18nTranslator.translate('AM')} $hh:$mm';
      } else {
        return '${i18nTranslator.translate('PM')} $hh:$mm';
      }
    } else if (timestamp >= (midnight - 24 * 3600 * 1000)) {
      // 👇 同理，还是GetX的.tr
      return '${i18nTranslator.translate('Yesterday')} $hh:$mm';
    } else if (timestamp >= (midnight - 72 * 3600 * 1000)) {
      String weekday = _weakDayName(time.weekday);
      return '$weekday $hh:mm';
    }

    String m = _twoDigits(time.month);
    String d = _twoDigits(time.day);
    if (timestamp >= newYear) {
      return '$m-$d $hh:mm';
    } else {
      return '${time.year}-$m-$d';
    }
  }

  /// 格式化时间为完整字符串（无改动）
  static String getFullTimeString(DateTime time) {
    time = time.toLocal();
    String m = _twoDigits(time.month);
    String d = _twoDigits(time.day);
    String h = _twoDigits(time.hour);
    String min = _twoDigits(time.minute);
    String sec = _twoDigits(time.second);
    return '${time.year}-$m-$d $h:$min:$sec';
  }

  /// 数字补零（无改动）
  static String _twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }

  /// 星期转换（本质还是GetX的.tr）
  static String _weakDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return i18nTranslator.translate('Monday'); // 等价于'Monday'.tr
      case DateTime.tuesday:
        return i18nTranslator.translate('Tuesday'); // 等价于'Tuesday'.tr
      case DateTime.wednesday:
        return i18nTranslator.translate('Wednesday');
      case DateTime.thursday:
        return i18nTranslator.translate('Thursday');
      case DateTime.friday:
        return i18nTranslator.translate('Friday');
      case DateTime.saturday:
        return i18nTranslator.translate('Saturday');
      case DateTime.sunday:
        return i18nTranslator.translate('Sunday');
      default:
        assert(false, 'weekday error: $weekday');
        return '';
    }
  }
}