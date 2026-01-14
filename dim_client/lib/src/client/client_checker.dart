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
import 'package:object_key/object_key.dart';

import '../common/protocol/groups.dart';
import '../common/checker.dart';
import '../common/facebook.dart';
import '../common/messenger.dart';
import '../common/session.dart';

/// 客户端实体检查器
/// 核心功能：查询缺失的Meta、Document、群成员信息，确保通信所需的实体数据完整
class ClientChecker extends EntityChecker {
  /// 构造方法
  /// [facebook]：用户/群组信息管理类（弱引用）
  /// [database]：数据库接口
  ClientChecker(CommonFacebook facebook, super.database)
    : _barrack = WeakReference(facebook);

  /// Facebook弱引用（避免内存泄漏）
  final WeakReference<CommonFacebook> _barrack;

  /// Messenger弱引用（避免内存泄漏）
  WeakReference<CommonMessenger>? _transceiver;

  // 受保护方法：获取Facebook实例
  CommonFacebook? get facebook => _barrack.target;

  // 受保护方法：获取Messenger实例
  CommonMessenger? get messenger => _transceiver?.target;
  // 公开方法：设置Messenger实例
  set messenger(CommonMessenger? delegate) =>
      _transceiver = delegate == null ? null : WeakReference(delegate);

  /// 查询指定ID的Meta信息
  /// [identifier]：用户/群组ID
  /// 返回：是否成功发送查询命令
  @override
  Future<bool> queryMeta(ID identifier) async {
    // 获取消息发送器
    Transmitter? transmitter = messenger;
    if (transmitter == null) {
      logWarning('messenger not ready yet');
      return false;
    }
    // 检查查询是否过期（避免频繁查询）
    if (!isMetaQueryExpired(identifier)) {
      logInfo('meta query not expired yet: $identifier');
      return false;
    }
    logInfo('querying meta for: $identifier');
    // 创建Meta查询命令
    var content = MetaCommand.query(identifier);
    // 发送查询命令到任意节点
    var pair = await transmitter.sendContent(
      content,
      sender: null,
      receiver: Station.ANY,
      priority: 1,
    );
    // 返回是否发送成功
    return pair.second != null;
  }

  /// 查询指定ID的Document信息
  /// [identifier]：用户/群组ID
  /// [documents]：已有的文档列表（用于对比更新时间）
  /// 返回：是否成功发送查询命令
  @override
  Future<bool> queryDocuments(ID identifier, List<Document> documents) async {
    Transmitter? transmitter = messenger;
    if (transmitter == null) {
      logWarning('messenger not ready yet');
      return false;
    }
    // 检查查询是否过期
    if (!isDocumentQueryExpired(identifier)) {
      logInfo('document query not expired yet: $identifier');
      return false;
    }
    // 获取最后更新时间
    DateTime? lastTime = getLastDocumentTime(identifier, documents);
    logInfo('querying documents for: $identifier, last time: $lastTime');
    // 创建Document查询命令
    var content = DocumentCommand.query(identifier, lastTime);
    // 发送查询命令到任意节点
    var pair = await transmitter.sendContent(
      content,
      sender: null,
      receiver: Station.ANY,
      priority: 1,
    );
    return pair.second != null;
  }

  /// 查询群组成员
  /// [group]：群组ID
  /// [members]：已有的成员列表
  /// 返回：是否成功发送查询命令
  @override
  Future<bool> queryMembers(ID group, List<ID> members) async {
    // 获取当前用户
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    Transmitter? transmitter = messenger;
    if (transmitter == null) {
      logWarning('messenger not ready yet');
      return false;
    }
    // 检查查询是否过期
    if (!isMembersQueryExpired(group)) {
      logInfo('members query not expired yet: $group');
      return false;
    }
    ID me = user.identifier;
    // 获取群组最后更新时间
    DateTime? lastTime = await getLastGroupHistoryTime(group);
    logInfo('querying members for group: $group, last time: $lastTime');
    // 构建群成员查询命令（TODO：后续替换为GroupHistory.queryGroupHistory）
    Content command = QueryCommand.query(group, lastTime);
    bool ok;
    // 1. 向群机器人查询
    ok = await queryMembersFromAssistants(command, sender: me, group: group);
    if (ok) {
      return true;
    }
    // 2. 向群管理员查询
    ok = await queryMembersFromAdministrators(
      command,
      sender: me,
      group: group,
    );
    if (ok) {
      return true;
    }
    // 3. 向群主查询
    ok = await queryMembersFromOwner(command, sender: me, group: group);
    if (ok) {
      return true;
    }
    Pair<InstantMessage, ReliableMessage?>? pair;
    // 所有方式失败，尝试向最后活跃成员查询
    ID? lastMember = await getLastActiveMember(group: group);
    if (lastMember != null) {
      logInfo('querying members from: $lastMember, group: $group');
      pair = await transmitter.sendContent(
        command,
        sender: me,
        receiver: lastMember,
        priority: 1,
      );
    }
    logError('group not ready: $group');
    return pair?.second != null;
  }

  // 受保护方法：向群机器人查询成员
  Future<bool> queryMembersFromAssistants(
    Content command, {
    required ID sender,
    required ID group,
  }) async {
    // 获取群奇迹人列表
    List<ID>? bots = await facebook?.getAssistants(group);
    if (bots == null || bots.isEmpty) {
      logWarning('assistants not designated for group: $group');
      return false;
    }
    int success = 0;
    Pair<InstantMessage, ReliableMessage?>? pair;
    logInfo('querying members from bots: $bots, group: $group');
    // 遍历机器人发送查询命令
    for (ID receiver in bots) {
      if (sender == receiver) {
        logWarning('ignore cycled querying: $sender, group: $group');
        continue;
      }
      pair = await messenger?.sendContent(
        command,
        sender: sender,
        receiver: receiver,
        priority: 1,
      );
      if (pair?.second != null) {
        success += 1;
      }
    }
    if (success == 0) {
      return false;
    }
    // 额外向最后活跃成员发送查询（如果不是机器人）
    ID? lastMember = getLastActiveMember(group: group);
    if (lastMember == null || bots.contains(lastMember)) {
      // 最后活跃成员是机器人，无需重复发送
    } else {
      logInfo('querying members from: $lastMember, group: $group');
      await messenger?.sendContent(
        command,
        sender: sender,
        receiver: lastMember,
        priority: 1,
      );
    }
    return true;
  }

  // 受保护方法：向群管理员查询成员
  Future<bool> queryMembersFromAdministrators(
    Content command, {
    required ID sender,
    required ID group,
  }) async {
    // 获取群管理员列表
    List<ID>? admins = await facebook?.getAdministrators(group);
    if (admins == null || admins.isEmpty) {
      logWarning('administrators not found for group: $group');
      return false;
    }
    int success = 0;
    Pair<InstantMessage, ReliableMessage?>? pair;
    logInfo('querying members from admins: $admins, group: $group');
    // 遍历管理员发送查询命令
    for (ID receiver in admins) {
      if (sender == receiver) {
        logWarning('ignore cycled querying: $sender, group: $group');
        continue;
      }
      pair = await messenger?.sendContent(
        command,
        sender: sender,
        receiver: receiver,
        priority: 1,
      );
      if (pair?.second != null) {
        success += 1;
      }
    }
    if (success == 0) {
      return false;
    }
    // 额外想最后活跃成员发送查询（如果不是管理员）
    ID? lastMember = getLastActiveMember(group: group);
    if (lastMember == null || admins.contains(lastMember)) {
      // 最后活跃成员是管理员，无需重复发送
    } else {
      logInfo('querying members from: $lastMember, group: $group');
      await messenger?.sendContent(
        command,
        sender: sender,
        receiver: lastMember,
        priority: 1,
      );
    }
    return true;
  }

  // 受保护方法：向群主查询成员
  Future<bool> queryMembersFromOwner(
    Content command, {
    required ID sender,
    required ID group,
  }) async {
    // 获取群主
    ID? owner = await facebook?.getOwner(group);
    if (owner == null) {
      logWarning('owner not found for group: $group');
      return false;
    } else if (owner == sender) {
      logError('you are the owner of group: $group');
      return false;
    }
    Pair<InstantMessage, ReliableMessage?>? pair;
    logInfo('querying members from owner: $owner, group: $group');
    // 向群主发送查询命令
    pair = await messenger?.sendContent(
      command,
      sender: sender,
      receiver: owner,
      priority: 1,
    );
    if (pair?.second == null) {
      return false;
    }
    // 额外向最后活跃成员发送查询（如果不是群主）
    ID? lastMember = getLastActiveMember(group: group);
    if (lastMember == null || lastMember == owner) {
      // 最后活跃成员是群主，无需重复发送
    } else {
      logInfo('querying members from: $lastMember, group: $group');
      messenger?.sendContent(
        command,
        sender: sender,
        receiver: lastMember,
        priority: 1,
      );
    }
    return true;
  }

  /// 向联系人发送Visa文档
  /// [visa]：要发送的Visa文档
  /// [contact]：接收者ID
  /// [updated]：是否是更新后的文档（强制发送）
  /// 返回：是否发送成功
  @override
  Future<bool> sendVisa(Visa visa, ID contact, {bool updated = false}) async {
    ID me = visa.identifier;
    if (me == contact) {
      logWarning('skip cycled message: $contact, $visa');
      return false;
    }
    Transmitter? transmitter = messenger;
    if (transmitter == null) {
      logWarning('messenger not ready yet');
      return false;
    }
    // 检查是否需要发送（避免频繁发送）
    if (!isDocumentResponseExpired(contact, updated)) {
      logDebug('visa response not expired yet: $contact');
      return false;
    }
    logDebug('push visa document: $me => $contact');
    // 创建Document响应命令
    DocumentCommand command = DocumentCommand.response(me, null, [visa]);
    // 发送Visa文档
    var res = await transmitter.sendContent(
      command,
      sender: me,
      receiver: contact,
      priority: 1,
    );
    return res.second != null;
  }
}
