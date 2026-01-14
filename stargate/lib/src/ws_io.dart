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

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// IO端WebSocket连接器（适配Dart IO的WebSocket API）
class WebSocketConnector {
  /// 构造方法
  WebSocketConnector(this.url);

  /// WebSocket状态常量（对应IO端API）
  static const int connecting = WebSocket.connecting;
  static const int open       = WebSocket.open;
  static const int closing    = WebSocket.closing;
  static const int closed     = WebSocket.closed;

  /// WebSocket连接地址
  final Uri url;
  /// WebSocket实例
  WebSocket? _ws;

  /// 获取WebSocket实例
  WebSocket? get socket => _ws;
  /// 设置WebSocket实例（关闭旧实例）
  // protected
  Future<void> setSocket(WebSocket? ws) async {
    // 1. 替换新实例
    WebSocket? old = _ws;
    if (ws != null) {
      _ws = ws;
    }
    // 2. 关闭旧实例
    if (old == null || identical(old, ws)) {} else {
      await old.close();
    }
  }

  /// 判断是否已关闭
  bool get isClosed {
    WebSocket? ws = _ws;
    if (ws == null) {
      // 未初始化 → 返回false
      return false;
    }
    // 检查状态+关闭码
    return ws.readyState == closed || ws.closeCode != null;
  }

  /// 判断是否已连接
  bool get isConnected {
    WebSocket? ws = _ws;
    if (ws == null) {
      // 未初始化 → 返回false
      return false;
    }
    // 检查状态+关闭码
    return ws.readyState == open && ws.closeCode == null;
  }

  /// 获取类名（用于日志）
  String get className => 'WebSocketConnector';

  /// 重写toString（打印连接信息）
  @override
  String toString() {
    String clazz = className;
    return '<$clazz url="$url" state=${_ws?.readyState} />';
  }

  /// 连接WebSocket（带超时）
  /// [timeout] - 超时时间（毫秒）
  Future<bool> connect([int timeout = 8000]) async {
    // 创建WebSocket实例（IO端异步连接）
    var ws = await WebSocket.connect(url.toString());
    // 等待连接成功（超时检测）
    if (await _checkState(timeout, () => ws.readyState == open)) {
      // 连接成功 → 设置实例，返回true
      await setSocket(ws);
      return true;
    } else {
      // 连接失败 → 断言错误，返回false
      assert(false, 'failed to connect: $url');
      return false;
    }
  }

  /// 监听数据接收
  /// [onData] - 数据回调
  void listen(void Function(Uint8List data) onData) => socket?.listen((msg) {
    // 处理消息数据（字符串/字节数组）
    if (msg is String) {
      // 字符串 → 转UTF8字节数组
      msg = Uint8List.fromList(utf8.encode(msg));
    } else {
      // 断言：必须是字节数组
      assert(msg is Uint8List, 'msg error');
    }
    // 回调数据
    onData(msg);
  }, onDone: () {
    // 连接关闭 → 打印日志并关闭连接器
    print('[WS] socket closed: $url');
    close();
  });

  /// 写入数据
  Future<int> write(Uint8List src) async {
    WebSocket? ws = socket;
    if (ws == null || !isConnected) {
      // 未连接 → 断言错误，返回-1
      assert(false, 'WebSocket closed: $url');
      return -1;
    }
    // 发送数据（IO端用add方法）
    ws.add(src);
    // 返回发送长度
    return src.length;
  }

  /// 关闭连接
  Future<bool> close([int timeout = 8000]) async {
    var ws = _ws;
    if (ws == null) {
      // 无实例 → 断言错误，返回false
      assert(false, 'WebSocket not exists: $url');
      return false;
    } else {
      // 清空实例
      await setSocket(null);
    }
    // 等待连接关闭（超时检测）
    return await _checkState(timeout, () => ws.readyState == closed);
  }
}

/// 状态检查（带超时）
/// [timeout] - 超时时间（毫秒）
/// [condition] - 状态判断函数
Future<bool> _checkState(int timeout, bool Function() condition) async {
  if (timeout <= 0) {
    // 非阻塞 → 返回true
    return true;
  }
  // 计算过期时间
  DateTime expired = DateTime.now().add(Duration(milliseconds: timeout));
  // 循环检查状态
  while (!condition()) {
    // 未满足条件 → 休眠128毫秒
    await Future.delayed(Duration(milliseconds: 128));
    if (DateTime.now().isAfter(expired)) {
      // 超时 → 返回false
      return false;
    }
  }
  // 满足条件 → 返回true
  return true;
}