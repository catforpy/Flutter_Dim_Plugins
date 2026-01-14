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

import '../common/dbi/message.dart';
import '../common/constants.dart';

import 'helper/error.dart';
import 'helper/sqlite.dart';


///
///  存储消息
///
///     文件路径: '{sdcard}/Android/data/chat.dim.sechat/files/.dkd/msg.db'
///


/// 消息数据库连接器：管理msg.db的创建和版本升级
class MessageDatabase extends DatabaseConnector {
  /// 构造方法：初始化数据库配置
  MessageDatabase() : super(name: dbName, directory: '.dkd', version: dbVersion,
      onCreate: (db, version) {
        // 1. 创建会话表：存储会话的基础信息（未读数、最后一条消息等）
        DatabaseConnector.createTable(db, tChatBox, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "cid VARCHAR(64) NOT NULL UNIQUE",   // 会话ID（唯一标识单个会话，如单聊/群聊ID）
          "unread INTEGER",                     // 该会话的未读消息数量
          "last VARCHAR(128)",                  // 最后一条消息的简短描述（用于会话列表展示）
          "time INTEGER",                       // 最后一条消息的时间戳（秒级）
          "mentioned INTEGER",                  // 提及消息的序列号（用于定位@我的消息）
        ]);
        
        // 2. 创建即时消息表：存储单条消息的完整信息
        DatabaseConnector.createTable(db, tInstantMessage, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "cid VARCHAR(64) NOT NULL",           // 会话ID（关联会话表的cid）
          "sender VARCHAR(64)",                 // 消息发送者ID（用户/机器人ID）
          // "receiver VARCHAR(64)",              // 接收者ID（已注释：会话ID已隐含接收者信息）
          "time INTEGER NOT NULL",              // 消息发送时间戳（秒级）
          "type INTEGER",                       // 消息类型（文本/图片/文件等，对应Content的类型）
          "sn INTEGER",                         // 消息序列号（单会话内唯一，用于去重/排序）
          "signature VARCHAR(8)",               // 消息签名后8位（用于快速区分不同消息，节省存储）
          // "content TEXT",                      // 内容（已注释：合并到msg字段的JSON中）
          "msg TEXT NOT NULL",                  // 消息完整内容（JSON字符串，包含envelope+content+签名等）
        ]);
        // 为cid字段创建索引：加速按会话ID查询消息的速度
        DatabaseConnector.createIndex(db, tInstantMessage,
            name: 'cid_index', fields: ['cid']);
        
        // 3. 创建消息追踪表：记录消息的发送/接收状态追踪信息
        DatabaseConnector.createTable(db, tTrace, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "cid VARCHAR(64) NOT NULL",           // 会话ID
          "sender VARCHAR(64) NOT NULL",        // 发送者ID
          "sn INTEGER NOT NULL",                // 消息序列号
          "signature VARCHAR(8)",               // 消息签名后8位
          "trace TEXT NOT NULL",                // 追踪信息（JSON字符串，如发送状态、送达状态等）
        ]);
        // 为sender字段创建索引：加速按发送者查询追踪记录的速度
        DatabaseConnector.createIndex(db, tTrace,
            name: 'trace_index', fields: ['sender']);
        
        // 4. 可靠消息表（待实现）：存储需要确认送达的可靠消息
      }, onUpgrade: (db, oldVersion, newVersion) {
        // 版本升级逻辑：v2及以上版本为会话表添加mentioned列（支持@我的消息功能）
        if (oldVersion < 2) {
          DatabaseConnector.addColumn(db, tChatBox, name: 'mentioned', type: 'INTEGER');
        }
      });

  /// 数据库文件名
  static const String dbName = 'msg.db';
  /// 数据库版本号
  static const int dbVersion = 2;

  /// 表名常量
  static const String tChatBox         = 't_conversation';        // 会话表
  static const String tInstantMessage  = 't_message';             // 即时消息表
  static const String tTrace           = 't_trace';               // 消息追踪表
  static const String tReliableMessage = 't_reliable_message';    // 可靠消息表（待实现）
}


/// 从数据库结果集中提取即时消息对象
/// [resultSet] 数据库查询结果集
/// [index] 行索引
/// 返回即时消息对象（解析失败时返回错误消息）
InstantMessage _extractInstantMessage(ResultSet resultSet, int index) {
  // 从结果集中获取msg字段（JSON字符串），为空则取空字符串
  String json = resultSet.getString('msg') ?? '';
  InstantMessage? msg;
  try {
    // 解析JSON字符串为Map，再转换为InstantMessage对象
    Map? info = JSONMap.decode(json);
    msg = InstantMessage.parse(info);
  } catch(e, st) {
    // 解析失败时记录错误日志，便于排查问题
    Log.error('failed to extract message: $json');
    Log.error('failed to extract message: $e, $st');
  }
  // 解析成功返回消息对象，失败则返回错误兜底的消息对象（避免空指针）
  return msg ?? DBErrorPatch.rebuildMessage(json);
}


/// 即时消息数据表处理器：实现InstantMessageDBI接口，封装消息表的增删改查
/// 核心职责：对外提供消息的CRUD接口，对内处理数据库交互逻辑
class InstantMessageTable extends DataTableHandler<InstantMessage> implements InstantMessageDBI {
  /// 构造方法：初始化数据库连接器和结果集提取器
  InstantMessageTable() : super(MessageDatabase(), _extractInstantMessage);

  /// 即时消息表名
  static const String _table = MessageDatabase.tInstantMessage;
  /// 查询列名列表（截取前1024000字符避免游标窗口过大）
  /// SUBSTR(msg, 0, 1024000) AS msg：截取msg字段前1024000个字符（约1MB），别名仍为msg
  /// 目的：避免超大消息（如大文件）导致查询卡顿/内存溢出，基础信息解析仅需前1MB内容
  static const List<String> _selectColumns = ['SUBSTR(msg, 0, 1024000) AS msg'];
  /// 插入列名列表：与消息表字段对应，用于插入新消息时指定字段
  static const List<String> _insertColumns = ["cid", "sender",/* "receiver",*/
    "time", "type", "sn", "signature",/* "content",*/ "msg"];

  /// 获取指定会话的即时消息列表
  /// [chat] 会话ID
  /// [start] 起始偏移量（默认0，用于分页）
  /// [limit] 最大数量（默认1024，避免一次查询过多数据）
  /// 返回消息列表和剩余数量（剩余数量暂未实现）
  @override
  Future<Pair<List<InstantMessage>, int>> getInstantMessages(ID chat,
      {int start = 0, int? limit}) async {
    limit ??= 1024;
    // 构建查询条件：仅查询指定会话ID的消息
    SQLConditions cond;
    cond = SQLConditions(left: 'cid', comparison: '=', right: chat.toString());
    // 按时间降序查询（最新消息在前），支持分页（offset/limit）
    List<InstantMessage> messages = await select(_table, columns: _selectColumns,
        conditions: cond, orderBy: 'time DESC', offset: start, limit: limit);
    int remaining = 0;
    // TODO: 计算剩余消息数量（总条数 - start - limit），暂未实现
    if (limit > 0 && limit == messages.length) {
      // 若查询结果数量等于limit，说明可能还有更多消息未查询
    }
    return Pair(messages, remaining);
  }

  /// 保存即时消息（核心方法）
  /// 逻辑：先检查是否存在同序列号的旧消息 → 无则插入 → 有则检查时间并更新
  /// [chat] 会话ID
  /// [iMsg] 待保存的即时消息对象
  /// 返回操作是否成功
  @override
  Future<bool> saveInstantMessage(ID chat, InstantMessage iMsg) async {
    String cid = chat.toString();
    String sender = iMsg.sender.toString();
    // 转换消息时间为秒级时间戳（数据库存储秒级，避免毫秒级数值过大）
    int? time = iMsg.time?.millisecondsSinceEpoch;
    if (time == null) {
      time = 0; // 时间为空时默认设为0
    } else {
      time = time ~/ 1000; // 毫秒转秒
    }
    Content content = iMsg.content;
    
    // 处理文件内容：移除data字段（文件二进制数据），避免数据库体积过大
    // 文件数据单独存储，数据库仅存文件元信息（路径/大小等）
    Map info;
    if (content is FileContent) {
      Map body = content.copyMap(false);
      body.remove('data'); // 移除二进制数据字段
      info = iMsg.copyMap(false);
      info['content'] = body;
    } else {
      info = iMsg.toMap(); // 非文件消息直接转Map
    }
    // 将消息对象序列化为JSON字符串，存入数据库msg字段
    String msg = JSON.encode(info);

    // 处理签名：仅保留后8位（用于快速区分消息，完整签名在msg的JSON中）
    // 8位字符冲突概率极低（1/4294967296），兼顾存储效率和唯一性
    String? sig = iMsg.getString('signature');
    if (sig != null) {
      sig = sig.substring(sig.length - 8);
    }

    // 检查旧记录：通过「序列号+会话ID+发送者ID」唯一标识一条消息
    SQLConditions cond;
    cond = SQLConditions(left: 'sn', comparison: '=', right: content.sn);
    cond.addCondition(SQLConditions.kAnd, left: 'cid', comparison: '=', right: cid);
    cond.addCondition(SQLConditions.kAnd, left: 'sender', comparison: '=', right: sender);
    List<InstantMessage> messages = await select(_table, columns: _selectColumns,
        conditions: cond, limit: 1);

    // 无旧记录：插入新消息
    if (messages.isEmpty) {
      List values = [cid, sender, time, iMsg.type,
        content.sn, sig, msg];
      // 插入数据库，返回行数<=0则表示失败
      if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
        Log.error('failed to save message: $sender -> $chat');
        return false;
      }
      // 发送消息更新通知：告知上层（UI/业务层）有新消息添加
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kMessageUpdated, this, {
        'action': 'add',          // 操作类型：add表示新增消息
        'ID': chat,               // 会话ID（对应cid，可理解为会话的uid）
        'envelope': iMsg.envelope,// 消息信封：包含发送者、接收者、时间等基础元信息
        'content': iMsg.content,  // 消息内容：文本/图片/文件等具体内容（Content对象）
        'msg': iMsg,              // 完整的即时消息对象（包含envelope+content+签名等）
      });
      return true;
    }

    // 有旧记录：检查时间，避免覆盖更新时间更早的消息（防止旧消息覆盖新消息）
    DateTime? oldTime = messages.last.time; // 旧消息的时间
    DateTime? newTime = iMsg.time;           // 新消息的时间
    // 仅当「新旧时间都有效」且「新消息时间早于旧消息」时，忽略这条新消息（视为过期）
    if (oldTime != null && newTime != null && newTime.isBefore(oldTime)) {
      Log.warning('ignore expired message: $iMsg');
      return false;
    }

    // 更新旧消息：仅更新时间、类型、签名、msg字段（其他字段如sn/cid/sender不变）
    Map<String, dynamic> values = {
      'time': time,
      'type': iMsg.type,
      'signature': sig,
      'msg': msg,
    };
    // 更新数据库，返回行数<1则表示失败
    if (await update(_table, values: values, conditions: cond) < 1) {
      Log.error('failed to update message: $sender -> $chat');
      return false;
    }
    // 发送消息更新通知：告知上层（UI/业务层）消息已更新
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kMessageUpdated, this, {
      'action': 'update',        // 操作类型：update表示更新已有消息
      'ID': chat,               // 会话ID
      'envelope': iMsg.envelope,// 消息信封（基础元信息）
      'content': iMsg.content,  // 消息内容（具体内容）
      'msg': iMsg,              // 完整的即时消息对象
    });
    return true;
  }

  /// 移除指定的即时消息
  /// [chat] 会话ID
  /// [envelope] 消息信封（包含发送者等元信息）
  /// [content] 消息内容（包含序列号sn）
  /// 返回操作是否成功
  @override
  Future<bool> removeInstantMessage(ID chat, Envelope envelope, Content content) async {
    String cid = chat.toString();
    String sender = envelope.sender.toString();
    // 构建删除条件：通过「序列号+会话ID+发送者ID」定位要删除的消息
    SQLConditions cond;
    cond = SQLConditions(left: 'sn', comparison: '=', right: content.sn);
    cond.addCondition(SQLConditions.kAnd, left: 'cid', comparison: '=', right: cid);
    cond.addCondition(SQLConditions.kAnd, left: 'sender', comparison: '=', right: sender);
    // 执行删除操作，返回行数<0则表示失败
    if (await delete(_table, conditions: cond) < 0) {
      Log.error('failed to remove message: $sender -> $chat');
      return false;
    }
    // 发送消息更新通知：告知上层（UI/业务层）消息已移除
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kMessageUpdated, this, {
      'action': 'remove',        // 操作类型：remove表示移除单条消息
      'ID': chat,               // 会话ID
      'envelope': envelope,      // 消息信封
      'content': content,        // 消息内容
    });
    return true;
  }

  /// 移除指定会话的所有即时消息
  /// [chat] 会话ID
  /// 返回操作是否成功
  @override
  Future<bool> removeInstantMessages(ID chat) async {
    // 构建删除条件：删除指定会话ID的所有消息
    SQLConditions cond;
    cond = SQLConditions(left: 'cid', comparison: '=', right: chat.toString());
    // 执行删除操作，返回行数<0则表示失败
    if (await delete(_table, conditions: cond) < 0) {
      Log.error('failed to remove messages: $chat');
      return false;
    }
    // 发送消息更新通知：告知上层（UI/业务层）会话消息已清空
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kMessageUpdated, this, {
      'action': 'clear',         // 操作类型：clear表示清空整个会话的消息
      'ID': chat,               // 会话ID
    });
    return true;
  }

  /// 清理过期消息（批量删除）
  /// [expired] 过期时间点（早于该时间的消息都会被删除）
  /// 返回删除的行数（<0表示失败）
  Future<int> burnMessages(DateTime expired) async {
    // 转换为秒级时间戳（与数据库存储格式一致）
    int time = expired.millisecondsSinceEpoch ~/ 1000;
    // 构建删除条件：删除时间早于过期时间的所有消息
    SQLConditions cond;
    cond = SQLConditions(left: 'time', comparison: '<', right: time);
    // 执行删除操作，返回删除的行数
    int results = await delete(_table, conditions: cond);
    if (results < 0) {
      Log.error('failed to remove expired messages: $expired');
      return results;
    }
    // 发送消息清理通知：告知上层（UI/业务层）过期消息已清理
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kMessageCleaned, this, {
      'action': 'burn',          // 操作类型：burn表示清理过期消息
      'expired': expired,        // 过期时间点
      'results': results,        // 成功删除的消息数量
    });
    return results;
  }
}