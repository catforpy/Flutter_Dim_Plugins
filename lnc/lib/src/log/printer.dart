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

import 'caller.dart';  // 调用方信息类（LogCaller）


/// 日志输出器（负责最终的日志打印，支持分片、长度限制）
class LogPrinter {
  /// 分片长度（超长日志按此长度拆分，默认1000）
  static int chunkLength = 1000;
  /// 最大输出长度（-1表示无限制）
  static int limitLength = -1;
  /// 换行标记（分片日志的换行符，默认"↩️"）
  static String carriageReturn = '↩️';

  /// 彩色日志输出（核心方法）
  /// [body]：日志内容
  /// [head]：前缀（如颜色编码）
  /// [tail]：后缀（如颜色重置编码）
  /// [tag]：日志标签（如" DEBUG "）
  /// [caller]：调用方信息
  void output(String body, {
    String head = '', String tail = '',
    required String tag, required LogCaller caller,
  }) {
    int size = body.length;
    // 1. 限制日志最大长度
    if (0 < limitLength && limitLength < size) {
      body = '${body.substring(0, limitLength - 4)} ...';
      size = limitLength;
    }

    String x;
    // 2. 分片打印超长日志
    int start = 0, end = chunkLength;
    for (; end < size; start = end, end += chunkLength) {
      // 打印分片（加换行标记）
      x = head + body.substring(start, end) + tail + carriageReturn;
      println(x, tag: tag, caller: caller);
    }

    // 3. 打印最后一个分片（或完整日志）
    if (start > 0) {
      x = head + body.substring(start) + tail;
    } else {
      x = head + body + tail;
    }
    println(x, tag: tag, caller: caller);
  }

  /// 实际打印方法（可重写，如写入文件、发送到日志服务器等）
  /// [x]：最终要打印的字符串
  /// [tag]：日志标签
  /// [caller]：调用方信息
  void println(String x, {
    required String tag, required LogCaller caller,
  }) => print(x);
}