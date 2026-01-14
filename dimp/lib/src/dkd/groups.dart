/* license: https://mit-license.org
 *
 *  ObjectKey : Object & Key kits
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

import 'package:dimp/dkd.dart';
import 'package:dimp/mkm.dart';

/// 群组历史相关命令基类
/// 作用：统一所有群组命令的消息类型为ContentType.HISTORY，作为群组命令的顶层父类
class BaseHistoryCommand extends BaseCommand implements HistoryCommand {
  /// 构造方法1：从字典初始化（解析网络传输的群组历史命令）
  BaseHistoryCommand([super.dict]);

  /// 构造方法2：从命令名称初始化（创建群组历史命令）
  /// @param cmd - 命令名称（如GroupCommand.INVITE）
  BaseHistoryCommand.fromName(String cmd)
    : super.fromType(ContentType.HISTORY, cmd);
}

/// 群组管理命令基类（所有群命令的核心父类）
/// 作用：封装群成员管理的通用逻辑（member/members字段解析），统一群命令的基础结构
class BaseGroupCommand extends BaseHistoryCommand implements GroupCommand {
  /// 构造方法1：从字典初始化（解析网络传输的群管理命令）
  BaseGroupCommand([super.dict]);

  /// 构造方法2：从命令名称+群组ID+成员初始化（创建群管理命令）
  /// @param cmd      - 命令名称（如GroupCommand。INVITE）
  /// @param group    - 群组ID
  /// @param member   - 单个成员ID（与members互斥）
  /// @param members  - 多个成员ID列表（与member互斥）
  BaseGroupCommand.from(String cmd, ID group, {ID? member, List<ID>? members})
    : super.fromName(cmd) {
    this.group = group;
    if (member != null) {
      assert(members == null, '参数错误：member和members不能同时设置');
      this.member = member;
    } else if (members != null) {
      this.members = members;
    }
  }

  /// 获取单个群成员ID（null表示未设置）
  @override
  ID? get member => ID.parse(this['member']);

  /// 设置单个群成员ID（同步更新字典，移除members字段保证互斥）
  @override
  set member(ID? user) {
    setString('member', user);
    remove('members');
  }

  /// 获取群成员列表（核心方法）
  /// 逻辑：有限解析members字段，无责降级到member字段，保证兼容性
  @override
  List<ID>? get members {
    var array = this['members'];
    if (array is List) {
      // 将列表项转为ID对象，保证类型安全
      return ID.convert(array);
    }
    // 降级解析member字段的单个成员
    ID? single = member;
    return single == null ? [] : [single];
  }

  /// 设置群成员列表（同步更新字典，移除member字段保证互斥）
  @override
  set members(List<ID>? users) {
    if (users == null) {
      remove('members');
    } else {
      this['members'] = ID.revert(users);
    }
    remove('member');
  }
}

/// 群组邀请命令类
/// 作用：封装群主邀请成员加入群组的命令，支持单/多成员邀请
class InviteGroupCommand extends BaseGroupCommand implements InviteCommand {
  /// 构造方法1：从字典初始化（解析网络传输的邀请命令）
  InviteGroupCommand([super.dict]);

  /// 构造方法2：从群组ID+成员初始化（创建邀请命令）
  /// @param group - 群组ID
  /// @param member - 单个被邀请成员ID（可选）
  /// @param members - 多个被邀请成员ID列表（可选）
  InviteGroupCommand.from(ID group, {ID? member, List<ID>? members})
    : super.from(GroupCommand.INVITE, group, member: member, members: members);
}

/// 群组踢出命令类（已弃用，推荐使用ResetCommand）
/// 作用：封装群主踢出群成员的命令，兼容老版本的踢出逻辑
class ExpelGroupCommand extends BaseGroupCommand implements ExpelCommand {
  /// 构造方法1：从字典初始化（解析网络传输的踢出命令）
  ExpelGroupCommand([super.dict]);

  /// 构造方法2：从群组ID+成员初始化（创建踢出命令）
  /// @param group - 群组ID
  /// @param member - 单个被踢出成员ID（可选）
  /// @param members - 多个被踢出成员ID列表（可选）
  ExpelGroupCommand.from(ID group, {ID? member, List<ID>? members})
    : super.from(GroupCommand.EXPEL, group, member: member, members: members);
}

/// 加入群组命令类
/// 作用：封装用户主动申请加入群组的命令，适配去中心化的自主加入场景
class JoinGroupCommand extends BaseGroupCommand implements JoinCommand {
  /// 构造方法1：从字典初始化（解析网络传输的加入命令）
  JoinGroupCommand([super.dict]);

  /// 构造方法2：从群组ID初始化（创建加入命令）
  /// @param group - 群组ID
  JoinGroupCommand.from(ID group) : super.from(GroupCommand.JOIN, group);
}

/// 退出群组命令类
/// 作用：封装用户主动退出群组的命令，适配去中心化的自主退出场景
class QuitGroupCommand extends BaseGroupCommand implements QuitCommand {
  /// 构造方法1：从字典初始化（解析网络传输的退出命令）
  QuitGroupCommand([super.dict]);

  /// 构造方法2：从群组ID初始化（创建退出命令）
  /// @param group - 群组ID
  QuitGroupCommand.from(ID group) : super.from(GroupCommand.QUIT, group);
}

/// 群组重置命令类
/// 作用：封装群主重置群成员列表的命令（替代ExpelCommand），支持批量设置群成员
class ResetGroupCommand extends BaseGroupCommand implements ResetCommand {
  /// 构造方法1：从字典初始化（解析网络传输的重置命令）
  ResetGroupCommand([super.dict]);

  /// 构造方法2：从群组ID+成员列表初始化（创建重置命令）
  /// @param group - 群组ID
  /// @param members - 重置后的群成员列表（必填）
  ResetGroupCommand.from(ID group, {required List<ID> members})
    : super.from(GroupCommand.RESET, group, members: members);
}
