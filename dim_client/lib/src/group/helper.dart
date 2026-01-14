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

import 'package:object_key/object_key.dart';
import 'package:dimsdk/dimsdk.dart';

import '../common/dbi/account.dart';

import 'delegate.dart';

/// 群组命令助手类
/// 负责群组命令的存储、获取和有效性校验
class GroupCommandHelper extends TripletsHelper {
  /// 构造方法
  /// [super.delegate] - 父类初始化，传入群组代理对象
  GroupCommandHelper(super.delegate);

  ///
  /// 群组历史命令相关方法
  ///

  /// 保存群组历史命令
  /// [group] - 群组ID
  /// [content] - 群组命令内容
  /// [rMsg] - 可靠消息
  /// @return 保存成功返回true
  Future<bool> saveGroupHistory(ID group, GroupCommand content, ReliableMessage rMsg) async {
    assert(group == content.group, 'group ID error: $group, $content');
    // 校验命令是否过期，过期则丢弃
    if(await isCommandExpired(content)){
      logWarning('drop expired command: ${content.cmd}, ${rMsg.sender} => $group');
      return false;
    }
    // 检查命令时间
    DateTime? cmdTime = content.time;
    if(cmdTime == null){
      assert(false, 'group command error: $content');
    }else{
      // 校准时间：确保命令时间不会远在未来
      DateTime nearFuture = DateTime.now().add(Duration(minutes: 30));
      if (cmdTime.isAfter(nearFuture)) {
        assert(false, 'group command time error: $cmdTime, $content');
        return false;
      }
    }
    // 更新群组历史
    AccountDBI? db = database;
    if(content is ResetCommand){
      // 重置命令需要清空历史记录
      logWarning('cleaning group history for "reset" command: ${rMsg.sender} => $group');
      await db!.clearGroupMemberHistories(group: group);
    }
    // 保存命令到数据库
    return await db!.saveGroupHistory(content, rMsg, group: group);
  }

  /// 获取群组历史命令列表
  /// [group] - 群组ID
  /// @return 包含命令和可靠消息的配对列表
  Future<List<Pair<GroupCommand,ReliableMessage>>> getGroupHistories(ID group) async{
    AccountDBI? db = database;
    return await db!.getGroupHistories(group:group);
  }

  /// 获取群组重置命令及对应的消息
  /// [group] - 群组ID
  /// @return 包含重置命令和可靠消息的配对对象
  Future<Pair<ResetCommand?,ReliableMessage?>> getResetCommandMessage(ID group) async{
    AccountDBI? db = database;
    return await db!.getResetCommandMessage(group: group);
  }

  /// 清空群成员历史记录
  /// [group] - 群组ID
  /// @return 清空成功返回true
  Future<bool> clearGroupMemberHistories(ID group) async{
    AccountDBI? db = database;
    return await db!.clearGroupMemberHistories(group: group);
  }

  /// 清空群管理员历史记录
  /// [group] - 群组ID
  /// @return 清空成功返回true
  Future<bool> clearGroupAdminHistories(ID group) async{
    AccountDBI? db = database;
    return await db!.clearGroupAdminHistories(group: group);
  }

  /// 校验命令是否过期
  /// （所有收到的群组命令必须晚于缓存的reset命令）
  /// [content] - 群组命令
  /// @return 过期返回true
  Future<bool> isCommandExpired(GroupCommand content) async{
    ID? group = content.group;
    if(group == null){
      assert(false, 'group content error: $content');
      return true;
    }
    if(content is ResetCommand){
      // 管理员辞职命令：对比文档时间
      Bulletin? doc = await delegate.getBulletin(group);
      if(doc == null){
        assert(false, 'group document not exists: $group');
        return true;
      }
      return DocumentUtils.isBefore(doc.time, content.time);
    }
    // 成员相关命令：对比reset命令时间
    Pair<ResetCommand?,ReliableMessage?> pair = await getResetCommandMessage(group);
    ResetCommand? cmd = pair.first;
    if(cmd == null){
      return false;
    }
    return DocumentUtils.isBefore(cmd.time, content.time);
  }

  /// 从命令中提取成员列表
  /// [content] - 群组命令
  /// @return 成员ID列表
  Future<List<ID>> getMembersFromCommand(GroupCommand content) async{
    // 先从‘members’字段获取
    List<ID>? members = content.members;
    if(members == null){
      members = [];
      // 再从'member'字段获取（单个成员）
      ID? single = content.member;
      if(single != null){
        members.add(single);
      }
    }
    return members;
  }
}