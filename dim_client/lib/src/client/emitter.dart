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

import 'package:lnc/log.dart';
import 'package:object_key/object_key.dart';
import 'package:dimsdk/dimsdk.dart';

import '../common/session.dart';
import '../group/shared.dart';

import '../common/protocol/password.dart';

/// 消息发射器抽象类
/// 核心功能：封装文本、语音、图片、视频等消息的发送逻辑
abstract class Emitter with Logging {
  /// 获取当前登录用户
  Future<User?> get currentUser;

  /// 获取消息发送器
  Transmitter? get messenger;

  /// 发送文本消息
  /// [text]：文本内容
  /// [extra]：额外参数
  /// [receiver]：接收者ID
  /// 返回：打包后的消息对（即时消息+可靠消息）
  Future<Pair<InstantMessage?, ReliableMessage?>> sendText(
    String text, {
    Map<String, Object>? extra,
    required ID receiver,
  }) async {
    assert(text.isNotEmpty, 'text message should not empty');
    // 创建文本内容
    TextContent content = TextContent.create(text);
    // 检查是否为Markdown格式
    if (checkMarkdown(text)) {
      logInfo('send text as markdown: $text => $receiver');
      content['format'] = 'markdown';
    } else {
      logInfo('send text as plain: $text -> $receiver');
    }
    // 设置额外参数
    if (extra != null) {
      content.addAll(extra);
    }
    return await sendContent(content, receiver: receiver);
  }

  // 受保护方法：检查文本是否为Markdown格式
  bool checkMarkdown(String text) {
    // 检查是否包含链接
    if (text.contains('://')) {
      return true;
    }
    // 检查是否包含代码块
    int pos = text.indexOf('```');
    if (pos >= 0) {
      pos += 3;
      int next = text.codeUnitAt(pos);
      if (next != '`'.codeUnitAt(0)) {
        pos = text.indexOf('```', pos + 1);
        if (pos > 0) {
          return true;
        }
      }
    }
    // 检查是否包含标题/引用
    List<String> array = text.split('\n');
    for (String line in array) {
      if (line.startsWith('> ')) {
        return true;
      } else if (line.startsWith('## ')) {
        return true;
      } else if (line.startsWith('### ')) {
        return true;
      }
    }
    // TODO: 其他Markdown格式检查
    return false;
  }

  /// 发送语音消息
  /// [mp4]：语音数据（MP4格式）
  /// [filename]：文件名（格式：$encoded.mp4）
  /// [duration]：语音时长（秒）
  /// [extra]：额外参数
  /// [receiver]：接收者ID
  /// 返回：打包后的消息对
  Future<Pair<InstantMessage?, ReliableMessage?>> sendVoice(
    Uint8List mp4, {
    required String filename,
    required double duration,
    Map<String, Object>? extra,
    required ID receiver,
  }) async {
    assert(mp4.isNotEmpty, 'voice data should not empty');
    // 封装传输数据
    TransportableData ted = TransportableData.create(mp4);
    // 创建音频内容
    AudioContent content = FileContent.audio(data: ted, filename: filename);
    // 设置语音数据长度和时长
    content['length'] = mp4.length;
    content['duration'] = duration;
    // 设置额外参数
    if (extra != null) {
      content.addAll(extra);
    }
    return await sendContent(content, receiver: receiver);
  }

  /// 发送图片消息
  /// [jpeg]：图片数据（JPEG格式）
  /// [filename]：文件名（格式：$encoded.jpeg）
  /// [thumbnail]：图片缩略图
  /// [extra]：额外参数
  /// [receiver]：接收者ID
  /// 返回：打包后的消息对
  Future<Pair<InstantMessage?, ReliableMessage?>> sendPicture(
    Uint8List jpeg, {
    required String filename,
    required PortableNetworkFile? thumbnail,
    Map<String, Object>? extra,
    required ID receiver,
  }) async {
    assert(jpeg.isNotEmpty, 'image data should not empty');
    // 封装传输数据
    TransportableData ted = TransportableData.create(jpeg);
    // 创建图片数据
    ImageContent content = FileContent.image(data: ted, filename: filename);
    // 设置图片数据长度
    content['length'] = jpeg.length;
    // 设置缩略图和额外参数
    if (thumbnail != null) {
      content.thumbnail = thumbnail;
    }
    if (extra != null) {
      content.addAll(extra);
    }
    return await sendContent(content, receiver: receiver);
  }

  /// 发送视频消息
  /// [url]：视频URL
  /// [snapshot]：视频封面
  /// [title]：视频标题
  /// [filename]：文件名
  /// [extra]：额外参数
  /// [receiver]：接收者ID
  /// 返回：打包后的消息对
  Future<Pair<InstantMessage?, ReliableMessage?>> sendMovie(
    Uri url, {
    required PortableNetworkFile? snapshot,
    required String? title,
    String? filename,
    Map<String, Object>? extra,
    required ID receiver,
  }) async {
    // 创建视频内容
    VideoContent content = FileContent.video(
      filename: filename,
      url: url,
      password: Password.kPlainKey,
    );
    // 设置封面、标题和额外参数
    if (snapshot != null) {
      content.snapshot = snapshot;
    }
    if (title != null) {
      content['title'] = title;
    }
    if (extra != null) {
      content.addAll(extra);
    }
    return await sendContent(content, receiver: receiver);
  }

  /// 发送通用内容
  /// [content]：消息内容
  /// [sender]：发送者ID（默认当前用户）
  /// [receiver]：接收者ID
  /// [priority]：优先级
  /// 返回：打包后的消息对
  Future<Pair<InstantMessage?, ReliableMessage?>> sendContent(
    Content content, {
    ID? sender,
    required ID receiver,
    int priority = 0,
  }) async {
    // 检查发送者（默认当前用户）
    if (sender == null) {
      User? user = await currentUser;
      sender = user?.identifier;
      if (sender == null) {
        assert(false, 'failed to get current user');
        return Pair(null, null);
      }
    }
    // 处理群组接收者
    if (receiver.isGroup) {
      assert(
        content.group == null || content.group == receiver,
        'group ID error: $receiver, $content',
      );
      content.group = receiver;
    }
    // 创建消息信封
    Envelope envelope = Envelope.create(sender: sender, receiver: receiver);
    // 创建即时消息
    InstantMessage iMsg = InstantMessage.create(envelope, content);
    // 发送即时消息
    ReliableMessage? rMsg = await sendInstantMessage(iMsg, priority: 0);
    if (rMsg == null && !receiver.isGroup) {
      logWarning('not send yet (type=${content.type}): $receiver');
    }
    return Pair(iMsg, rMsg);
  }

  /// 发送即时消息
  /// [iMsg]：即时消息
  /// [priority]：优先级
  /// 返回：可靠消息（发送成功）或null（发送失败/等待文件上传）
  Future<ReliableMessage?> sendInstantMessage(
    InstantMessage iMsg, {
    int priority = 0,
  }) async {
    // 1. 检查文件内容
    Content content = iMsg.content;
    if (content is FileContent) {
      // 注意：不允许直接发送包含文件数据的消息，需先上传到CDN
      // 处理文件内容（加密并上传）
      bool waiting = await handleFileContent(content, iMsg, priority: priority);
      if (waiting) {
        // 等待文件上传完成后重新调用此方法
        return null;
      }
    }
    assert(iMsg.content['data'] == null, 'cannot send this message: $iMsg');

    // 2. 检查接收者
    ID receiver = iMsg.receiver;
    logInfo(
      'sending message (type=${iMsg.content.type}): ${iMsg.sender} -> $receiver',
    );
    if (receiver.isUser) {
      // 个人消息直接发送
      return await messenger?.sendInstantMessage(iMsg, priority: priority);
    }
    // 群组消息通过群组管理器发送
    SharedGroupManager manager = SharedGroupManager();
    return await manager.sendInstantMessage(iMsg, priority: priority);
  }

  // 文件内容发送流程说明：
  // Step 1: 将原始数据保存到缓存目录
  // Step 2: 保存不含content.data的即时消息
  // Step 3: 用密码加密数据
  // Step 4: 上传加密数据到CDN并获取下载URL
  // Step 5: 重新发送包含下载URL的即时消息

  /// 加密并上传文件数据到CDN
  /// [content]：文件内容
  /// [iMsg]：待发送的即时消息
  /// [priority]：优先级
  /// 返回：true=等待上传，false=无需等待/上传完成
  Future<bool> handleFileContent(
    FileContent content,
    InstantMessage iMsg, {
    int priority = 0,
  });
}
