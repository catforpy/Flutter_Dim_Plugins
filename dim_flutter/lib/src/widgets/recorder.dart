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

import 'dart:typed_data';

// import 'package:get/get.dart';
import 'package:dim_flutter/src/ui/nav.dart';
import 'package:flutter/material.dart';

import 'package:dim_client/ok.dart';
import 'package:dim_client/ok.dart' as lnc;

import '../channels/manager.dart';
import '../common/constants.dart';
import '../ui/styles.dart';

import 'permissions.dart';

/// 【核心回调定义】录音完成后的回调类型
/// 作用：把录音得到的mp4字节数据和时长传递给上层组件（比如聊天页面）
typedef OnVoiceRecordComplected = void Function(Uint8List mp4, double duration);

/// 录音按钮组件（微信式“按住说话”按钮）
/// 核心角色：1. UI交互载体 2. 跨端录音调用者 3. 通知中心的消费者
/// RecordButton
class RecordButton extends StatefulWidget {
  const RecordButton({required this.onComplected, super.key});

  // 上层组件传入的回调：录音完成（且用户选择发送）时触发
  final OnVoiceRecordComplected onComplected;

  @override
  State<StatefulWidget> createState() => _RecordState();

}

class _RecordState extends State<RecordButton> implements lnc.Observer {
  // ======================== 【消费者核心环节1：订阅通知】 ========================
  // 构造方法：组件初始化时，订阅“录音完成”通知
  _RecordState() {
    // 获取通知中心单例（相当于连接RocketMQ的Consumer）
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kRecordFinished);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kRecordFinished);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kRecordFinished) {
      Uint8List data = userInfo?['data'];
      double duration = userInfo?['duration'];
      if (_position.dy > 0.0) {
        Log.debug('stop record, send: $_position, ${duration}s, ${data.length} bytes');
        widget.onComplected(data, duration);
      } else {
        Log.debug('stop record, cancel: $_position, ${duration}s, ${data.length} bytes');
      }
    }
  }

  bool _recording = false;

  Offset _position = Offset.zero;

  Color? _color(BuildContext context) {
    if (!_recording) {
      return Styles.colors.recorderBackgroundColor;
    } else if (_position.dy > 0.0) {
      return Styles.colors.recordingBackgroundColor;
    } else {
      return Styles.colors.cancelRecordingBackgroundColor;
    }
  }
  String get _text {
    if (!_recording) {
      return i18nTranslator.translate('Hold to Talk');
    } else if (_position.dy < 0) {
      return i18nTranslator.translate('Release to Cancel');
    } else {
      return i18nTranslator.translate('Release to Send');
    }
  }

  Widget _button(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: _color(context),
    ),
    alignment: Alignment.center,
    child: Text(_text, textAlign: TextAlign.center,
      style: TextStyle(
        color: Styles.colors.recorderTextColor,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: GestureDetector(
      child: _button(context),
      onLongPressDown: (details) {
        Log.warning('tap down: ${details.localPosition}');
        setState(() {
          _position = details.localPosition;
          _recording = true;
        });
      },
      onLongPressCancel: () {
        Log.warning('tap cancel');
        setState(() {
          _recording = false;
        });
      },
      onLongPressStart: (details) {
        Log.debug('check permissions');
        PermissionCenter().requestMicrophonePermissions(context, onGranted: (context) {
          Log.debug('start record');
          ChannelManager man = ChannelManager();
          man.audioChannel.startRecord();
        });
      },
      onLongPressMoveUpdate: (details) {
        // Log.warning('move: ${details.localPosition}');
        setState(() {
          _position = details.localPosition;
        });
      },
      onLongPressUp: () {
        Log.warning('tap up');
        setState(() {
          _recording = false;
        });
        ChannelManager man = ChannelManager();
        man.audioChannel.stopRecord();
        Log.debug('stop record, touch point: $_position');
      },
    ),
  );

}
