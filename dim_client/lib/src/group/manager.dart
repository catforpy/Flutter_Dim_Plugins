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

import 'package:dimsdk/dimsdk.dart';

import '../common/register.dart';
import '../common/messenger.dart';

import 'delegate.dart';
import 'helper.dart';
import 'builder.dart';
import 'packer.dart';

/// 群组管理器
/// 负责群组的创建、成员管理（重置/邀请/退出）等核心操作
class GroupManager extends TripletsHelper {
  /// 构造方法
  /// [super.delegate] - 父类初始化，传入群组代理对象
  GroupManager(super.delegate);

  // 群组打包器（懒加载）
  late final GroupPacker packer = createPacker();
  // 群组命令助手（懒加载）
  late final GroupCommandHelper helper = createHelper();
  // 群组历史构建器（懒加载）
  late final GroupHistoryBuilder builder = createBuilder();

  /// 创建群组打包器（可重写以自定义实现）
  GroupPacker createPacker() => GroupPacker(delegate);

  /// 创建群组命令助手（可重写以自定义实现）
  GroupCommandHelper createHelper() => GroupCommandHelper(delegate);

  /// 创建群组历史构建器（可重写以自定义实现）
  GroupHistoryBuilder createBuilder() => GroupHistoryBuilder(delegate);

  /// 创建新群组（包含初始成员）
  /// （将文档和成员信息广播给所有成员和相邻节点）
  /// [members] - 初始群成员列表
  /// @return 新创建的群组ID（失败返回null）
  Future<ID?> createGroup(List<ID> members) async {
    assert(members.length > 1, 'not enough members: $members');

    //
    //  0. 获取当前登录用户
    //
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return null;
    }
    ID founder = user.identifier;

    //
    //  1. 检查创建者（群主）
    //
    int pos = members.indexOf(founder);
    if (pos < 0) {
      // 不在成员列表中，添加到首位
      members.insert(0, founder);
    } else if (pos > 0) {
      // 在列表中但不在首位，移到首位
      members.removeAt(pos);
      members.insert(0, founder);
    }
    // 构建群组名称
    String title = await delegate.buildGroupName(members);

    //
    //  2. 创建群组（带名称）
    //
    Register register = Register(database!);
    ID group = await register.createGroup(founder, name: title);
    logInfo('new group: $group ($title), founder: $founder');

    //
    //  3. 上传元数据和文档到相邻节点
    //  讨论：是否需要让相邻节点知道群组信息？
    //
    Meta? meta = await delegate.getMeta(group);
    Bulletin? doc = await delegate.getBulletin(group);
    Command content;
    if (doc != null) {
      // 有文档则创建文档相应命令
      content = DocumentCommand.response(group, meta, [doc]);
    } else {
      assert(false, 'failed to get group info: $group');
      return null;
    }
    // 发送到任意节点
    bool ok = await _sendCommand(content, receiver: Station.ANY);
    assert(ok, 'failed to upload meta/document to neighbor station');

    //
    //  4. 创建并广播包含新成员的reset命令
    //
    if (await resetMembers(members, group: group)) {
      logInfo('created group $group with ${members.length} members');
    } else {
      logError('failed to create group $group with ${members.length} members');
    }

    return group;
  }

  // 讨论：是否需要让相邻节点知道群组信息？
  //
  //      (A) 如果这样做，好处是：
  //          当有人收到未知群组的消息时，
  //          可以立即从相邻节点查询群组信息；
  //          潜在风险是：非群成员也能知道群组信息
  //          （仅群组ID、名称、管理员等）。
  //
  //      (B) 如果不这样做，
  //          则必须由群成员自己共享群组信息；
  //          如果所有成员都不在线，
  //          则无法立即获取最新信息，直到有人上线。

  /// 重置群成员列表
  /// （将新的群组历史广播给所有成员）
  /// [group] - 群组ID
  /// [newMembers] - 新的成员列表
  /// @return 操作成功返回true
  Future<bool> resetMembers(List<ID> newMembers, {required ID group}) async {
    assert(
      group.isGroup && newMembers.isNotEmpty,
      'params error: $group, $newMembers',
    );

    //
    //  0. 获取当前登录用户
    //
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;

    // 检查成员列表：首位必须是群主
    ID first = newMembers.first;
    bool ok = await delegate.isOwner(first, group: group);
    if (!ok) {
      assert(false, 'group owner must be the first member: $group');
      return false;
    }
    // 获取旧成员列表，找出被移除的成员
    List<ID> oldMembers = await delegate.getMembers(group);
    List<ID> expelList = [];
    for(ID item in oldMembers){
      if(!newMembers.contains(item)){
        expelList.add(item);
      }
    }

    //
    //  1. 权限校验
    //
    bool isOwner = me == first;
    bool isAdmin = await delegate.isAdministrator(me, group: group);
    bool isBot = await delegate.isAssistant(me, group: group);
    bool canReset = isOwner || isAdmin;
    if(!canReset){
      assert(false, 'cannot reset members of group: $group');
      return false;
    }
    // 只有群主或管理员能重置成员，机器人不行
    assert(!isBot, 'group bot cannot reset members: $group, $me');

    //
    //  2. 构建reset命令
    //
    var pair = await builder.buildResetCommand(group,newMembers);
    ResetCommand? reset = pair.first;
    ReliableMessage? rMsg = pair.second;
    if (reset == null || rMsg == null) {
      assert(false, 'failed to build "reset" command for group: $group');
      return false;
    }

    //
    //  3. 保存reset命令并更新成员列表
    //
    if(!await helper.saveGroupHistory(group, reset, rMsg)){
      assert(false, 'failed to save "reset" command for group: $group');
      return false;
    }else if(!await delegate.saveMembers(newMembers, group)){
      assert(false, 'failed to update members of group: $group');
      return false;
    }else{
      logInfo('group members updated: $group, ${newMembers.length}');
    }

    //
    //  4. 转发所有群组历史
    //
    List<ReliableMessage> messages = await builder.buildGroupHistories(group);
    ForwardContent forward = ForwardContent.create(secrets: messages);

    List<ID> bots = await delegate.getAssistants(group);
    if (bots.isNotEmpty) {
      // 存在机器人，发送给所有机器人（让其知道最新成员列表）
      return await _sendCommand(forward, members: bots);
    } else {
      // 无机器人，分别发送给新成员和被移除成员
      await _sendCommand(forward, members: newMembers);
      await _sendCommand(forward, members: expelList);
    }

    return true;
  }

  /// 邀请新成员加入群组
  /// [group] - 群组ID
  /// [newMembers] - 待邀请的成员列表
  /// @return 操作成功返回true
  Future<bool> inviteMembers(List<ID> newMembers, {required ID group}) async {
    assert(group.isGroup && newMembers.isNotEmpty, 'params error: $group, $newMembers');

    //
    //  0. 获取当前登录用户
    //
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;

    // 获取旧成员列表
    List<ID> oldMembers = await delegate.getMembers(group);

    // 校验身份
    bool isOwner = await delegate.isOwner(me, group: group);
    bool isAdmin = await delegate.isAdministrator(me, group: group);
    bool isMember = await delegate.isMember(me, group: group);

    //
    //  1. 权限校验
    //
    bool canReset = isOwner || isAdmin;
    if(canReset){
      // 群主/管理员：追加新成员并重置群组
      List<ID> members = [...oldMembers];
      for(ID item in newMembers){
        if(!members.contains(item)){
          members.add(item);
        }
      }
      return resetMembers(members, group: group);
    }else if(!isMember){
      // 非群成员无权限邀请
      assert(false, 'cannot invite member into group: $group');
      return false;
    }
    // 普通成员邀请

    //
    //  2. 构建invite命令
    //
    InviteCommand invite = GroupCommand.invite(group,members: newMembers);
    ReliableMessage? rMsg = await packer.packMessage(invite, sender: me);
    if (rMsg == null) {
      assert(false, 'failed to build "invite" command for group: $group');
      return false;
    } else if (!await helper.saveGroupHistory(group, invite, rMsg)) {
      assert(false, 'failed to save "invite" command for group: $group');
      return false;
    }
    // 创建转发内容
    ForwardContent forward = ForwardContent.create(forward: rMsg);

    //
    //  3. 转发群组命令
    //
    List<ID> bots = await delegate.getAssistants(group);
    if (bots.isNotEmpty) {
      // 存在机器人，发送给所有机器人
      return await _sendCommand(forward, members: bots);
    }

    // 无机器人，转发给旧成员
    await _sendCommand(forward, members: oldMembers);

    // 转发所有群组历史给新成员
    List<ReliableMessage> messages = await builder.buildGroupHistories(group);
    forward = ForwardContent.create(secrets: messages);

    await _sendCommand(forward, members: newMembers);
    return true;
  }

  /// 退出群组
  /// （广播quit命令给所有成员）
  /// [group] - 群组ID
  /// @return 操作成功返回true
  Future<bool> quitGroup({required ID group}) async {
    assert(group.isGroup, 'group ID error: $group');

    //
    //  0. 获取当前登录用户
    //
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;

    // 获取群成员列表
    List<ID> members = await delegate.getMembers(group);
    assert(members.isNotEmpty, 'failed to get members for group: $group');

    // 校验身份
    bool isOwner = await delegate.isOwner(me, group: group);
    bool isAdmin = await delegate.isAdministrator(me, group: group);
    bool isBot = await delegate.isAssistant(me, group: group);
    bool isMember = members.contains(me);

    //
    //  1. 权限校验
    //
    if (isOwner) {
      assert(false, 'owner cannot quit from group: $group');
      return false;
    } else if (isAdmin) {
      assert(false, 'administrator cannot quit from group: $group');
      return false;
    }
    assert(!isBot, 'group bot cannot quit: $group, $me');

    //
    //  2. 更新本地存储
    //
    if(isMember){
      logWarning('quitting group: $group, $me');
      //创建members列表的独立副本，后面是修改的这个独立副本
      members = [...members];
      members.remove(me);
      bool ok = await delegate.saveMembers(members, group);
      assert(ok, 'failed to save members for group: $group');
    }else {
      logWarning('member not in group: $group, $me');
    }

    //
    //  3. 构建quit命令
    //
    Command content = GroupCommand.quit(group);
    ReliableMessage? rMsg = await packer.packMessage(content, sender: me);
    if (rMsg == null) {
      assert(false, 'failed to pack group message: $group');
      return false;
    }
    ForwardContent forward = ForwardContent.create(forward: rMsg);

    //
    //  4. 转发quit命令
    //
    List<ID> bots = await delegate.getAssistants(group);
    if (bots.isNotEmpty) {
      // 存在机器人，发送给机器人
      return await _sendCommand(forward, members: bots);
    } else {
      // 无机器人，直接发送给所有成员
      return await _sendCommand(forward, members: members);
    }
  }

  /// 发送命令到指定接收者/成员列表
  /// [content] - 要发送的命令内容
  /// [receiver] - 单个接收者（与members二选一）
  /// [members] - 接收者列表（与receiver二选一）
  /// @return 发送成功返回true
  Future<bool> _sendCommand(Content content, {ID? receiver, List<ID>? members}) async {
    // 参数处理：receiver和members二选一
    if (receiver != null) {
      assert(members == null, 'params error: $receiver, $members');
      members = [receiver];
    } else if (members == null) {
      assert(false, 'params error');
      return false;
    }
    // 1.获取发送者（当前用户）
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'should not happen: $user');
      return false;
    }
    ID me = user.identifier;
    // 2. 逐个发送给接收者
    CommonMessenger? transceiver = messenger;
    for(ID receiver in members){
      if(me == receiver){
        logInfo('skip cycled message: $me => $receiver');
        continue;
      }
      await transceiver?.sendContent(content, sender: me, receiver: receiver);
    }
    return true;
  }
}
