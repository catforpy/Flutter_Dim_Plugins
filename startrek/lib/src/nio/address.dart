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


/// 套接字地址抽象接口（无协议绑定）
/// 作为抽象类，需由具体协议（如IP）实现子类
abstract interface class SocketAddress {}

/// IP套接字地址（IP地址 + 端口号）
/// 支持主机名+端口号形式（会尝试解析主机名），解析失败则标记为“未解析”，但仍可用于代理连接等场景
/// 提供不可变对象，用于套接字的绑定、连接或作为返回值
/// 通配符是特殊的本地IP地址，通常表示“任意地址”，仅用于bind操作
class InetSocketAddress implements SocketAddress {
  /// 构造函数：主机名/IP + 端口号
  InetSocketAddress(this.host, this.port);

  /// 主机名/IP地址
  final String host;

  /// 端口号
  final int port;

  /// 重写相等判断：端口+主机名均相同则相等
  @override
  bool operator ==(Object other) {
    if (other is InetSocketAddress) {
      if (identical(this, other)) {
        // 同一个对象 直接返回true
        return true;
      }
      return other.port == port && other.host == host;
    } else {
      return false;
    }
  }

  /// 重写哈希值：端口*13 + 主机名哈希（减少哈希冲突）
  @override
  int get hashCode => 13 * port + host.hashCode;

  /// 重写字符串格式：("主机名", 端口)
  @override
  String toString() => '("$host", $port)';

  /// 解析字符串为InetSocketAddress
  /// 支持格式："host:port" / "(host, port)" / "host,port" 等，自动清理特殊字符
  static InetSocketAddress? parse(String string) {
    // 清理字符串中的特殊字符：单引号、双引号、空格、斜杠、括号
    string = string.replaceAll("'", '');
    string = string.replaceAll('"', '');
    string = string.replaceAll(' ', '');
    string = string.replaceAll('/', '');
    string = string.replaceAll('(', '');
    string = string.replaceAll(')', '');
    // 按逗号分割（优先），分割失败则按冒号分割
    List<String> pair = string.split(',');
    if (pair.length == 1) {
      pair = string.split(':');
    }
    // 分割出主机和端口，端口需为正数
    if (pair.length == 2) {
      int port = int.parse(pair.last);
      if (port > 0) {
        return InetSocketAddress(pair.first, port);
      }
    }
    return null;
  }
}
