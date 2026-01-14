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

import 'package:flutter/services.dart'; // Flutter原生通信核心库
import 'package:dim_client/ok.dart';    // DIM-SDK基础工具库
import '../common/constants.dart'; // 项目通用常量（通道方法名/通知名）
import 'manager.dart';             // 通道管理相关（单例/基类）

/// 音频通道：封装Flutter与原生（iOS/Android）的音频交互
/// 核心功能：录制音频、播放音频，通过通知中心回调结果
class AudioChannel extends SafeChannel {
  /// 构造方法：初始化音频通道，绑定通道名称并设置方法回调
  /// [name] - 原生通道名称（对应ChannelNames.audio）
  AudioChannel(super.name) {
    // 设置原生调用Flutter方法的处理器（接收录制/播放完成的回调）
    setMethodCallHandler(_handle);
  }

  /// 原生→Flutter方法调用处理器：处理音频相关的回调事件
  /// [call] - 原生传递的方法调用（包含方法名+参数）
  Future<void> _handle(MethodCall call) async {
    String method = call.method;      // 原生调用的方法名
    var arguments = call.arguments;   // 原生传递的参数

    // 场景1：音频录制完成回调（原生通知Flutter）
    if(method == ChannelMethods.onRecordFinished){
      Uint8List mp4 = arguments['data'];      //录制的音频二进制
      double duration = arguments['current']; //录制时长（秒）
      // 异步发送录制完成通知（解耦：让其他模块监听该事件）
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kRecordFinished, this,{
        'data': mp4,
        'duration': duration,
      });
    }
    // 场景2：音频播放完成回调（原生通知Flutter）
    else if(method == ChannelMethods.onPlayFinished){
      String? path = arguments['path'];     //播放的音频文件路径
      // 异步发送播放完成通知
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kPlayFinished, this,{
        'path':path,
      });
    }
  }

  // ===================== Flutter→原生 调用方法（音频控制） =====================
  /// 开始录制音频：调用原生方法启动录音
  Future<void> startRecord() async => 
    await invoke(ChannelMethods.startRecord, null);

  /// 停止录制音频：调用原生方法停止录音（触发onRecordFinished回调）
  Future<void> stopRecord() async =>
    await invoke(ChannelMethods.stopRecord, null);

  /// 开始播放音频：调用原生方法播放指定路径的音频文件
  /// [path] - 音频文件本地路径
  Future<void> startPlay(String path) async => 
    await invoke(ChannelMethods.startPlay, {'path': path});

  /// 停止播放音频：调用原生方法停止播放（触发onPlayFinished回调）
  /// [path] - 可选，指定停止的音频路径（null则停止当前播放）
  Future<void> stopPlay(String? path) async =>
      await invoke(ChannelMethods.stopPlay, {
        'path': path,
      });
}