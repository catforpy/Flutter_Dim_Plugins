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


///
///   从StackTrace解析日志调用方信息
///   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
///
/// 示例调用栈格式：
/// #0      LogMixin.caller (package:lnc/src/log.dart:85:55)
/// #1      LogMixin.debug (package:lnc/src/log.dart:105:41)
/// #2      Log.debug (package:lnc/src/log.dart:50:45)
/// #3      main.<anonymous closure>.<anonymous closure> (file:///Users/moky/client/test/client_test.dart:14:11)
/// #4      Declarer.test.<anonymous closure>.<anonymous closure> (package:test_api/src/backend/declarer.dart:215:19)
/// <asynchronous suspension>
/// #5      Declarer.test.<anonymous closure> (package:test_api/src/backend/declarer.dart:213:7)
/// <asynchronous suspension>
/// #6      Invoker._waitForOutstandingCallbacks.<anonymous closure> (package:test_api/src/backend/invoker.dart:258:9)
/// <asynchronous suspension>
///
/// 解析目标格式：#?      function (path:1:2) 或 #?      function (path:1)

/// 日志调用方信息解析类
/// 作用：从StackTrace中提取调用日志的代码位置（方法名、文件路径、行号）
class LogCaller {
  /// 构造方法
  /// [anchor]：锚点字符串（用于定位日志框架内部代码的结束位置）
  /// [stacks]：当前调用栈（StackTrace.current）
  LogCaller(this.anchor, this.stacks);

  // 私有成员：锚点字符串（如"lnc/src/log.dart"，标记日志框架内部代码）
  final String anchor;
  // 私有成员：原始调用栈
  final StackTrace stacks;
  // 缓存解析后的调用方信息（避免重复解析）
  Map? _caller;

  /// 重写toString：返回"文件路径:行号"（如"client_test.dart:14"）
  @override
  String toString() => '$path:$line';

  /// 调用方方法名（如"main.<anonymous closure>.<anonymous closure>"）
  String? get name => caller?['name'];
  /// 调用方文件路径（如"file:///Users/moky/client/test/client_test.dart"）
  String? get path => caller?['path'];
  /// 调用方行号（如14）
  int?    get line => caller?['line'];

  // ---------------------------------------------------------------------------
  //  核心解析逻辑
  // ---------------------------------------------------------------------------

  /// 获取解析后的调用方信息（懒加载，首次调用才解析）
  Map? get caller {
    Map? info = _caller;
    if (info == null) {
      // 1. 将调用栈转为字符串列表（每行一个栈帧）
      List<String> traces = stacks.toString().split('\n');
      // 2. 定位并解析真实调用方
      info = locate(anchor, traces);
      // 3. 缓存解析结果
      _caller = info;
    }
    return info;
  }

  /// 定位真实调用方（跳过日志框架内部代码，找到业务代码的调用位置）
  /// [anchor]：锚点字符串（标记日志框架代码）
  /// [traces]：调用栈字符串列表
  /// 返回：调用方信息（name/path/line），未找到则返回null
  Map? locate(String anchor, List<String> traces) {
    bool flag = false;
    for (var element in traces) {
      if (checkAnchor(anchor, element)) {
        // 匹配到锚点：跳过日志框架内部代码，标记后续为业务代码
        flag = true;
      } else if (flag) {
        // 找到锚点后的第一个业务代码栈帧，解析并返回
        return parseCaller(element);
      }
    }
    // 断言：开发期提示（未找到调用方，锚点配置错误）
    assert(false, 'caller not found: $anchor -> $traces');
    return null;
  }

  /// 检查当前栈帧是否是日志框架内部代码（锚点匹配）
  /// [anchor]：锚点字符串
  /// [line]：单个栈帧字符串
  /// 返回：true=框架内部代码，false=业务代码
  bool checkAnchor(String anchor, String line) {
    if (line.contains(anchor)) {
      // 包含锚点字符串（如"lnc/src/log.dart"），是框架内部代码
      return true;
    }
    // 非"#数字 "开头的行（如"<asynchronous suspension>"），也视为框架内部代码
    return !line.startsWith('#');
  }

  /// 解析单个栈帧字符串，提取调用方信息
  /// [text]：单个栈帧字符串（如"#3      main.<anonymous closure> (file:///xxx/client_test.dart:14:11)"）
  /// 返回：调用方信息（name/path/line）
  Map? parseCaller(String text) {
    // 1. 跳过开头的"#数字 "（如"#3      "）
    int pos = text.indexOf(' ');
    text = text.substring(pos + 1).trimLeft();

    // 2. 拆分方法名和位置信息（如拆分"main.<anonymous closure>"和"(file:///xxx.dart:14:11)"）
    pos = text.lastIndexOf(' ');
    String name = text.substring(0, pos);  // 方法名
    String tail = text.substring(pos + 1); // 位置信息（带括号）

    // 3. 初始化默认值
    String path = 'unknown.file';
    String line = '-1';

    // 4. 解析位置信息（如从"(file:///xxx.dart:14:11)"提取路径和行号）
    int pos1 = tail.indexOf(':');
    if (pos1 > 0) {
      pos = tail.indexOf(':', pos1 + 1);
      if (pos > 0) {
        // 提取文件路径（去掉开头的"("）
        path = tail.substring(1, pos);
        // 提取行号
        pos1 = pos + 1;
        pos = tail.indexOf(':', pos1);
        if (pos > 0) {
          line = tail.substring(pos1, pos);
        } else if (pos1 < tail.length) {
          // 行号后无列号，提取到结尾（去掉最后的")"）
          line = tail.substring(pos1, tail.length - 1);
        }
      }
    }

    // 5. 返回解析结果
    return {
      'name': name,
      'path': path,
      'line': int.tryParse(line), // 行号转为int（解析失败则为null）
    };
  }
}