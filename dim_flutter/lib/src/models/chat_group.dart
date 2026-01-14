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

import 'package:flutter/cupertino.dart';
// import 'package:get/get.dart';

import 'package:dim_client/ok.dart' as lnc;
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';
import 'package:dim_client/group.dart';
import 'package:dim_client/client.dart';

import '../client/shared.dart';
import '../common/dbi/contact.dart';
import '../common/constants.dart';
import '../network/group_image.dart';
import '../ui/nav.dart';
import '../utils/syntax.dart';
import '../widgets/alert.dart';

import 'amanuensis.dart';
import 'chat.dart';
import 'chat_contact.dart';

/// 群邀请模型：记录邀请人、群ID、被邀请人、邀请时间
class Invitation {
  Invitation({required this.sender, required this.group, required this.member, required this.time});

  /// 邀请人ID
  final ID sender;
  /// 群ID
  final ID group;
  /// 被邀请人ID
  final ID member;
  /// 邀请时间
  final DateTime? time;
}

/// 群聊会话类（继承自Conversation，混入Logging），封装群聊的属性和操作
class GroupInfo extends Conversation with Logging {
  /// 构造函数：初始化群聊ID和基础属性
  /// [identifier] 群ID
  /// [unread] 未读数
  /// [lastMessage] 最后一条消息
  /// [lastMessageTime] 最后一条消息时间
  /// [mentionedSerialNumber] @我的消息序号
  GroupInfo(super.identifier, {super.unread = 0, super.lastMessage, super.lastMessageTime, super.mentionedSerialNumber = 0}) {
    // 注册群相关通知监听
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kGroupHistoryUpdated);
    nc.addObserver(this, NotificationNames.kAdministratorsUpdated);
    nc.addObserver(this, NotificationNames.kMembersUpdated);
  }

  /// 接收通知的处理方法
  /// [notification] 收到的通知
  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    // 处理群历史更新通知
    if(name == NotificationNames.kGroupHistoryUpdated){
      ID? gid = userInfo?['ID'];
      assert(gid != null, 'notification error: $notification');
      if(gid == identifier){
        logInfo('group history updated: $gid');
        setNeedsReload();
        await reloadData();
      }
    }else if(name == NotificationNames.kAdministratorsUpdated){
      // 处理群成员更新通知
      ID? gid = userInfo?['ID'];
      assert(gid != null, 'notification error: $notification');
      if (gid == identifier) {
        logInfo('members updated: $gid');
        setNeedsReload();
        await reloadData();
      }
    }else{
      // 其他通知交给父类处理
      await super.onReceiveNotification(notification);
    }
  }

  /// 当前登录用户ID
  ID? _current;

  /// 临时群名称（群无名称时，由成员昵称拼接）
  String? _temporaryTitle;

  /// 群公告
  Bulletin? _bulletin;

  /// 群主ID
  ID? _owner;
  /// 群管理员列表
  List<ID>? _admins;
  /// 群成员列表
  List<ID>? _members;

  /// 群邀请记录列表
  List<Invitation>? _invitations;
  /// 群重置命令和消息
  Pair<ResetCommand?, ReliableMessage?>? _reset;

  /// 是否是群主
  bool get isOwner {
    ID? me = _current;
    ID? owner = _owner;
    return me != null && owner != null && me == owner;
  }
  /// 是否非群主
  bool get isNotOwner {
    ID? me = _current;
    ID? owner = _owner;
    return me != null && owner != null && me != owner;
  }

  /// 是否是群管理员
  bool get isAdmin {
    ID? me = _current;
    List<ID>? admins = _admins;
    return me != null && admins != null && admins.contains(me);
  }
  /// 是否非群管理员
  bool get isNotAdmin {
    ID? me = _current;
    List<ID>? admins = _admins;
    return me != null && admins != null && !admins.contains(me);
  }

  /// 是否是群成员
  bool get isMember {
    ID? me = _current;
    List<ID>? members = _members;
    return me != null && members != null && members.contains(me);
  }
  /// 是否非群成员
  bool get isNotMember {
    ID? me = _current;
    List<ID>? members = _members;
    return me != null && members != null && !members.contains(me);
  }

  /// 获取群显示标题（群名称 + 备注，无名称时用临时名称/匿名名称）
  @override
  String get title {
    String text = name;
    if (text.isEmpty) {
      text = _temporaryTitle ?? '';
    }
    // 获取群备注
    ContactRemark cr = remark;
    String alias = cr.alias;
    if (alias.isEmpty) {
      return text.isEmpty ? Anonymous.getName(identifier) : text;
    }
    // 群名称过长时截断
    if (VisualTextUtils.getTextWidth(text) > 25) {
      text = VisualTextUtils.getSubText(text, 22);
      text = '$text...';
    }
    // 最终标题：群名称 (备注)
    return '$text ($alias)';
  }

  /// 获取群主ID
  ID? get owner => _owner;
  /// 获取群管理员列表
  List<ID> get admins => _admins ?? [];
  /// 获取群成员列表
  List<ID> get members => _members ?? [];

  /// 获取群邀请记录列表
  List<Invitation> get invitations => _invitations ?? [];
  /// 获取群重置命令和消息
  Pair<ResetCommand?, ReliableMessage?> get reset => _reset ?? const Pair(null, null);

  /// 获取群头像组件
  /// [width] 宽度
  /// [height] 高度
  /// [fit] 适配方式
  @override
  Widget getImage({double? width, double? height, BoxFit? fit}) =>
      GroupImage(this, width: width, height: height, fit: fit);

  /// 加载群聊详细数据（群主、管理员、成员、邀请记录、重置命令等）
  @override
  Future<void> loadData() async {
    // 先执行父类的加载逻辑
    await super.loadData();
    // 获取全局变量
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    assert(user != null, 'current user not found');
    // 保存当前用户ID
    ID? me = _current = user?.identifier;
    if (me == null) {
      _owner = null;
      _admins = null;
      _members = null;
    } else {
      /// 获取群主
      _owner = await shared.facebook.getOwner(identifier);
      /// 获取群管理员
      _admins = await shared.facebook.getAdministrators(identifier);
      /// 获取群公告和成员
      _bulletin = await shared.facebook.getBulletin(identifier);
      if (_bulletin == null) {
        _members = null;
        _temporaryTitle = null;
      } else {
        _members = await shared.facebook.getMembers(identifier);
        logInfo('group members: $identifier, ${members.length}');
        // 构建成员ContactInfo列表（用于临时名称）
        List<ContactInfo> users = [];
        ContactInfo? info;
        for (ID item in members) {
          info = ContactInfo.fromID(item);
          if (info == null) {
            logWarning('failed to get contact: $item');
            continue;
          }
          users.add(info);
        }
        // 无群名称时构建临时名称
        if (name.isEmpty && _temporaryTitle == null) {
          _temporaryTitle = await buildGroupName(members);
        }
        // 发送群成员更新通知
        var nc = lnc.NotificationCenter();
        nc.postNotification(NotificationNames.kParticipantsUpdated, this, {
          'ID': identifier,
          'members': members,
        });
      }
    }
    // 加载群邀请记录和重置命令
    if (_owner == null || _members == null) {
      _invitations = [];
      _reset = const Pair(null, null);
    } else {
      AccountDBI db = shared.database;
      // 获取群历史命令（邀请、加入等）
      List<Pair<GroupCommand, ReliableMessage>> histories = await db.getGroupHistories(group: identifier);
      GroupCommand content;
      ReliableMessage rMsg;
      List<Invitation> array = [];
      List<ID> members;
      // 倒序遍历（最新的邀请在前）
      var reversed = histories.reversed;
      for (var item in reversed) {
        content = item.first;
        rMsg = item.second;
        assert(content.group == identifier, 'group ID not match: $identifier, $content');
        // 解析邀请/加入命令
        if (content is InviteCommand) {
          members = content.members ?? [];
        } else if (content is JoinCommand) {
          members = [rMsg.sender];
        } else {
          logDebug('ignore group command: ${content.cmd}');
          continue;
        }
        logInfo('${rMsg.sender} invites $members');
        // 构建邀请记录
        for (var user in members) {
          array.add(Invitation(
            sender: rMsg.sender,
            group: identifier,
            member: user,
            time: content.time ?? rMsg.time,
          ));
        }
      }
      _invitations = array;
      // 获取群重置命令
      _reset = await db.getResetCommandMessage(group: identifier);
    }
  }

  /// 构建临时群名称（由成员昵称拼接）
  /// [members] 群成员ID列表
  /// 返回拼接后的名称
  static Future<String> buildGroupName(List<ID> members) async {
    assert(members.isNotEmpty, 'members should not be empty here');
    GlobalVariable shared = GlobalVariable();
    ClientFacebook facebook = shared.facebook;
    // 取第一个成员的昵称
    String text = await facebook.getName(members.first);
    String nickname;
    // 拼接后续成员昵称（最多32字符）
    for (int i = 1; i < members.length; ++i) {
      nickname = await facebook.getName(members[i]);
      if (nickname.isEmpty) {
        continue;
      }
      text += ', $nickname';
      if (text.length > 32) {
        text = '${text.substring(0, 28)} ...';
        break;
      }
    }
    return text;
  }

  /// 修改群名称（带权限校验和持久化）
  /// [context] 上下文
  /// [name] 新群名称
  void setGroupName({required BuildContext context, required String name}) {
    // 名称未变化则直接返回
    if (name == this.name) {
      return;
    } else {
      this.name = name;
    }
    // 执行名称更新逻辑
    _updateGroupName(identifier, name).then((message) {
      if (message != null && context.mounted) {
        Alert.show(context, i18nTranslator.translate('Error'), 
        i18nTranslator.translate(message));
      }
    });
  }

  /// 执行群名称更新的具体逻辑（仅群主可操作）
  /// [group] 群ID
  /// [text] 新群名称
  /// 返回错误信息（成功返回null）
  static Future<String?> _updateGroupName(ID group, String text) async {
    GlobalVariable shared = GlobalVariable();
    // 0. 获取当前用户
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return 'Failed to get current user.';
    }
    ID me = user.identifier;
    // 1. 校验权限（仅群主可修改）
    SharedGroupManager man = SharedGroupManager();
    if (await man.isOwner(me, group: group)) {
      Log.info('updating group $group by owner $me');
    } else {
      Log.error('cannot update group name: $group, $text');
      return 'Permission denied';
    }
    // 2. 获取群公告文档
    Bulletin? bulletin = await man.getBulletin(group);
    if (bulletin == null) {
      // TODO: 创建新的群公告？
      assert(false, 'failed to get group document: $group');
      return 'Failed to get group document';
    } else {
      // 克隆文档用于修改（避免修改原对象）
      Document? clone = Document.parse(bulletin.copyMap(false));
      if (clone is Bulletin) {
        bulletin = clone;
      } else {
        assert(false, 'bulletin error: $bulletin, $group');
        return 'Group document error';
      }
    }
    // 2.1. 获取当前用户的签名密钥
    SignKey? sKey = await shared.facebook.getPrivateKeyForVisaSignature(me);
    if (sKey == null) {
      assert(false, 'failed to get sign key for user: $user');
      return 'Failed to get sign key';
    }
    // 2.2. 更新群名称并签名
    bulletin.name = text.trim();
    Uint8List? sig = bulletin.sign(sKey);
    if (sig == null) {
      assert(false, 'failed to sign group document: $bulletin, $me');
      return 'Failed to sign group document';
    }
    // 3. 保存到本地并广播
    var archivist = shared.facebook.archivist;
    var ok = await archivist?.saveDocument(bulletin);
    if (ok == true) {
      Log.warning('group document saved: $group');
    } else {
      assert(false, 'failed to save group document: $bulletin');
      return 'failed to save group document';
    }
    // 广播更新后的群文档
    if (await man.broadcastGroupDocument(bulletin)) {
      Log.warning('group document broadcast: $group');
    } else {
      assert(false, 'failed to broadcast group document: $bulletin');
      return 'Failed to broadcast group document';
    }
    // 操作成功
    return null;
  }

  /// 退出群聊（带确认弹窗）
  /// [context] 上下文
  void quit({required BuildContext context}) {
    // 获取当前用户
    GlobalVariable shared = GlobalVariable();
    shared.facebook.currentUser.then((user) {
      if (!context.mounted) {
        logWarning('context unmounted: $context');
      } else if (user == null) {
        logError('current user not found, failed to add contact: $identifier');
        Alert.show(context, i18nTranslator.translate('Error'), 
          i18nTranslator.translate('Current user not found'));
      } else {
        // 显示确认弹窗
        Alert.confirm(context, i18nTranslator.translate('Confirm'), 
          i18nTranslator.translate('Sure to remove this group?'),
          okAction: () => _doQuit(context, identifier, user.identifier),
        );
      }
    });
  }

  /// 执行退出群聊的具体逻辑
  /// [ctx] 上下文
  /// [group] 群ID
  /// [user] 当前用户ID
  void _doQuit(BuildContext ctx, ID group, ID user) {
    // 1. 退出群聊
    SharedGroupManager man = SharedGroupManager();
    man.quitGroup(group: group).then((out) {
      // 2. 删除群会话
      Amanuensis clerk = Amanuensis();
      clerk.removeConversation(group);
      // 3. 从联系人列表移除
      GlobalVariable shared = GlobalVariable();
      shared.database.removeContact(group, user: user);
      // 关闭当前页面
      if (ctx.mounted) {
        appTool.closePage(ctx);
      }
    }).onError((error, stackTrace) {
      // 显示错误提示
      if (ctx.mounted) {
        Alert.show(ctx, 'Error', '$error');
      }
    });
  }

  /// 从ID创建GroupInfo实例（带初始属性）
  /// [identifier] 群ID
  /// [unread] 未读数
  /// [lastMessage] 最后一条消息
  /// [lastMessageTime] 最后一条消息时间
  /// [mentionedSerialNumber] @我的消息序号
  /// 返回GroupInfo实例
  static GroupInfo from(ID identifier, {
    required int unread,
    required String? lastMessage,
    required DateTime? lastMessageTime,
    required int mentionedSerialNumber,
  }) {
    GroupInfo info = _GroupInfoManager().getGroupInfo(identifier);
    info.unread = unread;
    info.lastMessage = lastMessage;
    info.lastMessageTime = lastMessageTime;
    info.mentionedSerialNumber = mentionedSerialNumber;
    return info;
  }

  /// 从ID创建GroupInfo实例（仅群ID，用户ID返回null）
  /// [identifier] 群ID
  /// 返回GroupInfo实例或null
  static GroupInfo? fromID(ID identifier) {
    if (identifier.isUser) {
      return null;
    }
    return _GroupInfoManager().getGroupInfo(identifier);
  }

  /// 从ID列表创建GroupInfo列表（过滤用户ID）
  /// [contacts] ID列表
  /// 返回GroupInfo列表
  static List<GroupInfo> fromList(List<ID> contacts) {
    List<GroupInfo> array = [];
    _GroupInfoManager man = _GroupInfoManager();
    for (ID item in contacts) {
      if (item.isUser) {
        Log.warning('ignore user conversation: $item');
        continue;
      }
      array.add(man.getGroupInfo(item));
    }
    return array;
  }
}

/// 群管理器（单例）：缓存GroupInfo实例，避免重复创建
class _GroupInfoManager {
  /// 工厂构造函数，保证单例
  factory _GroupInfoManager() => _instance;
  /// 单例实例
  static final _GroupInfoManager _instance = _GroupInfoManager._internal();
  /// 私有构造函数
  _GroupInfoManager._internal();

  /// 群ID到GroupInfo的映射缓存
  final Map<ID, GroupInfo> _contacts = {};

  /// 获取指定ID的GroupInfo实例（缓存不存在则创建）
  /// [identifier] 群ID
  /// 返回GroupInfo实例
  GroupInfo getGroupInfo(ID identifier) {
    GroupInfo? info = _contacts[identifier];
    if (info == null) {
      info = GroupInfo(identifier);
      _contacts[identifier] = info;
      // 加载群数据
      info.reloadData();
    }
    return info;
  }

}