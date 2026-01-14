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

import 'package:dim_client/plugins.dart';

/// 握手状态枚举类
/// 定义握手过程中的不同状态
class HandshakeState {

  /// 初始状态：客户端→服务器，无会话密钥（或会话过期）
  static const int START   = 0;
  /// 再次握手：服务器→客户端，携带新会话密钥
  static const int AGAIN   = 1;
  /// 重新开始：客户端→服务器，携带新会话密钥
  static const int RESTART = 2;
  /// 握手成功：服务器→客户端，确认握手完成
  static const int SUCCESS = 3;

  /// 检查握手状态
  /// [title] 握手标题（"DIM?"/"DIM!"/"Hello world!"等）
  /// [session] 会话密钥
  /// 返回：对应的握手状态码
  static int checkState(String title, String? session){
    if(title == 'DIM!'/* || title == 'OK!'*/){
      return SUCCESS;             // 标题为DIM!表示成功
    }else if(title == 'DIM?'){
      return AGAIN;               // 标题为DIM?表示需要再次握手
    }else if(session == null){
      return START;               // 无会话密钥表示初始状态
    }else{
      return RESTART;             // 有会话密钥表示重新开始
    }
  }
}

/// 握手命令接口
/// 用于客户端与服务器之间的会话握手
/// 数据结构规范：
/// {
///     type : 0x88,             // 命令类型
///     sn   : 123,              // 序列号
///     command : "handshake",   // 命令名称
///     title   : "Hello world!",// 握手标题（"DIM?", "DIM!"等）
///     session : "{SESSION_KEY}"// 会话密钥
/// }
abstract interface class HandshakeCommand implements Command{
  static const String HANDSHAKE = 'handshake';  // 命令名称常量

  /// 获取握手标题
  String get title;
  /// 获取会话密钥
  String? get sessionKey;

  /// 获取当前握手状态（通过title和sessionKey计算）
  int get state;

  //
  //  工厂方法
  //

  /// 创建初始握手命令（START状态）
  /// 返回：无会话密钥的握手命令
  static HandshakeCommand start() =>
      BaseHandshakeCommand.from('Hello world!');

  /// 创建重新开始握手命令（RESTART状态）
  /// [session] 新会话密钥
  /// 返回：携带会话密钥的握手命令
  static HandshakeCommand restart(String session) =>
      BaseHandshakeCommand.from('Hello world!', sessionKey: session);

  /// 创建再次握手命令（AGAIN状态）
  /// [session] 新会话密钥
  /// 返回：标题为DIM?的握手命令
  static HandshakeCommand again(String session) =>
      BaseHandshakeCommand.from('DIM?', sessionKey: session);

  /// 创建握手成功命令（SUCCESS状态）
  /// [session] 会话密钥（可选）
  /// 返回：标题为DIM!的握手命令
  static HandshakeCommand success(String? session) =>
      BaseHandshakeCommand.from('DIM!', sessionKey: session);
}

/// 握手命令实现类
/// 继承BaseCommand，实现HandshakeCommand接口
class BaseHandshakeCommand extends BaseCommand implements HandshakeCommand {
  /// 从字典初始化握手命令
  /// [dict] 包含握手命令字段的字典
  BaseHandshakeCommand(super.dict);

  /// 构造方法：创建握手命令
  /// [title] 握手标题
  /// [sessionKey] 会话密钥（可选）
  BaseHandshakeCommand.from(String title, {String? sessionKey})
    : super.fromName(HandshakeCommand.HANDSHAKE){
    // 设置标题字段
    this['title'] = title;
    // 设置会话秘钥字段（可选）
    if(sessionKey != null){
      this['session'] = sessionKey;
    }
  }

  /// 实现sessionKey获取逻辑：从字典中获取会话密钥
  @override
  String? get sessionKey => getString('session');

  /// 实现state获取逻辑：调用HandshakeState检查状态
  @override
  int get state => HandshakeState.checkState(title, sessionKey);

  /// 实现title获取逻辑：从字典中获取标题字符串
  @override
  String get title => getString('title') ?? '';
  
  

}