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

import 'package:flutter/services.dart'; // Flutter系统服务（键盘事件）


/// 原始键盘按键模型 - 封装按键值和修饰键状态
class RawKeyboardKey {
  RawKeyboardKey(this.value);

  final int value; // 按键值（包含修饰键信息）

  /// 是否按下Shift键
  bool get isShiftPressed => value & _ModifierKeyCode.shift == _ModifierKeyCode.shift;
  /// 是否按下Ctrl键
  bool get isCtrlPressed => value & _ModifierKeyCode.ctrl == _ModifierKeyCode.ctrl;
  /// 是否按下Alt键
  bool get isAltPressed => value & _ModifierKeyCode.alt == _ModifierKeyCode.alt;
  // Apple系统 - 是否按下Command键
  bool get isMetaPressed => value & _ModifierKeyCode.meta == _ModifierKeyCode.meta;

  /// 是否按下任意修饰键（Shift/Ctrl/Alt/Meta）
  bool get isModified => isShiftPressed || isCtrlPressed || isAltPressed || isMetaPressed;

  /// 重写toString - 输出按键值
  @override
  String toString() => '<$runtimeType value="$value" />';

  /// 重写相等判断 - 比较按键值（仅低16位）
  @override
  bool operator ==(Object other) {
    int otherValue = -1;
    if (other is RawKeyboardKey) {
      if (identical(this, other)) {
        // 同一对象，直接返回true
        return true;
      }
      otherValue = other.value;
    } else if (other is LogicalKeyboardKey) {
      // 兼容LogicalKeyboardKey类型
      otherValue = other.keyId;
    }
    assert(otherValue > 0, 'other key error: $other');
    // 仅比较低16位（忽略修饰键）
    return (otherValue & 0x0000ffff) == (value & 0x0000ffff);
  }

  /// 重写哈希值 - 使用按键值
  @override
  int get hashCode => value;

  //
  //  工厂方法
  //
  /// 从LogicalKeyboardKey创建RawKeyboardKey
  /// 仅保留低16位按键值
  static RawKeyboardKey logical(LogicalKeyboardKey key) =>
      RawKeyboardKey(key.keyId & 0x0000ffff);

  //
  //  常用键盘按键常量
  //
  static final backspace  = logical(LogicalKeyboardKey.backspace);  // 退格键 (0008)
  static final tab        = logical(LogicalKeyboardKey.tab);        // Tab键 (0009)
  static final enter      = logical(LogicalKeyboardKey.enter);      // 回车键 (000d)
  static final escape     = logical(LogicalKeyboardKey.escape);     // ESC键 (001b)
  static final space      = logical(LogicalKeyboardKey.space);      // 空格键 (0020)

  static final capsLock   = logical(LogicalKeyboardKey.capsLock);   // 大小写锁定 (0104)
  static final fn         = logical(LogicalKeyboardKey.fn);         // FN功能键 (0106)
  static final fnLock     = logical(LogicalKeyboardKey.fnLock);     // FN锁定 (0107)
  static final numLock    = logical(LogicalKeyboardKey.numLock);    // 数字锁定 (010a)

  static final arrowDown  = logical(LogicalKeyboardKey.arrowDown);  // 下方向键 (0301)
  static final arrowLeft  = logical(LogicalKeyboardKey.arrowLeft);  // 左方向键 (0302)
  static final arrowRight = logical(LogicalKeyboardKey.arrowRight); // 右方向键 (0303)
  static final arrowUp    = logical(LogicalKeyboardKey.arrowUp);    // 上方向键 (0304)

  static final end        = logical(LogicalKeyboardKey.end);        // End键 (0305)
  static final home       = logical(LogicalKeyboardKey.home);       // Home键 (0306)
  static final pageDown   = logical(LogicalKeyboardKey.pageDown);   // 下翻页 (0307)
  static final pageUp     = logical(LogicalKeyboardKey.pageUp);     // 上翻页 (0308)
  static final insert     = logical(LogicalKeyboardKey.insert);     // 插入键 (0407)
  static final paste      = logical(LogicalKeyboardKey.paste);      // 粘贴键 (0408)

  static final pause      = logical(LogicalKeyboardKey.pause);      // 暂停键 (0509)
  static final play       = logical(LogicalKeyboardKey.play);       // 播放键 (050a)

  static final f1         = logical(LogicalKeyboardKey.f1);         // F1键 (0801)
  static final f2         = logical(LogicalKeyboardKey.f2);         // F2键 (0802)
  static final f3         = logical(LogicalKeyboardKey.f3);         // F3键 (0803)
  static final f4         = logical(LogicalKeyboardKey.f4);         // F4键 (0804)
  static final f5         = logical(LogicalKeyboardKey.f5);         // F5键 (0805)
  static final f6         = logical(LogicalKeyboardKey.f6);         // F6键 (0806)
  static final f7         = logical(LogicalKeyboardKey.f7);         // F7键 (0807)
  static final f8         = logical(LogicalKeyboardKey.f8);         // F8键 (0808)
  static final f9         = logical(LogicalKeyboardKey.f9);         // F9键 (0809)
  static final f10        = logical(LogicalKeyboardKey.f10);        // F10键 (080a)
  static final f11        = logical(LogicalKeyboardKey.f11);        // F11键 (080b)
  static final f12        = logical(LogicalKeyboardKey.f12);        // F12键 (080c)

  static final delete     = logical(LogicalKeyboardKey.delete);     // 删除键 (007f)

  // 带修饰键的回车键
  static final altEnter   = RawKeyboardKey(enter.value | _ModifierKeyCode.alt);     // Alt+Enter
  static final ctrlEnter  = RawKeyboardKey(enter.value | _ModifierKeyCode.ctrl);    // Ctrl+Enter
  static final shiftEnter = RawKeyboardKey(enter.value | _ModifierKeyCode.shift);   // Shift+Enter
  static final metaEnter  = RawKeyboardKey(enter.value | _ModifierKeyCode.meta);    // Meta+Enter (Apple Command+Enter)

}

/// 修饰键编码常量接口
abstract interface class _ModifierKeyCode {

  static const int shift = 0x10000000; // Shift键掩码
  static const int ctrl  = 0x01000000; // Ctrl键掩码
  static const int alt   = 0x00100000; // Alt键掩码

  // Apple系统 - Command键掩码
  static const int meta  = 0x00010000;

}


/// 键盘事件检查器 - 单例模式，处理键盘事件并识别按键（含修饰键）
class RawKeyboardChecker {
  // 单例实现：工厂构造函数 + 私有静态实例 + 私有构造函数
  factory RawKeyboardChecker() => _instance;
  static final RawKeyboardChecker _instance = RawKeyboardChecker._internal();
  RawKeyboardChecker._internal();

  // 修饰键状态
  bool _shift = false; // Shift键是否按下
  bool _ctrl = false;  // Ctrl键是否按下
  bool _alt = false;   // Alt键是否按下
  bool _meta = false;  // Meta键（Apple Command）是否按下

  /// 检查键盘事件，返回带修饰键信息的RawKeyboardKey
  /// [event] 键盘事件
  /// 返回：RawKeyboardKey（修饰键事件返回null）
  RawKeyboardKey? checkKeyEvent(KeyEvent event) {
    LogicalKeyboardKey key = event.logicalKey;
    //
    //  检查修饰键状态
    //
    if (//key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight) {
      // Shift键按下/释放
      _shift = event is! KeyUpEvent;
      return null;
    }
    if (//key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight) {
      // Ctrl键按下/释放
      _ctrl = event is! KeyUpEvent;
      return null;
    }
    if (//key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight) {
      // Alt键按下/释放
      _alt = event is! KeyUpEvent;
      return null;
    }
    if (//key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight) {
      // Meta键（Apple Command）按下/释放
      _meta = event is! KeyUpEvent;
      return null;
    }
    if (event is! KeyDownEvent) {
      // 仅处理按键按下事件，释放事件忽略
      return null;
    }
    //
    //  检查回车键（含修饰键）
    //
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      // 根据修饰键状态返回对应的回车键常量
      return _shift ? RawKeyboardKey.shiftEnter
          : _ctrl ? RawKeyboardKey.ctrlEnter
          : _alt ? RawKeyboardKey.altEnter
          : _meta ? RawKeyboardKey.metaEnter
          : RawKeyboardKey.enter;
    }
    //
    //  其他按键（添加修饰键信息）
    //
    // 提取基础按键值（低16位）
    int value = key.keyId & 0x0000ffff;
    // 添加修饰键掩码
    if (_shift) {
      value |= _ModifierKeyCode.shift;
    }
    if (_ctrl) {
      value |= _ModifierKeyCode.ctrl;
    }
    if (_alt) {
      value |= _ModifierKeyCode.alt;
    }
    if (_meta) {
      value |= _ModifierKeyCode.meta;
    }
    // 返回带修饰键信息的RawKeyboardKey
    return RawKeyboardKey(value);
  }

}