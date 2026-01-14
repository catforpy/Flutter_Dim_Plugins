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

import 'package:lnc/log.dart';

import '../time.dart';

/// 日志核心配置类（全局单例使用）
/// 作用：定义日志级别、全局配置（彩色输出、显示时间/调用方、日志长度限制）
class Log {
  // 忽略lint警告：常量命名规则（允许全大写）
  // ignore_for_file: constant_identifier_names

  // -------------------------- 日志级别掩码 --------------------------
  static const int DEBUG_FLAG = 1 << 0; // 调试级掩码（0001）
  static const int INFO_FLAG = 1 << 1; // 信息级掩码（0010）
  static const int WARNING_FLAG = 1 << 2; // 警告级掩码（0100）
  static const int ERROR_FLAG = 1 << 3; // 错误级掩码（1000）

  // -------------------------- 预设日志级别 --------------------------
  static const int DEBUG =
      DEBUG_FLAG | INFO_FLAG | WARNING_FLAG | ERROR_FLAG; // 调试（所有级别）
  static const int DEVELOP =
      INFO_FLAG | WARNING_FLAG | ERROR_FLAG; // 开发（INFO+WARNING+ERROR）
  static const int RELEASE = WARNING_FLAG | ERROR_FLAG; // 发布（仅WARNING+ERROR）

  // 忽略lint警告：非const变量命名（允许全大写）
  // ignore_for_file: non_constant_identifier_names
  /// 日志最大长度（超过则截断，默认1024）
  static int MAX_LEN = 1024;

  /// 当前日志级别（默认RELEASE）
  static int level = RELEASE;

  /// 是否启用彩色输出（默认false）
  static bool colorful = false;

  /// 是否显示日志时间（默认true）
  static bool showTime = true;

  /// 是否显示调用方（文件+行号，默认false）
  static bool showCaller = false;

  /// 全局日志器实例（默认DefaultLogger）
  static Logger logger = DefaultLogger();

  // -------------------------- 快捷调用方法 --------------------------
  static void debug(String msg) => logger.debug(msg);
  static void info(String msg) => logger.info(msg);
  static void warning(String msg) => logger.warning(msg);
  static void error(String msg) => logger.error(msg);
}

/// 带类名的日志混入类
/// 作用：给业务类添加日志方法（自动携带类名，便于日志定位）
mixin Logging {
  /// 获取当前类的名称（默认Object）
  String get className => _runtimeType(this) ?? 'Object';

  /// 打印调试日志（自动携带类名）
  void logDebug(String msg) =>
      Log.logger.debug(msg, className: _runtimeType(this));

  /// 打印信息日志（自动携带类名）
  void logInfo(String msg) =>
      Log.logger.info(msg, className: _runtimeType(this));

  /// 打印警告日志（自动携带类名）
  void logWarning(String msg) =>
      Log.logger.warning(msg, className: _runtimeType(this));

  /// 打印错误日志（自动携带类名）
  void logError(String msg) =>
      Log.logger.error(msg, className: _runtimeType(this));
}

/// 工具方法：获取对象的运行时类型名称（封装，避免直接调用runtimeType影响性能）
/// [object]：目标对象
/// [className]：缓存的类名（避免重复计算）
/// 返回：对象的运行时类型名称
String? _runtimeType(Object object, [String? className]) {
  assert(() {
    // 注意：调用runtimeType.toString会影响性能，仅在断言模式下执行
    className = object.runtimeType.toString();
    return true;
  }());
  return className;
}

/// 默认日志器实现（混入LogMixin，复用核心逻辑）
class DefaultLogger with LogMixin {
  /// 构造方法
  /// [logPrinter]：日志输出器（默认LogPrinter）
  DefaultLogger([LogPrinter? logPrinter]) {
    _printer = logPrinter ?? LogPrinter();
  }

  /// 日志输出器实例
  late final LogPrinter _printer;

  /// 实现Logger接口：获取输出器
  @override
  LogPrinter get printer => _printer;
}

/// 日志器接口（定义核心日志方法）
abstract interface class Logger {
  // -------------------------- 日志标签 --------------------------
  static String DEBUG_TAG = " DEBUG "; // 调试日志标签
  static String INFO_TAG = "       "; // 信息日志标签（空，对齐）
  static String WARNING_TAG = "WARNING"; // 警告日志标签
  static String ERROR_TAG = " ERROR "; // 错误日志标签

  /// 获取日志输出器
  LogPrinter get printer;

  /// 打印调试日志
  void debug(String msg, {String? className});

  /// 打印信息日志
  void info(String msg, {String? className});

  /// 打印警告日志
  void warning(String msg, {String? className});

  /// 打印错误日志
  void error(String msg, {String? className});

  /// 截断超长日志（避免日志刷屏）
  /// [text]：原始日志内容
  /// [maxLen]：最大长度
  /// 返回：截断后的日志（中间加省略号，保留首尾）
  static String shorten(String text, int maxLen) {
    assert(maxLen > 128, 'too short: $maxLen'); // 最小长度限制
    int size = text.length;
    if (size <= maxLen) {
      // 未超长，直接返回
      return text;
    }
    // 生成描述（总长度）
    String desc = 'total $size chars';
    // 计算首尾保留长度
    int pos = (maxLen - desc.length - 10) >> 1;
    if (pos <= 0) {
      return text;
    }
    // 截取首尾，中间加省略号
    String prefix = text.substring(0, pos);
    String suffix = text.substring(size - pos);
    return '$prefix ... $desc ... $suffix';
  }
}

/// 日志核心混入类（实现Logger接口，封装通用日志逻辑）
mixin LogMixin implements Logger {
  // -------------------------- 彩色输出配置 --------------------------
  static String colorRed = '\x1B[95m'; // 错误日志颜色（洋红）
  static String colorYellow = '\x1B[93m'; // 警告日志颜色（黄色）
  static String colorGreen = '\x1B[92m'; // 调试日志颜色（绿色）
  static String colorClear = '\x1B[0m'; // 重置颜色

  /// 获取当前时间字符串（格式由Time工具类定义）
  String get now => Time.now;

  /// 获取日志调用方信息（可重写，自定义解析逻辑）
  LogCaller get caller => LogCaller('lnc/src/log/log.dart', StackTrace.current);

  /// 日志输出核心方法（封装格式、颜色、调用方等逻辑）
  /// [msg]：日志内容
  /// [className]：类名（可选）
  /// [tag]：日志标签（如" DEBUG "）
  /// [color]：颜色编码（如colorGreen）
  void output(
    String msg, {
    String? className,
    required String tag,
    required String color,
  }) {
    // 1. 截断超长日志
    int maxLen = Log.MAX_LEN;
    if (maxLen > 0) {
      msg = Logger.shorten(msg, maxLen);
    }

    // 2. 处理彩色输出
    String clear;
    if (Log.colorful && color.isNotEmpty) {
      clear = colorClear; // 需要重置颜色
    } else {
      color = ''; // 禁用彩色
      clear = '';
    }

    // 3. 构建日志主体（拼接调用方、类名）
    String body;
    var locate = caller; // 获取调用方信息
    if (Log.showCaller) {
      // 显示调用方：文件路径:行号 | 类名 > 日志内容
      if (className == null) {
        body = '$locate >\t$msg';
      } else {
        body = '$locate | $className >\t$msg';
      }
    } else {
      // 不显示调用方：类名 > 日志内容
      if (className == null) {
        body = msg;
      } else {
        body = '$className >\t$msg';
      }
    }

    // 4. 拼接时间和标签
    if (Log.showTime) {
      body = '[$now] $tag | $body';
    } else {
      body = '$tag | $body';
    }

    // 5. 调用输出器打印（支持彩色）
    if (Log.colorful) {
      printer.output(body, head: color, tail: clear, tag: tag, caller: locate);
    } else {
      printer.output(body, tag: tag, caller: locate);
    }
  }

  // -------------------------- 实现Logger接口 --------------------------
  @override
  void debug(String msg, {String? className}) {
    assert(() {
      // 仅在断言模式下执行（避免影响生产环境性能）
      var flag = Log.level & Log.DEBUG_FLAG;
      if (flag > 0) {
        output(
          msg,
          className: className,
          tag: Logger.DEBUG_TAG,
          color: colorGreen,
        );
      }
      return true;
    }());
  }

  @override
  void info(String msg, {String? className}) {
    assert(() {
      var flag = Log.level & Log.INFO_FLAG;
      if (flag > 0) {
        output(msg, className: className, tag: Logger.INFO_TAG, color: '');
      }
      return true;
    }());
  }

  @override
  void warning(String msg, {String? className}) {
    assert(() {
      var flag = Log.level & Log.WARNING_FLAG;
      if (flag > 0) {
        output(
          msg,
          className: className,
          tag: Logger.WARNING_TAG,
          color: colorYellow,
        );
      }
      return true;
    }());
  }

  @override
  void error(String msg, {String? className}) {
    // 错误日志不使用断言（确保生产环境也能输出）
    var flag = Log.level & Log.ERROR_FLAG;
    if (flag > 0) {
      output(msg, className: className, tag: Logger.ERROR_TAG, color: colorRed);
    }
  }
}
