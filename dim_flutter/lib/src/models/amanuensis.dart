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

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../common/constants.dart';
import '../common/protocol/search.dart';
import '../client/cpu/text.dart';
import '../client/shared.dart';

import 'chat.dart';
import 'chat_contact.dart';
import 'chat_group.dart';
import 'shield.dart';
import 'message.dart';

/// 会话管理核心类（单例），负责聊天会话的加载、更新、清理、删除，以及消息存储和会话状态同步
/// 混入 Logging 用于日志输出
class Amanuensis with Logging {

  /// 工厂构造函数，保证单例
  factory Amanuensis() => _instance;
  /// 单例实例
  static final Amanuensis _instance = Amanuensis._internal();
  /// 私有构造函数，防止外部实例化
  Amanuensis._internal();

  ///
  ///  会话相关属性
  ///

  /// 所有会话列表缓存
  List<Conversation>? _conversations;
  /// 会话ID到会话对象的映射（弱引用Map，避免内存泄漏）
  final Map<ID, Conversation> _conversationMap = WeakValueMap();

  /// 过滤后的会话列表（排除拉黑联系人、陌生人，仅保留好友和群聊）
  List<Conversation> get conversations {
    List<Conversation>? all = _conversations;
    if(all == null){
      return [];
    }
    List<Conversation> array = [];
    for(Conversation chat in all){
      // 群聊直接加入
      if(chat is GroupInfo){
        array.add(chat);
      }else if(chat is ContactInfo){
        // 拉黑的联系人跳过
        if(chat.isBlocked){

        }else if(chat.isNotFriend){
          // 陌生人跳过
        }else{
          // 好友加入
          array.add(chat);
        }
      }
    }
    return array;
  }

  /// 仅获取群聊会话列表
  List<Conversation> get groupChats {
    List<Conversation>? all = _conversations;
    if(all == null){
      return [];
    }
    List<Conversation> array = [];
    for(Conversation chat in all){
      if(chat is GroupInfo){
        array.add(chat);
      }
    }
    return array;
  }

  /// 仅获取陌生人会话列表（新好友）
  List<Conversation> get strangers {
    List<Conversation>? all = _conversations;
    if(all == null){
      return [];
    }
    List<Conversation> array = [];
    for(Conversation chat in all){
      if(chat is ContactInfo){
        if(chat.isNotFriend){
          array.add(chat);
        }
      }
    }
    return array;
  }

  /// 从数据库加载所有会话列表并缓存
  /// 返回加载后的会话列表
  Future<List<Conversation>> loadConversations() async {
    List<Conversation>? array = _conversations;
    // 缓存存在则直接返回，避免重复加载
    if(array == null){
      GlobalVariable shared = GlobalVariable();
      // 从数据库获取会话ID列表并构建会话对象
      array = await shared.database.getConversations();
      logDebug('${array.length} conversation(s) loaded');
      // 深拷贝避免原列表被修改
      List<Conversation> temp = [...array];
      // 讲会话对象存入映射表
      for(Conversation item in temp){
        logDebug('new conversation created: $item');
        _conversationMap[item.identifier] = item;
      }
      logDebug('${array.length} conversation(s) loaded: $array');
      // 更新缓存
      _conversations = array;
    }
    return array;
  }

  /// 清空指定会话的消息（保留会话，仅清空消息和未读状态）
  /// [identifier] 会话ID
  /// 返回是否清空成功
  Future<bool> clearConversation(ID identifier) async {
    GlobalVariable shared = GlobalVariable();
    // 1.清空该会话的所有消息
    if(await shared.database.removeInstantMessages(identifier)) {} else {
      logError('failed to clear messages in conversation: $identifier');
      return false;
    }
    // 2.更新缓存中的会话状态
    Conversation? chat = _conversationMap[identifier];
    if(chat != null){
      // 重置未读数
      chat.unread = 0;
      // 重置最后一条消息
      chat.lastMessage = null;
      // 重置最后一条消息时间
      chat.lastMessageTime = null;
      // 重置@我的消息序号
      chat.mentionedSerialNumber = 0;
      // 3. 将更新后的状态保存到数据库
      if(await shared.database.updateConversation(chat)) {} else {
        logError('failed to update conversation: $chat');
        return false;
      }
    }
    // 操作成功
    logWarning('conversation cleared: $identifier');
    return true;
  }

  /// 删除指定会话（彻底删除，包括消息和会话记录）
  /// [identifier] 会话ID
  /// 返回是否删除成功
  Future<bool> removeConversation(ID identifier) async {
    GlobalVariable shared = GlobalVariable();
    // 1. 清空该会话的所有消息
    if(await shared.database.removeInstantMessages(identifier)) {} else {
      logError('failed to clear messages in conversation: $identifier');
      return false;
    }
    // 2. 从数据库删除会话记录
    if(await shared.database.removeConversation(identifier)) {} else {
      logError('failed to remove conversation: $identifier');
      return false;
    }
    // 3. 从缓存中移除会话
    Conversation? chat = _conversationMap[identifier];
    if(chat != null){
      _conversations?.remove(chat);
      _conversationMap.remove(identifier);
    }
    // 操作成功
    logWarning('conversation cleared: $identifier');
    return true;
  }

  /// 根据消息信封和内容获取对应的会话ID
  /// [head] 消息信封（包含发送者、接收者、群ID等）
  /// [body] 消息内容
  /// 返回会话ID
  Future<ID> _cid(Envelope head, Content? body) async {
    // 优先获取群ID（内容中的群ID > 信封中的群ID）
    ID? group = body?.group;
    group ??= head.group;
    if (group != null) {
      // 群聊消息，会话ID为群ID
      return group;
    }
    // 非群聊消息，获取接收者ID
    ID receiver = head.receiver;
    if (receiver.isGroup) {
      // 接收者是群，会话ID为群ID
      return receiver;
    }
    // 私聊消息，确定会话ID（自己发送的消息取接收者，别人发送的取发送者）
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    assert(user != null, 'current user should not be empty here');
    ID sender = head.sender;
    if (sender == user?.identifier) {
      // 自己发送的消息，会话ID为接收者
      return receiver;
    } else {
      // 别人发送的消息，会话ID为发送者
      return sender;
    }
  }

  /// 清空指定会话的未读状态（未读数和@我的数）
  /// [chatBox] 会话对象
  /// 返回是否更新成功
  Future<bool> clearUnread(Conversation chatBox) async {
    ID cid = chatBox.identifier;
    int unread = chatBox.unread;
    int mentioned = chatBox.mentionedSerialNumber;
    //无未读和@我的消息，无需更新
    if(unread ==chatBox && mentioned == 0){
      logInfo('[Badge] no need to update: $cid, unread: $unread, at: $mentioned');
      return false;
    }else if(_conversationMap[cid] == null){
      // 会话不存在，返回失败
      logWarning('[Badge] conversation not found: $cid, unread: $unread, at: $mentioned');
      return false;
    }
    // 重置未读状态
    chatBox.unread = 0;
    chatBox.mentionedSerialNumber = 0;
    GlobalVariable shared = GlobalVariable();
    // 保存到数据库
    if(await shared.database.updateConversation(chatBox)){
      logInfo('[Badge] unread count cleared: $chatBox, unread: $unread, at: $mentioned');
    }else {
      logError('[Badge] failed to update conversation: $chatBox, unread: $unread, at: $mentioned');
      return false;
    }
    // 发送会话已读通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kConversationUpdated, null,{
      'action': 'read',
      'ID': cid,
    });
    return true;
  }

  /// 根据新消息更新会话的最后一条消息、未读数、@我的数等状态
  /// [cid] 会话ID
  /// [iMsg] 新消息对象
  Future<void> _updateConversation(ID cid, InstantMessage iMsg) async {
    final ID sender = iMsg.sender;
    Shield shield = Shield();
    // 发送者被拉黑，跳过更新
    if (await shield.isBlocked(sender, group: iMsg.group)) {
      logError('contact is blocked: $sender, group: ${iMsg.group}');
      return;
    }
    Content content = iMsg.content;
    // 隐藏消息，跳过更新
    if (content.getBool('hidden') == true) {
      logDebug('ignore hidden message: $sender -> $cid: $content');
      return;
    }
    DefaultMessageBuilder mb = DefaultMessageBuilder();
    // 命令类消息，跳过更新
    if (mb.isHiddenContent(content, sender)) {
      logInfo('ignore command for conversation updating');
      return;
    }
    GlobalVariable shared = GlobalVariable();
    CommonFacebook facebook = shared.facebook;
    User? current = await facebook.currentUser;
    assert(current != null, 'failed to get current user');
    // 构建最后一条消息的显示文本
    String last = mb.getText(content, sender);
    if (last.isEmpty) {
      logWarning('content text empty: $content');
      return;
    } else {
      // 替换换行符，截断超长文本（最多200字符）
      last = last.replaceAll(RegExp('[\r\n]+'), ' ').trim();
      if (last.length > 200) {
        last = '${last.substring(0, 197)}...';
      }
      // 群聊消息显示发送者昵称
      if (cid.isGroup && sender != current?.identifier) {
        String name = await facebook.getName(sender);
        last = '$name: $last';
      }
    }
    DateTime? time = iMsg.time;
    logWarning('update last message: $last for conversation: $cid');
    // 计算未读数增量（自己发送的/命令消息/静音消息不增加未读数）
    int increase;
    if (current?.identifier == sender) {
      logDebug('message from myself');
      increase = 0;
    } else if (content is Command) {
      logDebug('ignore command');
      increase = 0;
    } else if (iMsg.getBool('muted') == true || content.getBool('muted') == true) {
      logInfo('muted message');
      increase = 0;
    } else {
      increase = 1;
    }
    // 检查消息是否@我或@所有人
    int mentioned = 0;
    if (content is TextContent) {
      Visa? visa = await current?.visa;
      String? nickname = visa?.name;
      assert(nickname != null, 'failed to get my nickname');
      var text = content.text;
      // 匹配@我的昵称或@all/@All
      if (text.endsWith('@$nickname') || text.contains('@$nickname ')) {
        mentioned = content.sn;
      } else if (text.endsWith('@all') || text.contains('@all ')) {
        mentioned = content.sn;
      } else if (text.endsWith('@All') || text.contains('@All ')) {
        mentioned = content.sn;
      }
    }

    // 更新会话状态
    Conversation? chatBox = _conversationMap[cid];
    if (chatBox == null) {
      // 新会话，创建并初始化
      chatBox = Conversation.fromID(cid);
      if (chatBox == null) {
        logError('failed to get conversation: $cid');
        return;
      }
      chatBox.unread = increase;
      chatBox.lastMessage = last;
      chatBox.lastMessageTime = time;
      if (mentioned > 0) {
        chatBox.mentionedSerialNumber = mentioned;
      }
      // 保存新会话到数据库
      if (await shared.database.addConversation(chatBox)) {
        await chatBox.reloadData();
        // 加入缓存
        _conversationMap[cid] = chatBox;
        // _conversations?.insert(0, chatBox);
      } else {
        logError('failed to add conversation: $chatBox');
        return;
      }
    } else {
      // 已有会话，检查消息时间（只更新最新消息）
      DateTime? oldTime = chatBox.lastMessageTime;
      if (oldTime == null || time == null || time.isAfter(oldTime)) {
        // 新消息，继续更新
      } else {
        logWarning('ignore old message: $sender -> ${iMsg.receiver}'
            ' (${iMsg['group']}), time: $time');
        return;
      }
      // 会话窗口未打开，更新未读数和@我的数；已打开则重置
      if (chatBox.widget == null) {
        chatBox.unread += increase;
        if (mentioned > 0) {
          chatBox.mentionedSerialNumber = mentioned;
        }
      } else {
        logWarning('chat box is opened for: $cid');
        chatBox.unread = 0;
        chatBox.mentionedSerialNumber = 0;
      }
      // 更新最后一条消息和时间
      chatBox.lastMessage = last;
      chatBox.lastMessageTime = time;
      // 保存到数据库
      if (await shared.database.updateConversation(chatBox)) {} else {
        logError('failed to update conversation: $chatBox');
        return;
      }
    }
    // 发送会话更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kConversationUpdated, this, {
      'action': 'update',
      'ID': cid,
      'msg': iMsg,
    });
  }

  /// 保存即时消息到数据库，并更新对应会话状态
  /// [iMsg] 即时消息对象
  /// 返回是否保存成功
  Future<bool> saveInstantMessage(InstantMessage iMsg) async {
    Content content = iMsg.content;
    // 回执消息单独处理
    if (content is ReceiptCommand) {
      return await saveReceipt(iMsg);
    }
    // TODO: 检查消息类型，仅保存普通消息和群命令，忽略握手、登录等命令

    // 以下类型消息不保存，直接返回成功
    if (content is HandshakeCommand) {
      // 握手命令由CPU处理，无需保存
      return true;
    }
    if (content is ReportCommand) {
      // 上报命令发送到服务器，无需保存
      return true;
    }
    if (content is LoginCommand) {
      // 登录命令由CPU处理，无需保存
      return true;
    }
    if (content is MetaCommand) {
      // 元数据/文档命令由CPU检查并保存，无需此处保存
      return true;
    }
    // if (content is MuteCommand || content is BlockCommand) {
    //   // TODO: 为静音/拉黑命令创建CPU处理逻辑
    //   return true;
    // }
    if (content is SearchCommand) {
      // 搜索结果由CPU解析，无需保存
      return true;
    }
    if (content is ForwardContent) {
      // 转发内容会被解析，解密后保存，无需保存转发内容本身
      return true;
    }

    GlobalVariable shared = GlobalVariable();

    if (content is CustomizedContent) {
      // 自定义内容由业务解析，无需保存
      String app = content.application;
      String mod = content.module;
      String act = content.action;
      logInfo('ignore customized content: $app, $mod, $act from: ${iMsg.sender}');
      return true;
    } else if (ServiceContentHandler(shared.database).checkAppContent(content)) {
      // 应用服务内容由业务解析，无需保存
      var app = content['app'];
      var mod = content['mod'];
      var act = content['act'];
      if (content.getBool('hidden') == true) {
        logInfo('ignore hidden content: $app, $mod, $act from: ${iMsg.sender}');
        return true;
      } else if (app == 'chat.dim.search' && mod == 'users') {
        logInfo('show active users: ${content["users"]}');
      } else {
        logInfo('ignore content: $app, $mod, $act from: ${iMsg.sender}');
        return true;
      }
    }

    if (content is InviteCommand) {
      // 邀请命令，重新发送密钥
      ID me = iMsg.receiver;
      ID group = content.group!;
      SymmetricKey? key = await shared.database.getCipherKey(sender: me, receiver: group);
      if (key != null) {
        // 移除密钥的"复用"标记
        key.remove("reused");
      }
    } else if (content is QueryCommand) {
      // FIXME: 同一个查询命令是否发送给不同成员？
      return true;
    }

    // 获取消息对应的会话ID
    ID cid = await _cid(iMsg.envelope, iMsg.content);
    // 保存消息到数据库
    bool ok = await shared.database.saveInstantMessage(cid, iMsg);
    if (ok) {
      // TODO: 保存消息轨迹
      // 更新会话状态
      await _updateConversation(cid, iMsg);
    }
    return ok;
  }

  /// 保存消息回执（已读/送达回执）
  /// [iMsg] 包含回执命令的消息对象
  /// 返回是否保存成功
  Future<bool> saveReceipt(InstantMessage iMsg) async {
    Content content = iMsg.content;
    // 校验是否为回执命令
    if (content is! ReceiptCommand) {
      assert(false, 'receipt error: $iMsg');
      return false;
    }
    // 获取原始消息信封
    Envelope? env = content.originalEnvelope;
    if (env == null) {
      logError('original envelope not found: $content');
      return false;
    } else if (env.type == ContentType.COMMAND || env.type == ContentType.HISTORY) {
      // 忽略命令/历史消息的回执
      logWarning('ignore receipt for command: ${env.sender} -> ${env.receiver}, ${env.type}');
      return true;
    } else if (env.type == ContentType.FORWARD || env.type == ContentType.ARRAY) {
      // 忽略转发/数组内容的回执
      logWarning('ignore receipt for forward content: ${env.sender} -> ${env.receiver}, ${env.type}');
      return true;
    } else if (env.type == ContentType.CUSTOMIZED || env.type == ContentType.APPLICATION) {
      // 忽略自定义/应用内容的回执
      logWarning('ignore receipt for customized content: ${env.sender} -> ${env.receiver}, ${env.type}');
      return true;
    }
    // 构建轨迹信息
    Map mta = {
      'ID': iMsg.sender.toString(),
      'did': iMsg.sender.toString(),
      'time': content['time'],
    };
    // 序列化轨迹信息
    String trace = JSON.encode(mta);
    // 获取原始消息对应的会话ID
    ID cid = await _cid(env, null);
    ID sender = env.sender;  // 原始消息发送者
    int? sn = content.originalSerialNumber;  // 原始消息序号
    String? signature = content.originalSignature;  // 原始消息签名
    if (sn == null) {
      sn = 0;
      logError('original sn not found: $content, sender: ${iMsg.sender}');
    }
    // 保存轨迹到数据库
    GlobalVariable shared = GlobalVariable();
    if (await shared.database.addTrace(trace, cid,
        sender: sender, sn: sn, signature: signature)) {} else {
      logError('failed to add message trace: ${iMsg.sender} ($sender -> $cid)');
      return false;
    }
    // 发送消息轨迹更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kMessageTraced, this, {
      'cid': cid,
      'sender': sender,
      'sn': sn,
      'signature': signature,
      'mta': mta,
      'text': content.text
    });
    return true;
  }
}