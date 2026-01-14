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

import '../common/constants.dart';
import '../models/chat.dart';
import '../models/chat_contact.dart';
import '../models/chat_group.dart';
import 'helper/sqlite.dart';

import 'message.dart';


/// 会话数据库操作接口：定义会话的基础操作规范
abstract class ConversationDBI {

  ///  获取所有会话列表
  ///
  /// @return 会话对象列表
  Future<List<Conversation>> getConversations();

  ///  添加新会话
  ///
  /// @param chat - 会话信息
  /// @return 操作成功返回true
  Future<bool> addConversation(Conversation chat);

  ///  更新会话信息
  ///
  /// @param chat - 会话信息
  /// @return 操作成功返回true
  Future<bool> updateConversation(Conversation chat);

  ///  移除会话
  ///
  /// @param chat - 会话ID
  /// @return 操作成功返回true
  Future<bool> removeConversation(ID chat);

}

/// 从数据库结果集中提取会话对象
/// [resultSet] 数据库查询结果集
/// [index] 行索引
/// 返回会话对象（群聊/单聊）
Conversation _extractConversation(ResultSet resultSet, int index) {
  String? cid = resultSet.getString('cid');        // 会话ID
  int? unread = resultSet.getInt('unread');        // 未读消息数
  String? last = resultSet.getString('last');      // 最后一条消息内容
  DateTime? time = resultSet.getDateTime('time');  // 最后消息时间
  int mentioned = resultSet.getInt('mentioned') ?? 0; // 提及序列号
  ID identifier = ID.parse(cid)!;
  
  // 根据ID类型创建不同的会话对象（群聊/单聊）
  if (identifier.isGroup) {
    return GroupInfo.from(identifier, unread: unread!,
        lastMessage: last, lastMessageTime: time, mentionedSerialNumber: mentioned);
  }
  return ContactInfo.from(identifier, unread: unread!,
      lastMessage: last, lastMessageTime: time, mentionedSerialNumber: mentioned);
}

/// 会话数据表处理器：实现ConversationDBI接口，封装会话表的增删改查
class _ConversationTable extends DataTableHandler<Conversation> implements ConversationDBI {
  /// 构造方法：初始化数据库连接器和结果集提取器
  _ConversationTable() : super(MessageDatabase(), _extractConversation);

  /// 会话表名
  static const String _table = MessageDatabase.tChatBox;
  /// 查询列名列表
  static const List<String> _selectColumns = ["cid", "unread", "last", "time", "mentioned"];
  /// 插入列名列表
  static const List<String> _insertColumns = ["cid", "unread", "last", "time", "mentioned"];

  /// 获取所有会话列表（按最后消息时间降序）
  @override
  Future<List<Conversation>> getConversations() async {
    SQLConditions cond = SQLConditions.kTrue;  // 无条件查询
    return await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'time DESC');
  }

  /// 添加新会话
  @override
  Future<bool> addConversation(Conversation chat) async {
    // 转换最后消息时间为秒级时间戳
    double? seconds;
    if (chat.lastMessageTime != null) {
      seconds = chat.lastMessageTime!.millisecondsSinceEpoch / 1000.0;
    }
    // 构建插入值列表
    List values = [chat.identifier.toString(), chat.unread,
      chat.lastMessage, seconds, chat.mentionedSerialNumber];
    // 执行插入操作
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

  /// 更新会话信息
  @override
  Future<bool> updateConversation(Conversation chat) async {
    // 转换最后消息时间为秒级时间戳
    int? time = chat.lastMessageTime?.millisecondsSinceEpoch;
    if (time == null) {
      time = 0;
    } else {
      time = time ~/ 1000;
    }
    // 构建更新值映射
    Map<String, dynamic> values = {
      'unread': chat.unread,
      'last': chat.lastMessage,
      'time': time,
      'mentioned': chat.mentionedSerialNumber,
    };
    // 构建更新条件：会话ID匹配
    SQLConditions cond;
    cond = SQLConditions(left: 'cid', comparison: '=', right: chat.identifier.toString());
    // 执行更新操作
    return await update(_table, values: values, conditions: cond) > 0;
  }

  /// 移除会话
  @override
  Future<bool> removeConversation(ID chat) async {
    // 构建删除条件：会话ID匹配
    SQLConditions cond;
    cond = SQLConditions(left: 'cid', comparison: '=', right: chat.toString());
    // 执行删除操作
    return await delete(_table, conditions: cond) >= 0;
  }

  /// 清理过期会话（重置未读、最后消息等字段）
  /// [expired] 过期时间点
  /// 返回更新的行数
  Future<int> burnConversations(DateTime expired) async {
    // 转换过期时间为秒级时间戳
    int time = expired.millisecondsSinceEpoch ~/ 1000;
    // 构建重置值映射
    Map<String, dynamic> values = {
      'unread': 0,
      'last': '',
      'mentioned': 0,
    };
    // 构建更新条件：最后消息时间 < 过期时间
    SQLConditions cond;
    cond = SQLConditions(left: 'time', comparison: '<', right: time);
    // 执行更新操作
    return await update(_table, values: values, conditions: cond);
  }

}

/// 会话缓存管理器：继承数据表处理器，增加内存缓存和通知机制
class ConversationCache extends _ConversationTable {

  /// 内存缓存的会话列表
  List<Conversation>? _caches;

  /// 在会话列表中查找指定ID的会话
  /// [chat] 会话ID
  /// [array] 会话列表
  /// 返回匹配的会话对象（null表示未找到）
  static Conversation? _find(ID chat, List<Conversation> array) {
    for (var item in array) {
      if (item.identifier == chat) {
        return item;
      }
    }
    return null;
  }
  
  /// 按最后消息时间降序排序会话列表
  /// [array] 会话列表
  static void _sort(List<Conversation> array) {
    array.sort((a, b) {
      DateTime? at = a.lastMessageTime;
      DateTime? bt = b.lastMessageTime;
      int ai = at == null ? 0 : at.millisecondsSinceEpoch;
      int bi = bt == null ? 0 : bt.millisecondsSinceEpoch;
      return bi - ai;  // 降序排列
    });
  }

  /// 获取所有会话（优先从缓存读取）
  @override
  Future<List<Conversation>> getConversations() async {
    List<Conversation>? conversations;
    await lock();  // 加锁保证线程安全
    try {
      conversations = _caches;
      if (conversations == null) {
        // 缓存未命中，从数据库加载
        conversations = await super.getConversations();
        // 更新内存缓存
        _caches = conversations;
      }
    } finally {
      unlock();  // 解锁
    }
    return conversations;
  }

  /// 添加新会话（带缓存更新和通知）
  @override
  Future<bool> addConversation(Conversation chat) async {
    // 1. 检查缓存
    List<Conversation>? array = await getConversations();
    if (_find(chat.identifier, array) != null) {
      assert(false, 'duplicated conversation: $chat');
      return updateConversation(chat);
    }
    // 2. 插入数据库
    if (await super.addConversation(chat)) {
      // 更新缓存：插入到列表头部并重新排序
      array.insert(0, chat);
      _sort(array);
    } else {
      Log.error('failed to add conversation: $chat');
      return false;
    }
    // 3. 发送会话更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kConversationUpdated, this, {
      'action': 'add',
      'ID': chat.identifier,
    });
    return true;
  }

  /// 更新会话信息（带缓存更新和通知）
  @override
  Future<bool> updateConversation(Conversation chat) async {
    // 1. 检查缓存
    List<Conversation>? array = await getConversations();
    Conversation? old = _find(chat.identifier, array);
    if (old == null) {
      assert(false, 'conversation not found: $chat');
      return false;
    }
    // 2. 更新数据库
    if (await super.updateConversation(chat)) {
      // 更新缓存
      if (!identical(old, chat)) {
        old.unread = chat.unread;
        old.lastMessageTime = chat.lastMessageTime;
        old.lastMessage = chat.lastMessage;
        old.mentionedSerialNumber = chat.mentionedSerialNumber;
      }
      _sort(array);  // 重新排序
    } else {
      Log.error('failed to update conversation: $chat');
      return false;
    }
    // 3. 发送会话更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kConversationUpdated, this, {
      'action': 'update',
      'ID': chat.identifier,
    });
    return true;
  }

  /// 移除会话（带缓存更新和通知）
  @override
  Future<bool> removeConversation(ID chat) async {
    // 1. 检查缓存
    List<Conversation>? array = await getConversations();
    Conversation? old = _find(chat, array);
    if (old == null) {
      Log.warning('conversation not found: $chat');
      return false;
    }
    // 2. 删除数据库记录
    if (await super.removeConversation(chat)) {
      // 从缓存移除
      array.remove(old);
    } else {
      Log.error('failed to delete conversation: $chat');
      return false;
    }
    // 3. 发送会话更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kConversationUpdated, this, {
      'action': 'remove',
      'ID': chat,
    });
    return true;
  }

  /// 清理过期会话（带通知）
  @override
  Future<int> burnConversations(DateTime expired) async {
    int results = await super.burnConversations(expired);
    if (results < 0) {
      Log.error('failed to clean expired conversations: $expired');
      return results;
    }
    // 发送会话清理通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kConversationCleaned, this, {
      'action': 'burn',
      'expired': expired,
      'results': results,
    });
    return results;
  }

}