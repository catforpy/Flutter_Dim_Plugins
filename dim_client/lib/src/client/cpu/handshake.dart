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

import 'package:dimsdk/dimsdk.dart';    // DIM核心协议库（消息/命令模型）
import 'package:lnc/log.dart';          // 日志工具（打印日志）

import '../../common/protocol/handshake.dart'; // 握手命令协议模型（HandshakeCommand）

import '../network/session.dart';       // 客户端会话（管理连接状态/服务器信息）
import '../messenger.dart';             // 客户端Messenger（扩展基础Messenger）

/// 握手命令处理器
/// 核心功能：
/// 1. 处理客户端与服务器之间的握手命令（DIM?/DIM!）；
/// 2. 维护服务器ID的更新和校验（确保连接的是正确服务器）；
/// 3. 管理会话密钥（session key），处理重连/密钥更新场景；
/// 4. 控制客户端连接状态（握手成功/失败/重连）；
/// 应用场景：客户端与服务器建立连接、断线重连、密钥更新
class HandshakeCommandProcessor extends BaseCommandProcessor with Logging{
  /// 构造方法
  /// [facebook] - 基础Facebook实例
  /// [messenger] - 基础Messenger实例
  HandshakeCommandProcessor(super.facebook, super.messenger);

  /// 类型转换：将基类Messenger转为客户端专属的ClientMessenger
  /// 目的：获取客户端Messenger的扩展能力（如session管理）
  @override
  ClientMessenger? get messenger => super.messenger as ClientMessenger?;

  /// 处理握手命令的核心方法
  /// 核心流程：更新服务器ID → 解析握手标题 → 处理会话密钥 → 维护连接状态
  /// [content] - 握手命令内容
  /// [rMsg] - 可靠消息（服务器发送的握手响应）
  /// 返回值：空列表（无需回复握手命令）
  @override
  Future<List<Content>> processContent(Content content,ReliableMessage rMsg) async {
    // 断言：确保传入的内容是HandshakeCommand类型（开发阶段校验）
    assert(content is HandshakeCommand, 'handshake command error: $content');
    HandshakeCommand command = content as HandshakeCommand;
    // 获取客户端会话实例（核心依赖：管理连接状态/服务器信息/会话秘钥）
    ClientSession session = messenger!.session;

    // ========== 步骤1：更新服务器ID（确保连接的是正确服务器） ==========
    // 获取服务器实例（station：存储服务器地址/ID/端口等信息）
    Station station = session.station;
    // 获取服务器旧ID（首次连接时默认是广播ID：station@anywhere）
    ID oid = station.identifier;
    // 获取消息发送者ID（服务器的真实ID）
    ID sender = rMsg.sender;
    if(oid.isBroadcast){
      // 首次握手 -> 将服务器ID更新为真实ID（替换广播ID）
      station.identifier = sender;
      logInfo('update station ID: $oid => $sender');
    }else{
      // 非首次握手 → 校验服务器ID是否一致（防止连接到错误服务器）
      assert(oid == sender, 'station ID not match: $oid, $sender');
    }

    // ========== 步骤2：解析握手标题和会话密钥 ==========
    String title = command.title;       // 握手标题（DIM?/DIM!/其他，标识握手状态）
    String? newKey = command.sessionKey;// 服务器下发的新会话密钥
    String? oldKey = session.sessionKey;// 本地存储的旧会话密钥
    // 断言：新会话密钥不能为空（服务器必须下发有效密钥）
    assert(newKey != null, "new session key should not be empty: $command");

    // ========== 步骤3：根据握手标题处理不同场景 ==========
    if(title == 'DIM?'){
      // 情况1：服务器发送 DIM? -> 要求客户端重新握手
      if(oldKey == null){
        // 首次握手（本地无密钥）→ 使用新密钥重新发起握手
        logInfo('[DIM] handshake with session key: $newKey');
        await messenger?.handshake(newKey);
      }else if(oldKey == newKey){
        // 重复的握手响应（密钥相同）→ 重新握手（处理断线重连场景）
        logWarning('[DIM] handshake response duplicated: $newKey');
        await messenger?.handshake(newKey);
      }else{
        // 链接变更（秘钥不同）-> 清空就秘钥，重新握手
        logWarning('[DIM] handshake again: $oldKey => $newKey');
        session.sessionKey = null;
      }
    }else if(title == 'DIM!'){
      // 情况2：服务器发送 DIM! -> 握手成功,更新会话密钥，客户端进入运行状态
      if(oldKey == null){
        // 首次握手成功 → 更新会话密钥，客户端进入运行状态
        logInfo('[DIM] handshake success with session key: $newKey');
        session.sessionKey = newKey;
      }else if(oldKey == newKey){
        // 重复的握手成功响应 → 重新设置密钥（触发连接状态更新）
        logWarning('[DIM] handshake success duplicated: $newKey');
        session.sessionKey = newKey;
      }else{
        // 握手错误（密钥不匹配）→ 清空旧密钥，重新握手
        logError('[DIM] handshake again: $oldKey, $newKey');
        session.sessionKey = null;
      }
    }else{
      // 情况3：其他标题 → 非服务器发送的握手命令，忽略
      logWarning('Handshake from other user? $sender: $content');
    }
    // 无需回复握手命令（握手结果通过连接状态更新通知前端，而非回复消息）
    return [];
  }
}