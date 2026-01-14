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

import 'dart:typed_data'; // 字节数据处理

import 'package:dim_client/ok.dart';     // DIM-SDK基础工具（日志/异步）
import 'package:dim_client/ws.dart';    // DIM-SDK WebSocket（Emitter基类）
import 'package:dim_client/sdk.dart';   // DIM-SDK核心库（消息/内容模型）
import 'package:dim_client/common.dart'; // DIM-SDK通用接口
import 'package:dim_client/client.dart'; // DIM-SDK客户端核心
import 'package:dim_client/pnf.dart' show URLHelper; // URL/文件名工具

import '../common/constants.dart';      // 项目常量（通知名）
import '../models/amanuensis.dart';     // 消息记录员模型
import '../filesys/upload.dart';        // 文件上传工具

import 'shared.dart';                   // 全局变量/单例

/// 共享消息发送器：继承Emitter，实现文件消息处理+消息撤回功能
/// 实现Observer：监听文件上传通知，处理上传结果
class SharedEmitter extends Emitter implements Observer {

  /// 构造方法：初始化发送器，注册文件上传通知监听
  SharedEmitter() {
    var nc = NotificationCenter();
    // 监听文件上传成功通知
    nc.addObserver(this, NotificationNames.kPortableNetworkUploadSuccess);
    // 监听文件上传失败通知
    nc.addObserver(this, NotificationNames.kPortableNetworkError);
  }

  // ===================== 核心属性重写 =====================
  /// 当前登录用户（重写父类）
  @override
  Future<User?> get currentUser async {
    GlobalVariable shared = GlobalVariable();
    return await shared.facebook.currentUser;
  }

  /// 消息发送器实例（重写父类）
  @override
  Transmitter? get messenger {
    GlobalVariable shared = GlobalVariable();
    return shared.messenger;
  }

  // ===================== 文件上传任务管理 =====================
  /// 待发送文件消息任务缓存：filename => InstantMessage
  final Map<String, InstantMessage> _outgoing = {};

  /// 添加文件上传任务到缓存
  void _addTask(String filename, InstantMessage item) {
    _outgoing[filename] = item;
  }

  /// 从缓存中移除并获取文件上传任务
  InstantMessage? _popTask(String filename) {
    InstantMessage? item = _outgoing[filename];
    if (item != null) {
      _outgoing.remove(filename);
    }
    return item;
  }

  /// 清理过期任务（TODO：待实现）
  void purge() {
    // TODO: remove expired messages in the map
  }

  // ===================== 通知监听实现 =====================
  /// 处理文件上传通知（成功/失败）
  @override
  Future<void> onReceiveNotification(Notification notification) async {
    String name = notification.name;
    Map info = notification.userInfo!;
    
    // 1. 文件上传成功
    if (name == NotificationNames.kPortableNetworkUploadSuccess) {
      var pnf = info['PNF'];
      String filename = info['filename'] ?? pnf?['filename'] ?? '';
      Uri url = info['url'] ?? info['URL'];
      await _onUploadSuccess(filename, url);
    }
    // 2. 文件上传失败
    else if (name == NotificationNames.kPortableNetworkError) {
      var pnf = info['PNF'];
      String filename = info['filename'] ?? pnf?['filename'] ?? '';
      await _onUploadFailed(filename);
    }
  }

  /// 文件上传成功处理逻辑
  Future<void> _onUploadSuccess(String filename, Uri url) async {
    // 获取缓存的消息任务
    InstantMessage? iMsg = _popTask(filename);
    if (iMsg == null) {
      logWarning('failed to get task: $filename, url: $url');
      return;
    }
    logInfo('get task for file: $filename, url: $url');
    
    // 替换文件内容为下载URL（移除本地数据）
    FileContent content = iMsg.content as FileContent;
    assert(!content.containsKey('data'), 'file content error: $content');
    content.url = url;
    
    // 发送消息（优先级1）
    await sendInstantMessage(iMsg, priority: 1).onError((error, stackTrace) {
      logError('failed to send message: $error');
      return null;
    });
  }

  /// 文件上传失败处理逻辑
  Future<void> _onUploadFailed(String filename) async {
    // 获取缓存的消息任务
    InstantMessage? iMsg = _popTask(filename);
    if (iMsg == null) {
      logError('failed to get task: $filename');
      return;
    }
    logInfo('get task for file: $filename');
    
    // 标记消息错误状态
    iMsg['error'] = {
      'message': 'failed to upload file',
    };
    // 保存错误消息
    await _saveInstantMessage(iMsg);
  }

  // ===================== 文件消息处理核心逻辑 =====================
  /// 处理文件内容消息（重写父类）
  /// 返回：true=拦截消息（等待上传），false=直接发送
  @override
  Future<bool> handleFileContent(FileContent content, InstantMessage iMsg, {
    int priority = 0
  }) async {
    Uri? url = content.url;       // 文件下载URL
    Uint8List? data = content.data; // 文件二进制数据
    String? filename = content.filename; // 文件名

    // 1. 检查下载URL
    if (url != null) {
      // URL存在：文件已上传，直接发送
      if (data != null) {
        // 断言：已上传的文件不应包含本地数据
        assert(!content.containsKey('data'), 'file content error: $filename, $url');
        content.data = null;
      }
      logInfo('file data uploaded: $filename -> $url');
      return false; // 直接发送消息
    }

    // 2. 检查文件名
    if (filename == null) {
      // 无URL且无文件名：内容错误，丢弃消息
      logError('failed to create upload task: $content');
      assert(false, 'file content error: $content');
      return true;
    } 
    // 文件名编码校验/重建
    else if (URLHelper.isFilenameEncoded(filename)) {
      // 文件名已编码（md5(data).ext）：无需处理
    } 
    else if (data != null) {
      // 重建文件名（基于数据MD5）
      filename = URLHelper.filenameFromData(data, filename);
      Log.info('rebuild filename: ${content.filename} -> $filename');
      content.filename = filename;
    } 
    else {
      // 文件名错误：丢弃消息
      assert(false, 'filename error: $content');
      return true;
    }

    // 3. 添加上传任务并开始上传
    _addTask(filename, iMsg);
    var ftp = SharedFileUploader();
    // 上传加密后的文件数据
    bool waiting = await ftp.uploadEncryptData(content, iMsg.sender);
    
    if (waiting) {
      // 等待上传完成：缓存消息
      logInfo('cache instant message for waiting file data uploaded: $filename');
      await _saveInstantMessage(iMsg);
    }
    
    return waiting; // 返回true表示拦截消息，等待上传完成
  }

  // ===================== 消息发送与保存 =====================
  /// 发送即时消息（重写父类），发送后自动保存
  @override
  Future<ReliableMessage?> sendInstantMessage(InstantMessage iMsg, {int priority = 0}) async {
    ReliableMessage? rMsg = await super.sendInstantMessage(iMsg, priority: priority);
    // 发送后保存消息
    await _saveInstantMessage(iMsg);
    return rMsg;
  }

  /// 保存即时消息到数据库（静态工具方法）
  static Future<bool> _saveInstantMessage(InstantMessage iMsg) async {
    Amanuensis clerk = Amanuensis();
    return await clerk.saveInstantMessage(iMsg).onError((error, stackTrace) {
      Log.error('failed to save message: $error');
      return false;
    });
  }

  // ===================== 消息撤回功能 =====================
  /// 撤回文本消息
  Future<Pair<InstantMessage?, ReliableMessage?>> recallTextMessage(TextContent content, Envelope envelope) async =>
      await recallMessage(content, envelope, text: '_(message recalled)_');

  /// 撤回图片消息
  Future<Pair<InstantMessage?, ReliableMessage?>> recallImageMessage(ImageContent content, Envelope envelope) async =>
      await recallFileMessage(content, envelope, text: '_(image recalled)_');

  /// 撤回音频消息
  Future<Pair<InstantMessage?, ReliableMessage?>> recallAudioMessage(AudioContent content, Envelope envelope) async =>
      await recallFileMessage(content, envelope, text: '_(voice message recalled)_');

  /// 撤回视频消息
  Future<Pair<InstantMessage?, ReliableMessage?>> recallVideoMessage(VideoContent content, Envelope envelope) async =>
      await recallFileMessage(content, envelope, text: '_(video recalled)_');

  /// 撤回文件消息
  Future<Pair<InstantMessage?, ReliableMessage?>> recallFileMessage(FileContent content, Envelope envelope, {
    String? text,
  }) async => await recallMessage(content, envelope, text: text ?? '_(file recalled)_', origin: {
    'type': content['type'],
    'sn': content['sn'],
    'URL': content['URL'],
    'filename': content['filename'],
  });

  /// 通用消息撤回逻辑
  Future<Pair<InstantMessage?, ReliableMessage?>> recallMessage(Content content, Envelope envelope, {
    String? text, Map<String, dynamic>? origin,
  }) async {
    // 1. 校验当前用户
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return const Pair(null, null);
    }

    // 2. 校验发送者（只能撤回自己的消息）
    ID sender = user.identifier;
    if (sender != envelope.sender) {
      assert(false, 'cannot recall this message: ${envelope.sender} -> ${envelope.receiver}, ${content.group}');
      return const Pair(null, null);
    }

    // 3. 确定接收者（群组消息/单聊消息）
    ID receiver = content.group ?? envelope.receiver;
    
    // 4. 执行撤回逻辑
    return await _recall(content, sender: sender, receiver: receiver,
      text: text ?? '_(message recalled)_', origin: origin ?? {
        'type': content['type'],
        'sn': content['sn'],
      },
    );
  }

  /// 构建并发送撤回命令
  Future<Pair<InstantMessage?, ReliableMessage?>> _recall(Content content, {
    required ID sender, required ID receiver,
    required String text, required Map<String, dynamic> origin,
  }) async {
    assert(sender != receiver, 'cycled message: $sender, $text, $content');
    
    // 1. 构建撤回命令内容
    Content command = TextContent.create(text);
    command['format'] = 'markdown';       // 格式：markdown
    command['action'] = 'recall';         // 动作：撤回
    command['origin'] = origin;           // 原消息信息
    command['time'] = content['time'];    // 原消息时间
    command['sn'] = content['sn'];        // 原消息序列号
    if (receiver.isGroup) {
      command.group = receiver;           // 群组标记
    }

    // 2. 打包即时消息
    Envelope envelope = Envelope.create(sender: sender, receiver: receiver);
    content = Content.parse(command.toMap()) ?? command;
    InstantMessage iMsg = InstantMessage.create(envelope, content);
    iMsg['muted'] = true; // 静音发送（不触发通知）

    // 3. 发送撤回消息（低优先级）
    ReliableMessage? rMsg = await sendInstantMessage(iMsg, priority: DeparturePriority.SLOWER);
    if (rMsg == null && !receiver.isGroup) {
      logWarning('not send yet (type=${content.type}): $receiver');
    }
    
    return Pair(iMsg, rMsg);
  }
}