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

import 'dart:convert';    // 字符编码转换（utf8）
import 'dart:html';       // Web平台API（WebSocket）
import 'dart:typed_data';  // 字节数组（Uint8List）


/// WebSocket连接器（仅适配Dart Web环境）
/// 作用：封装WebSocket的连接、数据收发、状态管理、连接关闭等核心逻辑
class WebSocketConnector {
  /// 构造方法
  /// [url]：WebSocket连接地址（ws://或wss://）
  WebSocketConnector(this.url);

  /// WebSocket连接状态常量（映射dart:html的WebSocket状态）
  static const int connecting = WebSocket.CONNECTING;  // 连接中
  static const int open       = WebSocket.OPEN;        // 已连接
  static const int closing    = WebSocket.CLOSING;      // 关闭中
  static const int closed     = WebSocket.CLOSED;       // 已关闭

  /// WebSocket连接地址（不可变）
  final Uri url;
  /// 内部持有的WebSocket实例（核心通信对象）
  WebSocket? _ws;

  /// 对外暴露：获取当前WebSocket实例（只读）
  WebSocket? get socket => _ws;

  /// 【受保护方法】设置新的WebSocket实例（自动关闭旧实例）
  /// [ws]：新的WebSocket实例（null表示清空）
  Future<void> setSocket(WebSocket? ws) async {
    // 1. 保存旧实例，替换为新实例
    WebSocket? old = _ws;
    if (ws != null) {
      _ws = ws;
    }
    // 2. 关闭旧实例（避免连接泄漏）
    if (old == null || identical(old, ws)) {
      // 旧实例为空 或 新旧实例是同一个，无需处理
    } else {
      old.close();
    }
  }

  /// 判断连接是否已关闭
  bool get isClosed {
    WebSocket? ws = _ws;
    if (ws == null) {
      // 初始状态（还未创建WebSocket），返回false
      return false;
    }
    // 检查WebSocket的就绪状态是否为已关闭
    return ws.readyState == closed;
  }

  /// 判断连接是否已建立（处于打开状态）
  bool get isConnected {
    WebSocket? ws = _ws;
    if (ws == null) {
      // 初始状态（还未创建WebSocket），返回false
      return false;
    }
    // 检查WebSocket的就绪状态是否为已打开
    return ws.readyState == open;
  }

  /// 获取类名（便于日志/toString输出）
  String get className => 'WebSocketConnector';

  /// 重写toString：格式化输出连接器信息（便于调试）
  @override
  String toString() {
    String clazz = className;
    return '<$clazz url="$url" state=${_ws?.readyState} />';
  }

  /// 建立WebSocket连接（带超时检查）
  /// [timeout]：超时时间（毫秒，默认8000ms）
  /// 返回：是否连接成功
  Future<bool> connect([int timeout = 8000]) async {
    // 1. 创建新的WebSocket实例（开始连接）
    var ws = WebSocket(url.toString());
    // 2. 等待连接状态变为OPEN（带超时）
    if (await _checkState(timeout, () => ws.readyState == open)) {
      // 3. 连接成功：设置当前WebSocket实例
      await setSocket(ws);
      return true;
    } else {
      // 4. 连接超时/失败：断言提示（开发期）
      assert(false, 'failed to connect: $url');
      return false;
    }
  }

  /// 监听WebSocket的消息接收事件
  /// [onData]：收到数据后的回调（参数为Uint8List字节数组）
  void listen(void Function(Uint8List data) onData) => socket?.onMessage.listen((ev) {
    // 1. 获取消息数据（可能是String或Uint8List）
    var msg = ev.data;
    if (msg is String) {
      // 2. 字符串数据：转换为UTF8编码的字节数组
      msg = Uint8List.fromList(utf8.encode(msg));
    } else {
      // 3. 非字符串：断言必须是Uint8List（确保数据类型正确）
      assert(msg is Uint8List, 'msg error');
    }
    // 4. 回调上层处理数据
    onData(msg);
  }, onDone: () {
    // 5. 连接关闭时的回调：打印日志并关闭连接器
    print('[WS] socket closed: $url');
    close();
  });

  /// 发送字节数据到服务端
  /// [src]：要发送的字节数组
  /// 返回：发送的字节长度（失败返回-1）
  Future<int> write(Uint8List src) async {
    WebSocket? ws = socket;
    if (ws == null || !isConnected) {
      // 连接未建立/已关闭：断言提示（开发期）
      assert(false, 'WebSocket closed: $url');
      return -1;
    }
    // 发送字节数据（WebSocket.send支持Uint8List）
    ws.send(src);
    // 返回发送的字节长度
    return src.length;
  }

  /// 关闭WebSocket连接（带超时检查）
  /// [timeout]：超时时间（毫秒，默认8000ms）
  /// 返回：是否成功关闭
  Future<bool> close([int timeout = 8000]) async {
    var ws = _ws;
    if (ws == null) {
      // 没有WebSocket实例：断言提示（开发期）
      assert(false, 'WebSocket not exists: $url');
      return false;
    } else {
      // 清空当前WebSocket实例（内部会关闭旧实例）
      await setSocket(null);
    }
    // 等待连接状态变为CLOSED（带超时）
    return await _checkState(timeout, () => ws.readyState == closed);
  }

}

/// 通用状态检查工具方法（带超时）
/// [timeout]：超时时间（毫秒）
/// [condition]：状态检查条件（返回bool）
/// 返回：超时前条件是否满足（true=满足，false=超时）
Future<bool> _checkState(int timeout, bool Function() condition) async {
  if (timeout <= 0) {
    // 超时时间≤0：非阻塞模式，直接返回true（不等待）
    return true;
  }
  // 计算超时截止时间
  DateTime expired = DateTime.now().add(Duration(milliseconds: timeout));
  // 循环检查条件
  while (!condition()) {
    // 条件不满足：等待128ms后再次检查
    await Future.delayed(Duration(milliseconds: 128));
    // 检查是否超时
    if (DateTime.now().isAfter(expired)) {
      // 超时：返回false
      return false;
    }
  }
  // 条件满足：返回true
  return true;
}