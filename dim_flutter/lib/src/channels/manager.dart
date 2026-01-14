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

import 'package:dim_client/ok.dart';    // DIM-SDK基础工具库
import 'package:flutter/services.dart';

import 'audio.dart';     // 音频通道
import 'keychain.dart';  // 密钥通道
import 'session.dart';   // 会话消息通道
import 'transfer.dart';  // 文件传输通道

/// 通道名称常量类：统一管理所有原生通道名称
/// 作用：避免硬编码，方便维护和跨模块引用
class ChannelNames {
  /// 音频通道名称（Flutter↔原生 音频交互）
  static const String audio = "chat.dim/audio";
  /// 会话通道名称（Flutter↔原生 消息发送交互）
  static const String session = "chat.dim/session";
  /// 文件传输通道名称（Flutter↔原生 文件存储路径交互）
  static const String fileTransfer = "chat.dim/ftp";
  /// 数据库通道名称（Flutter↔原生 密钥存储交互）
  static const String database = "chat.dim/db";
}

/// 通道方法常量类：统一管理所有原生方法名
/// 分类：按通道功能划分，清晰区分不同通道的方法
class ChannelMethods {
  // ===================== 音频通道方法 =====================
  static const String startRecord        = "startRecord";        // 开始录音
  static const String stopRecord         = "stopRecord";         // 停止录音
  static const String startPlay          = "startPlay";          // 开始播放
  static const String stopPlay           = "stopPlay";           // 停止播放
  static const String onRecordFinished   = "onRecordFinished";   // 录音完成回调
  static const String onPlayFinished     = "onPlayFinished";     // 播放完成回调

  // ===================== 会话通道方法 =====================
  static const String sendContent        = "sendContent";        // 发送消息内容
  static const String sendCommand        = "sendCommand";        // 发送命令消息

  // ===================== 文件传输通道方法 =====================
  static const String getCachesDirectory    = "getCachesDirectory";    // 获取缓存目录
  static const String getTemporaryDirectory = "getTemporaryDirectory"; // 获取临时目录

  // ===================== 数据库通道方法 =====================
  static const String savePrivateKey             = "savePrivateKey";             // 保存私钥
  static const String privateKeyForSignature     = "privateKeyForSignature";     // 获取签名私钥
  static const String privateKeyForVisaSignature = "privateKeyForVisaSignature"; // 获取Visa签名私钥
  static const String privateKeysForDecryption   = "privateKeysForDecryption";   // 获取解密私钥列表
}

/// 通道管理器：单例模式，统一管理所有业务通道
/// 作用：
/// 1. 全局唯一入口，避免重复创建通道
/// 2. 集中管理所有通道实例，方便跨模块调用
class ChannelManager {
  // 单例实现：工厂构造方法 + 静态私有实例
  factory ChannelManager() => _instance;
  static final ChannelManager _instance = ChannelManager._internal();
  // 私有构造方法：防止外部实例化
  ChannelManager._internal();

  // ===================== 通道实例（按需初始化） =====================
  final AudioChannel audioChannel = AudioChannel(ChannelNames.audio);         // 音频通道
  final SessionChannel sessionChannel = SessionChannel(ChannelNames.session); // 会话消息通道
  final FileTransferChannel ftpChannel = FileTransferChannel(ChannelNames.fileTransfer); // 文件传输通道
  final KeychainChannel dbChannel = KeychainChannel(ChannelNames.database);   // 密钥存储通道
}

/// 安全通道基类：封装MethodChannel的异常处理
/// 核心改进：统一捕获原生调用异常，避免单个通道崩溃影响全局
class SafeChannel extends MethodChannel {
  /// 构造方法：继承MethodChannel，传入通道名称
  SafeChannel(super.name);

  /// 安全调用原生方法：封装异常处理
  /// [method] - 要调用的原生方法名
  /// [arguments] - 传递给原生的参数（可为null）
  /// 返回：原生返回的泛型数据（null表示调用失败）
  Future<T?> invoke<T>(String method, Map? arguments) async {
    try {
      // 调用原生方法，捕获异步错误
      return await super.invokeMethod(method, arguments).onError((error, stackTrace) {
        Log.error('failed to invoke method: $error, $stackTrace'); // 错误日志
        return null;
      });
    } catch (e, st) {
      // 捕获所有异常（包括同步异常）
      Log.error('channel error: $e, $st');
      return null;
    }
  }
}