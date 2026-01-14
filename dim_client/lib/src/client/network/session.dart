/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2025 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2025 Albert Moky
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

import 'dart:typed_data'; // 字节数组（网络数据传输）

import 'package:dimsdk/dimsdk.dart'; // DIM核心协议库
import 'package:lnc/log.dart'; // 日志工具
import 'package:stargate/stargate.dart'; // 网关/连接核心库
import 'package:stargate/startrek.dart'; // 星际迷航（网络传输层）

import '../../common/dbi/session.dart'; // 会话数据库接口
import '../../network/session.dart'; // 基础会话类
import 'state.dart'; // 会话状态机相关

/// 客户端会话类（核心）
/// 核心功能：
/// 1. 管理客户端与服务器的连接会话（生命周期、状态流转）；
/// 2. 维护会话密钥（session key）、用户ID、连接状态等核心属性；
/// 3. 处理网络数据的接收/分发，状态机的启停/暂停/恢复；
/// 设计思路：基于状态机模式，实现会话的自动化生命周期管理；
/// 关键属性说明：
/// - key: 会话密钥（服务器生成，握手成功后设置）
/// - did: 本地用户ID（连接前设置，为空时会话状态为Default）
/// - active: 会话状态（连接成功为true，断开为false）
/// - station: 远程服务器信息（IP/端口/ID）
class ClientSession extends BaseSession with Logging {
  /// 构造方法
  /// [database] - 会话数据库（持久化会话信息）
  /// [_server] - 远程服务器实例（Station）
  ClientSession(SessionDBI database, this._server)
    : super(database, remote: InetSocketAddress(_server.host!, _server.port)) {
    // 初始化会话状态机（核心：管理会话状态流转）
    _fsm = SessionStateMachine(this);
  }

  /// 远程服务器实例（包含IP、端口、ID等信息）
  final Station _server;

  /// 会话状态机（核心：驱动会话状态流转）
  late final SessionStateMachine _fsm;

  /// 会话密钥（服务器生成，握手成功后赋值）
  String? _key;

  /// 握手是否被接受（标识登录状态）
  bool _accepted = false;

  /// 获取远程服务器实例
  Station get station => _server;

  /// 获取当前会话状态（如Default/Connecting/Running等）
  SessionState? get state => _fsm.currentState ?? _fsm.defaultState;

  /// 设置会话激活状态（重写父类方法）
  /// [flag] - 是否激活（true=连接成功，false=连接断开）
  /// [when] - 状态变更时间
  @override
  bool setActive(bool flag, DateTime? when) {
    if (flag == false) {
      // 连接断开时，重置握手接受状态
      _accepted = false;
    }
    return super.setActive(flag, when);
  }

  /// 获取会话密钥（重写父类方法）
  @override
  String? get sessionKey => _key;

  /// 设置会话密钥（握手成功后调用）
  set sessionKey(String? key) => _key = key;

  /// 获取握手接受状态
  bool get isAccepted => _accepted;

  /// 设置握手接受状态
  set accepted(bool flag) => _accepted = flag;

  /// 检查会话是否就绪（可发送消息）
  /// 就绪条件：激活状态 + 握手接受 + 用户ID存在 + 会话密钥存在
  bool get isReady {
    // 基础检查：激活、握手接受、用户ID存在
    if (isActive && isAccepted && identifier != null) {
      // 握手成功，进入下一步检查
    } else {
      // 未激活/握手未完成/未登录 → 未就绪
      return false;
    }
    // 检查会话密钥是否存在
    bool ok = sessionKey != null;
    if (!ok) {
      // 会话密钥丢失 → 恢复状态机（重新握手）
      /*await */
      _fsm.resume();
    }
    return ok;
  }

  /// 获取当前网络连接实例
  Connection? get connection {
    // 从网关获取对应远程地址的Porter（搬运工）
    Porter? docker = gate.getPorter(remote: remoteAddress);
    if (docker is StarPorter) {
      // StarPorter是基于TCP的搬运工，包含Connection实例
      return docker.connection;
    }
    // 断言：非StarPorter则必须为null（防止未知类型）
    assert(docker == null, 'unknown docker: $docker');
    return null;
  }

  /// 获取连接状态机（管理网络连接的状态流转）
  ConnectionStateMachine? get connectionStateMachine {
    Connection? conn = connection;
    if (conn is BaseConnection) {
      // BaseConnection包含状态机实例
      return conn.stateMachine;
    }
    // 断言：非BaseConnection则必须为null
    assert(conn == null, 'unknown connection: $conn');
    return null;
  }

  /// 暂停状态机（会话暂停时调用）
  Future<void> pause() async {
    // 先暂停会话状态机，在暂停连接状态机
    await _fsm.pause();
    await connectionStateMachine?.pause();
  }

  /// 恢复状态机（会话恢复时调用）
  Future<void> resume() async {
    // 先恢复连接状态机，再恢复会话状态机
    await connectionStateMachine?.resume();
    await _fsm.resume();
  }

  /// 启动会话（后台线程）
  /// [delegate] - 状态机代理（接收状态变更回调）
  Future<void> start(SessionStateDelegate delegate) async {
    // 先停止已有会话
    await stop();
    // 启动后台线程（运行会话）
    /*await */
    run();
    // 设置状态机代理，启动状态机
    _fsm.delegate = delegate;
    await _fsm.start();
  }

  /// 停止会话（重写父类方法）
  /// 核心：停止状态机 + 停止后台线程
  @override
  Future<void> stop() async {
    await super.stop();
    // 停止会话状态机
    await _fsm.stop();
    // 等待后台线程停止
  }

  /// 会话初始化（重写父类方法）
  @override
  Future<void> setup() async {
    await super.setup();
    // 初始化时设置为激活状态
    setActive(true, null);
  }

  /// 会话结束（重写父类方法）
  @override
  Future<void> finish() async {
    // 结束时设置为非激活状态
    setActive(false, null);
    await super.finish();
  }

  //
  //  Docker Delegate（搬运工代理：处理网络事件）
  //

  /// 搬运工状态变更回调（连接状态变更）
  /// [previous] - 旧状态
  /// [current] - 新状态
  /// [porter] - 搬运工实例
  @override
  Future<void> onPorterStatusChanged(
    PorterStatus previous,
    PorterStatus current,
    Porter porter,
  ) async {
    if (current == PorterStatus.error) {
      // 连接错误/会话结束 -> 标记为非激活
      setActive(false, null);
      // TODO:清空会话ID，更新握手
    } else if (current == PorterStatus.ready) {
      // 连接成功/重连成功 -> 标记为激活
      setActive(true, null);
    }
  }

  /// 接收网络数据回调（核心：处理服务器下发的数据包）
  /// [ship] - 数据包载体（包含原始字节数据）
  /// [porter] - 搬运工实例
  @override
  Future<void> onPorterReceived(Arrival ship, Porter porter) async {
    // 存储所有相应数据（需要回发给服务器）
    List<Uint8List> allResponses = [];
    // 1. 从数据包中提取数据列表（支持JSON行分割）
    List<Uint8List> packages = _getDataPackages(ship);
    List<Uint8List> responses;
    // 2.遍历处理每个数据包
    for (Uint8List pack in packages) {
      try {
        // 处理数据包（交给messenger解析/处理）
        responses = await messenger!.processPackage(pack);
        if (responses.isEmpty) {
          continue;
        }
        // 收集所有相应数据
        for (Uint8List res in responses) {
          if (res.isEmpty) {
            // 空相应跳过（理论上不会出现）
            continue;
          }
          allResponses.add(res);
        }
      } catch (e, st) {
        // 处理数据包异常 -> 记录日志
        logError('failed to process package: ${pack.length} bytes, error: $e');
        logDebug(
          'failed to process package: ${pack.length} bytes, error: $e, $st',
        );
      }
    }
    // 3.准备回发相应数据
    SocketAddress source = porter.remoteAddress!; //服务器地址（目标）
    SocketAddress? destination = porter.remoteAddress; //本地地址（源）
    // 4.逐个发送相应数据
    for (Uint8List res in allResponses) {
      await gate.sendResponse(res, ship, remote: source, local: destination);
    }
  }
}

/// 从数据包载体中提取数据列表
/// 核心逻辑：
/// - 空数据 → 返回空列表
/// - JSON格式（以{开头）→ 按行分割
/// - 其他格式 → 直接返回原始数据
List<Uint8List> _getDataPackages(Arrival ship) {
  Uint8List payload = (ship as PlainArrival).payload;
  // 检查负载数据
  if (payload.isEmpty) {
    // 空数据 → 返回空列表
    return [];
  } else if (payload[0] == _jsonBegin) {
    // JSON格式（以{开头）→ 按行分割
    return _splitLines(payload);
  } else {
    // 其他格式 → 直接返回
    return [payload];
  }
}

/// 常量：JSON起始字符（{）的ASCII码
final int _jsonBegin = '{'.codeUnitAt(0);

/// 常量：换行符（\n）的ASCII码
final int _lineFeed = '\n'.codeUnitAt(0);

/// 按换行符分割字节数组（处理JSON行格式数据）
List<Uint8List> _splitLines(Uint8List payload) {
  // 查找第一个换行符位置
  int end = payload.indexOf(_lineFeed);
  if (end < 0) {
    // 无换行符 → 返回原始数据
    return [payload];
  }
  int start = 0;
  List<Uint8List> lines = [];
  // 循环分割每行数据
  while (end > 0) {
    if (end > start) {
      // 提取一行数据（start到end）
      lines.add(payload.sublist(start, end));
    }
    // 移动指针到下一行开头
    start = end + 1;
    end = payload.indexOf(_lineFeed, start);
  }
  // 处理最后一行（无换行符结尾）
  if (start < payload.length) {
    lines.add(payload.sublist(start));
  }
  return lines;
}
