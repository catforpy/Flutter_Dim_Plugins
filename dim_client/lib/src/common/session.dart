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

import 'dart:typed_data';

import 'package:dimsdk/dimsdk.dart';
import 'package:object_key/object_key.dart';
import 'package:stargate/startrek.dart';

import 'dbi/session.dart';

/// 消息传输器接口
/// 定义消息发送的核心方法，支持不同类型消息的发送
abstract interface class Transmitter {
  /// 发送消息内容（最顶层发送接口）
  /// [content] 消息内容
  /// [sender] 发送方ID（为空则使用当前用户）
  /// [receiver] 接收方ID（必传）
  /// [priority] 发送优先级（数值越小优先级越高）
  /// 返回：即时消息和可靠消息的配对（可靠消息为null表示发送失败）
  Future<Pair<InstantMessage, ReliableMessage?>> sendContent(Content content, {
    required ID? sender, required ID receiver, int priority = 0});

  /// 发送即时消息（明文消息）
  /// [iMsg] 即时消息
  /// [priority] 发送优先级
  /// 返回：可靠消息（失败返回null）
  Future<ReliableMessage?> sendInstantMessage(InstantMessage iMsg, {int priority = 0});

  /// 发送可靠消息（已加密+签名）
  /// [rMsg] 可靠消息
  /// [priority] 发送优先级
  /// 返回：false=发送失败，true=发送成功
  Future<bool> sendReliableMessage(ReliableMessage rMsg, {int priority = 0});
}

/// 会话接口
/// 继承Transmitter，扩展会话管理相关方法，负责消息队列、会话状态管理等
abstract interface class Session implements Transmitter {
  /// 获取会话数据库接口
  SessionDBI get database;

  /// 获取远程Socket地址
  /// 返回：主机+端口信息
  SocketAddress get remoteAddress;

  /// 会话密钥（标识唯一会话）
  String? get sessionKey;

  /// 更新登录用户ID
  /// [identifier] 登录用户ID
  /// 返回：true=ID已变更，false=ID未变更
  bool setIdentifier(ID? user);
  /// 获取当前登录用户ID
  ID? get identifier;

  /// 更新会话活跃状态
  /// [flag] 活跃标记
  /// [when] 时间戳（UTC时间，从1970-01-01开始的秒数）
  /// 返回：true=状态已变更，false=状态未变更
  bool setActive(bool flag, DateTime? when);
  /// 获取会话活跃状态
  bool get isActive;

  /// 将消息数据包加入等待队列
  /// [rMsg] 可靠消息
  /// [data] 序列化后的消息字节数组
  /// [priority] 发送优先级
  /// 返回：false=加入队列失败，true=加入队列成功
  bool queueMessagePackage(ReliableMessage rMsg, Uint8List data, {int priority = 0});
}