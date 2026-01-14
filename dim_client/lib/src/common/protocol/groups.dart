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

/// 历史记录查询命令接口
/// 用于查询群组历史消息
/// 数据结构规范：
/// {
///     type : i2s(0x88),   // 命令类型（0x88转换为字符串）
///     sn   : 123,         // 序列号
///     command : "query",  // 命令名称
///     time    : 123.456,  // 命令时间戳
///     group     : "{GROUP_ID}",  // 群组ID
///     last_time : 0       // 查询的最后消息时间
/// }
abstract interface class QueryCommand implements GroupCommand{
  // 注意：
  //     此命令仅用于查询群组信息，
  //     不应保存到群组历史记录中
  static const String QUERY      = 'query';     // 命令常量

  /// 获取查询的最后群组历史时间
  /// 用于分页查询历史消息，返回该时间之后的消息
  DateTime? get lastTime;

  //
  //  工厂方法
  //
  
  /// 创建群组历史查询命令
  /// [group] 要查询的群组ID
  /// [lastTime] 最后消息时间（可选，为空则查询全部）
  /// 返回：查询命令实例
  static QueryCommand query(ID group, [DateTime? lastTime]) =>
      QueryGroupCommand.from(group, lastTime);
}

/// 群组查询命令实现类
/// 继承BaseGroupCommand，实现QueryCommand接口
class QueryGroupCommand extends BaseGroupCommand implements QueryCommand {
  /// 从字典初始化查询命令
  /// [dict] 包含查询命令字段的字典
  QueryGroupCommand([super.dict]);

  /// 实现lastTime获取逻辑：从字典中获取并转换为DateTime
  @override
  DateTime? get lastTime => getDateTime('last_time');
  
  /// 构造方法：创建群组查询命令
  /// [group] 群组ID
  /// [lastTime] 最后消息时间（可选）
  QueryGroupCommand.from(ID group, [DateTime? lastTime])
    : super.from(QueryCommand.QUERY, group)
  {
    if(lastTime != null){
      setDateTime('last_time', lastTime);     // 设置最后消息时间字段
    }
  }
}
//===============================================================================//
//===============================================================================//
//===============================================================================//
//===============================================================================//

/// 群组历史记录命令（新版）
/// 替代旧版QueryCommand，使用自定义内容格式
/// 数据结构规范：
/// {
///     "type" : i2s(0xCC),  // 自定义内容类型
///     "sn"   : 123,        // 序列号
///     "time" : 123.456,    // 时间戳
///     "app"  : "chat.dim.group",  // 应用标识
///     "mod"  : "history",         // 模块名称
///     "act"  : "query",           // 操作类型
///     "group"     : "{GROUP_ID}", // 群组ID
///     "last_time" : 0,            // 查询的最后消息时间
/// }
abstract interface class GroupHistory {

  static const String APP = 'chat.dim.group';  // 应用标识
  static const String MOD = 'history';         // 模块名称（历史记录）

  static const String ACT_QUERY = 'query';     // 操作类型：查询

  //
  //  工厂方法
  //

  /// 创建群组历史记录查询命令（新版）
  /// 注意：旧版QueryCommand已废弃，建议使用此方法
  /// [group] 群组ID
  /// [lastTime] 最后消息时间（可选）
  /// 返回：自定义内容命令实例
  static CustomizedContent queryGroupHistory(ID group, DateTime? lastTime) {
    // 创建自定义内容（app+mod+act）
    var content = CustomizedContent.create(app: APP, mod: MOD, act: ACT_QUERY);
    content.group = group;  // 设置群组ID
    if (lastTime != null) {
      // 设置查询的最后消息时间
      content.setDateTime('last_time', lastTime);
    }
    return content;
  }

}

/// 群组密钥命令
/// 用于群组密钥的查询/更新/请求/响应
/// 数据结构规范：
/// {
///     "type" : i2s(0xCC),   // 自定义内容类型
///     "sn"   : 123,         // 序列号
///     "time" : 123.456,     // 时间戳
///     "app"  : "chat.dim.group", // 应用标识
///     "mod"  : "keys",           // 模块名称（密钥）
///     "act"  : "query",          // 操作类型（query/update/request/respond）
///     "group"  : "{GROUP_ID}",   // 群组ID
///     "from"   : "{SENDER_ID}",  // 发送方ID
///     "to"     : ["{MEMBER_ID}", ],  // 目标成员列表
///     "digest" : "{KEY_DIGEST}",     // 密钥摘要
///     "keys"   : {                  // 密钥映射
///         "digest"      : "{KEY_DIGEST}",
///         "{MEMBER_ID}" : "{ENCRYPTED_KEY}",
///     }
/// }
abstract interface class GroupKeys {

  static const String APP = 'chat.dim.group';  // 应用标识
  static const String MOD = 'keys';            // 模块名称（密钥）

  /// 群组密钥操作类型说明：
  /// 1. query   - 群组机器人向发送方查询新密钥（当发现新成员或密钥摘要更新时）
  /// 2. update  - 发送方向群组机器人更新所有密钥（附带摘要）
  /// 3. request - 群成员向群组机器人请求新密钥（当收到新密钥摘要的消息时）
  /// 4. respond - 群组机器人向群成员响应新密钥
  static const String ACT_QUERY   = 'query';    // 操作：查询
  static const String ACT_UPDATE  = 'update';   // 操作：更新
  static const String ACT_REQUEST = 'request';  // 操作：请求
  static const String ACT_RESPOND = 'respond';  // 操作：响应

  //
  //  工厂方法
  //

  /// 创建群组密钥命令（通用方法）
  /// [action] 操作类型（ACT_QUERY/ACT_UPDATE/ACT_REQUEST/ACT_RESPOND）
  /// [group] 群组ID
  /// [sender] 发送方ID（密钥所属用户）
  /// [members] 目标成员列表（仅query操作需要）
  /// [digest] 密钥摘要（query/request操作需要）
  /// [encodedKeys] 加密后的密钥映射（update/respond操作需要）
  /// 返回：自定义内容命令实例
  static CustomizedContent create(String action, ID group, {
    required ID sender, // keys from this user
    List<ID>? members,  // query for members
    String? digest,     // query with digest
    Map? encodedKeys,   // update/respond keys (and digest)
  }) {
    assert(group.isGroup, 'group ID error: $group');  // 断言：必须是群组ID
    assert(sender.isUser, 'user ID error: $sender');  // 断言：必须是用户ID
    // 1. 创建自定义内容（app+mod+act）
    var content = CustomizedContent.create(app: APP, mod: MOD, act: action);
    content.group = group;  // 设置群组ID
    // 2. 设置发送方和目标成员
    content.setString('from', sender);
    if (members != null) {
      content['to'] = ID.revert(members);
    }
    // 3. 设置密钥和摘要
    if (encodedKeys != null) {
      content['keys'] = encodedKeys;
    } else if (digest != null) {
      content['digest'] = digest;
    }
    // OK
    return content;
  }

  /// 1. 创建群组密钥查询命令（机器人→发送方）
  /// [group] 群组ID
  /// [sender] 发送方ID（要查询的用户）
  /// [members] 目标成员列表
  /// [digest] 密钥摘要（可选）
  /// 返回：群组密钥查询命令
  static CustomizedContent queryGroupKeys(ID group, {
    required ID sender,
    required List<ID> members,
    String? digest,
  }) => create(ACT_QUERY, group, sender: sender, members: members, digest: digest);

  /// 2. 创建群组密钥更新命令（发送方→机器人）
  /// [group] 群组ID
  /// [sender] 发送方ID
  /// [encodedKeys] 加密后的密钥映射
  /// 返回：群组密钥更新命令
  static CustomizedContent updateGroupKeys(ID group, {
    required ID sender,
    required Map encodedKeys,
  }) => create(ACT_UPDATE, group, sender: sender, encodedKeys: encodedKeys);

  /// 3. 创建群组密钥请求命令（成员→机器人）
  /// [group] 群组ID
  /// [sender] 发送方ID（请求的成员）
  /// [digest] 密钥摘要（可选）
  /// 返回：群组密钥请求命令
  static CustomizedContent requestGroupKey(ID group, {
    required ID sender,
    String? digest,
  }) => create(ACT_REQUEST, group, sender: sender, digest: digest);

  /// 4. 创建群组密钥响应命令（机器人→成员）
  /// [group] 群组ID
  /// [sender] 发送方ID（机器人）
  /// [member] 目标成员ID
  /// [encodedKey] 加密后的密钥
  /// [digest] 密钥摘要
  /// 返回：群组密钥响应命令
  static CustomizedContent respondGroupKey(ID group, {
    required ID sender,
    required ID member,
    required Object encodedKey,
    required String digest,
  }) => create(ACT_RESPOND, group, sender: sender, encodedKeys: {
    'digest': digest,
    member.toString(): encodedKey,
  });

}