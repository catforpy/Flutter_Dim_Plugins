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

import 'package:dim_client/sdk.dart';    // DIM-SDK核心库
import 'package:dim_client/common.dart'; // DIM-SDK通用接口
import 'package:dim_client/client.dart'; // DIM-SDK客户端核心
import 'package:dim_client/cpu.dart';    // DIM-SDK内容处理器

import '../shared.dart'; // 全局变量

/// 客户端握手命令处理器：继承HandshakeCommandProcessor，增强握手校验逻辑
/// 核心功能：
/// 1. 过滤测试/问候类握手命令
/// 2. 处理重复握手/密钥变更场景
/// 3. 后台模式忽略握手
class ClientHandshakeProcessor extends HandshakeCommandProcessor{
  /// 构造方法：初始化处理器
  ClientHandshakeProcessor(super.facebook, super.messenger);

  // ===================== 测试/问候握手常量 =====================
  static const String kTestSpeed = 'Nice to meet you!';       // 测速握手标题
  static const String kTestSpeedRespond = 'Nice to meet you too!'; // 测速响应标题

  /// 创建测速握手命令
  static HandshakeCommand createTestSpeedCommand() =>
      BaseHandshakeCommand.from(kTestSpeed);

  // ===================== 私有方法：过滤问候/测试握手 =====================
  /// 检查是否为问候/测试类握手命令（无需处理）
  /// 返回：true=忽略，false=需要处理
  bool checkGreetingHandshake(HandshakeCommand content){
    String title = content.title;
    // 1.测速相应：忽略
    if(title == kTestSpeedRespond){
      logWarning('ignore test speed respond: $content');
      return true;
    }
    // 2.测速请求：标记错误（客户端不应收到这个命令）
    else if(title == kTestSpeed){
      logError('unexpected test speed command: $content');
      // TODO: 后续可添加回复逻辑
      return true;
    }
    return false;
  }

  // ===================== 私有方法：过滤重复/错误握手 =====================
  /// 握手状态说明：
  /// - C->S：客户端发起握手（无会话密钥/密钥过期）
  /// - S->C：服务器要求重握手（下发新密钥）
  /// - C->S：客户端用新密钥重发起握手
  /// - S->C：服务器确认握手成功
  /// 
  /// 检查是否为重复/错误握手命令（需要忽略）
  /// 返回：true=忽略，false=需要处理
  bool ignoredHandshake(HandshakeCommand content){
    String title = content.title;

    // 1.服务器确认握手成功（DIM!）：必须处理，不能忽略
    if(title == "DIM!"){
      return false;
    }
    // 2. 非DIM?的握手命令：断言错误（客户端不应收到），忽略
    else if(title != "DIM?"){
      assert(false, 'handshake command error: $content');
      return true;
    }

    // 3. 服务器要求重握手（DIM?）：校验密钥合法性
    String? newKey = content.sessionKey;
    // 秘钥为空/空字符串：错误命令，忽略
    if(newKey == null || newKey.isEmpty){
      logError('handshake command error: $content');
      return true;
    }

    // 4. 校验会话状态
    ClientSession? session = messenger?.session;
    // 会话未就绪：需要处理重握手
    if (session == null || !session.isReady) {
      logInfo('session not ready, handshake again: $content, ${session?.remoteAddress}');
      return false;
    }

    // 5. 校验新旧密钥
    String? oldKey = session.sessionKey;
    // 首次握手（无旧密钥）：需要处理
    if (oldKey == null) {
      logInfo('first handshake: ${session.remoteAddress}');
      return false;
    }
    // 密钥变更：需要处理
    else if (newKey != oldKey) {
      logWarning('session key changed: $oldKey -> $newKey');
      return false;
    }

    // 6. 重复握手判断（5秒内重复则忽略）
    logWarning('duplicated session key: $newKey, ${session.remoteAddress}');
    DateTime? now = DateTime.now();
    DateTime? lastTime = _lastDuplicatedTime;
    
    if (lastTime == null) {
      // 首次重复：允许通过，记录时间
      logInfo('first duplicated, let it go: $newKey');
    } else if (lastTime.add(_delta).isAfter(now)) {
      // 5秒内重复：忽略（FIXME: 需排查重复原因）
      logWarning('ignore duplicated handshake: $session');
      return true;
    }

    // 更新最后重复时间
    _lastDuplicatedTime = now;
    return false;
  }

  DateTime? _lastDuplicatedTime; // 最后一次重复握手时间
  final Duration _delta = const Duration(seconds: 5); // 重复忽略窗口期

  // ===================== 核心处理方法 =====================
  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async {
    // 断言：确保是握手命令（开发期校验）
    assert(content is HandshakeCommand, 'handshake command error: $content');
    HandshakeCommand command = content as HandshakeCommand;
    logInfo('checking handshake command: ${rMsg.sender} -> $command');

    // 1. 过滤问候/测试握手
    if(checkGreetingHandshake(command)){
      logDebug('greeting handshake command processed: $command');
      return [];
    }
    // 2. 过滤重复/错误握手
    else if (ignoredHandshake(command)) {
      logDebug('duplicated / error handshake command: $command');
      return [];
    }

    // 3. 后台模式忽略握手（应用在后台时不处理）
    GlobalVariable shared = GlobalVariable();
    if (shared.isBackground == true) {
      logWarning('App Lifecycle: ignore handshake in background mode: $content');
      return [];
    }

    // 4. 交给父类处理核心握手逻辑
    return await super.processContent(content, rMsg);
  }
}