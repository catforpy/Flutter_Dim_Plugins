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

import 'package:startrek/nio.dart';

/// 地址对对象基类
/// 核心：封装「远程地址+本地地址」的配对，实现相等性判断、哈希值计算、标准化toString
/// 所有带地址对的核心类（如BaseConnection、BaseChannel）都继承此类
class AddressPairObject {
  /// 构造函数：初始化远程/本地地址
  AddressPairObject({SocketAddress? remote, SocketAddress? local})
    : remoteAddress = remote,
      localAddress = local;

  /// 远程地址（对端地址，如TCP连接的服务器地址、UDP发送的目标地址）
  SocketAddress? remoteAddress;

  /// 本地地址（绑定的本地地址，如本地网卡IP+端口）
  SocketAddress? localAddress;

  /// 重写相等性判断：仅当remote+local都相等时，两个对象才相等
  @override
  bool operator ==(Object other) {
    if (other is AddressPairObject) {
      if (identical(this, other)) {
        // 同一对象 → 直接相等
        return true;
      }
      // 不同对象 → 比较remote+local地址
      return other.remoteAddress == remoteAddress &&
          other.localAddress == localAddress;
    } else {
      // 非AddressPairObject → 不相等
      return false;
    }
  }

  /// 重写哈希值：组合remote+local的哈希，避免哈希冲突
  @override
  int get hashCode {
    // 算法说明：
    // 1. remote哈希 × 质数13 → 避免「remote=A, local=B」和「remote=B, local=A」哈希相同
    // 2. 空地址哈希为0 → 兼容null场景
    int? remote = remoteAddress?.hashCode;
    int? local = localAddress?.hashCode;
    return (remote ?? 0) * 13 + (local ?? 0);
  }

  /// 重写toString：标准化输出类名+地址对，便于调试
  @override
  String toString() {
    String clazz = className;
    return '<$clazz remote="$remoteAddress" local="$localAddress" />';
  }

  /// 获取类名（调试用，默认返回AddressPairObject，子类会被_runtimeType覆盖）
  String get className => _runtimeType(this, 'AddressPairObject');
}

/// 调试辅助函数：断言模式下返回对象实际运行时类型，否则返回默认类名
/// 作用：release模式下减少反射开销，debug模式下显示真实子类名
String _runtimeType(Object object, String className) {
  assert(() {
    className = object.runtimeType.toString();
    return true;
  }());
  return className;
}
