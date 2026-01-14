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

import 'package:dim_client/ok.dart'; // DIM-SDK基础工具（日志/异步）
import 'package:dim_client/sdk.dart'; // DIM-SDK核心库（数据模型/接口）
import 'package:dim_client/common.dart'; // DIM-SDK通用数据库接口

import '../common/dbi/app.dart'; // 应用自定义信息数据库接口
import '../common/dbi/contact.dart'; // 联系人数据库接口
import '../common/dbi/message.dart'; // 消息数据库接口
import '../common/dbi/network.dart'; // 网络（服务器/测速）数据库接口

import '../models/chat.dart'; // 聊天会话模型

import '../sqlite/app.dart'; // SQLite-应用自定义信息实现

import '../sqlite/contact.dart'; // SQLite-联系人实现
import '../sqlite/conversation.dart'; // SQLite-会话实现
import '../sqlite/document.dart'; // SQLite-文档实现
import '../sqlite/group.dart'; // SQLite-群组实现
import '../sqlite/group_history.dart'; // SQLite-群组历史实现
import '../sqlite/keys.dart'; // SQLite-密钥实现
import '../sqlite/login.dart'; // SQLite-登录实现
import '../sqlite/message.dart'; // SQLite-消息实现
import '../sqlite/meta.dart'; // SQLite-元数据实现
import '../sqlite/service.dart'; // SQLite-服务实现
import '../sqlite/speed.dart'; // SQLite-测速实现
import '../sqlite/station.dart'; // SQLite-服务器实现
import '../sqlite/trace.dart'; // SQLite-追踪实现
import '../sqlite/user.dart'; // SQLite-用户实现

import '../sqlite/alias.dart'; // SQLite-备注实现
import '../sqlite/blocked.dart'; // SQLite-黑名单实现
import '../sqlite/muted.dart'; // SQLite-静音列表实现

/// 共享数据库封装类：统一管理所有SQLite数据库表实例，实现多数据库接口
/// 核心作用：
/// 1. 聚合所有数据库表实例，提供统一的访问入口
/// 2. 实现DIM-SDK定义的所有数据库接口，适配SDK数据存储规范
/// 3. 封装常用的增删改查方法，简化上层调用
class SharedDatabase
    implements
        AccountDBI,
        SessionDBI,
        MessageDBI,
        AppCustomizedInfoDBI,
        ConversationDBI,
        InstantMessageDBI,
        TraceDBI,
        RemarkDBI,
        BlockedDBI,
        MutedDBI,
        SpeedDBI {
  // ===================== 账户相关表实例 =====================
  final PrivateKeyDBI privateKeyTable = PrivateKeyCache(); // 私钥表
  final MetaDBI metaTable = MetaCache(); // 元数据表
  final DocumentDBI documentTable = DocumentCache(); // 文档表

  final UserCache userTable = UserCache(); // 用户表
  final ContactCache contactTable = ContactCache(); // 联系人表

  final GroupCache groupTable = GroupCache(); // 群组表
  final GroupHistoryDBI groupHistoryTable = GroupHistoryCache(); // 群组历史表

  final RemarkDBI remarkTable = RemarkCache(); // 备注表
  final BlockedDBI blockedTable = BlockedCache(); // 黑名单表
  final MutedDBI mutedTable = MutedCache(); // 静音列表表

  // ===================== 会话相关表实例 =====================
  final LoginDBI loginTable = LoginCommandCache(); // 登录命令表
  final ProviderDBI providerTable = ProviderCache(); // 服务提供商表
  final StationDBI stationTable = StationCache(); // 服务器表
  final SpeedDBI speedTable = SpeedTable(); // 测速记录表

  // ===================== 消息相关表实例 =====================
  final CipherKeyDBI msgKeyTable = MsgKeyCache(); // 消息加密密钥表
  final InstantMessageTable instantMessageTable =
      InstantMessageTable(); // 即时消息表
  final TraceDBI traceTable = TraceTable(); // 消息追踪表
  final ConversationCache conversationTable = ConversationCache(); // 会话表

  // ===================== 其他核心实例 =====================
  final NotificationCenter _center = NotificationCenter(); // 通知中心
  NotificationCenter get center => _center; // 通知中心访问器

  final AppCustomizedInfoDBI appInfoTable = CustomizedInfoCache(); // 应用自定义信息表

  // ===================== 私钥表接口实现 =====================
  @override
  Future<bool> savePrivateKey(
    PrivateKey key,
    String type,
    ID user, {
    int sign = 1,
    required int decrypt,
  }) async => await privateKeyTable.savePrivateKey(
    key,
    type,
    user,
    sign: sign,
    decrypt: decrypt,
  );

  @override
  Future<List<DecryptKey>> getPrivateKeysForDecryption(ID user) async =>
      await privateKeyTable.getPrivateKeysForDecryption(user);

  @override
  Future<PrivateKey?> getPrivateKeyForSignature(ID user) async =>
      await privateKeyTable.getPrivateKeyForSignature(user);

  @override
  Future<PrivateKey?> getPrivateKeyForVisaSignature(ID user) async =>
      await privateKeyTable.getPrivateKeyForVisaSignature(user);

  // ===================== 元数据表接口实现 =====================
  @override
  Future<bool> saveMeta(Meta meta, ID entity) async =>
      await metaTable.saveMeta(meta, entity);

  @override
  Future<Meta?> getMeta(ID entity) async => await metaTable.getMeta(entity);

  // ===================== 文档表接口实现 =====================
  @override
  Future<bool> saveDocument(Document doc) async =>
      await documentTable.saveDocument(doc);

  @override
  Future<List<Document>> getDocuments(ID entity) async =>
      await documentTable.getDocuments(entity);

  // ===================== 用户表接口实现 =====================
  @override
  Future<List<ID>> getLocalUsers() async => await userTable.getLocalUsers();

  @override
  Future<bool> saveLocalUsers(List<ID> users) async =>
      await userTable.saveLocalUsers(users);

  Future<bool> addUser(ID user) async => await userTable.addUser(user);

  Future<bool> removeUser(ID user) async => await userTable.removeUser(user);

  Future<bool> setCurrentUser(ID user) async =>
      await userTable.setCurrentUser(user);

  Future<ID?> getCurrentUser() async => await userTable.getCurrentUser();

  // ===================== 联系人表接口实现 =====================
  @override
  Future<List<ID>> getContacts({required ID user}) async =>
      await contactTable.getContacts(user: user);

  @override
  Future<bool> saveContacts(List<ID> contacts, {required ID user}) async =>
      await contactTable.saveContacts(contacts, user: user);

  Future<bool> addContact(ID contact, {required ID user}) async =>
      await contactTable.addContact(contact, user: user);

  Future<bool> removeContact(ID contact, {required ID user}) async =>
      await contactTable.removeContact(contact, user: user);

  // ===================== 备注表接口实现 =====================
  @override
  Future<ContactRemark?> getRemark(ID contact, {required ID user}) async =>
      await remarkTable.getRemark(contact, user: user);

  @override
  Future<bool> setRemark(ContactRemark remark, {required ID user}) async =>
      await remarkTable.setRemark(remark, user: user);

  // ===================== 黑名单表接口实现 =====================
  @override
  Future<List<ID>> getBlockList({required ID user}) async =>
      await blockedTable.getBlockList(user: user);

  @override
  Future<bool> saveBlockList(List<ID> contacts, {required ID user}) async =>
      await blockedTable.saveBlockList(contacts, user: user);

  @override
  Future<bool> addBlocked(ID contact, {required ID user}) async =>
      await blockedTable.addBlocked(contact, user: user);

  @override
  Future<bool> removeBlocked(ID contact, {required ID user}) async =>
      await blockedTable.removeBlocked(contact, user: user);

  // ===================== 静音列表表接口实现 =====================
  @override
  Future<List<ID>> getMuteList({required ID user}) async =>
      await mutedTable.getMuteList(user: user);

  @override
  Future<bool> saveMuteList(List<ID> contacts, {required ID user}) async =>
      await mutedTable.saveMuteList(contacts, user: user);

  @override
  Future<bool> addMuted(ID contact, {required ID user}) async =>
      await mutedTable.addMuted(contact, user: user);

  @override
  Future<bool> removeMuted(ID contact, {required ID user}) async =>
      await mutedTable.removeMuted(contact, user: user);

  // ===================== 群组表接口实现 =====================
  @override
  Future<ID?> getFounder({required ID group}) async =>
      await groupTable.getFounder(group: group);

  @override
  Future<ID?> getOwner({required ID group}) async =>
      await groupTable.getOwner(group: group);

  @override
  Future<List<ID>> getMembers({required ID group}) async =>
      await groupTable.getMembers(group: group);

  @override
  Future<bool> saveMembers(List<ID> members, {required ID group}) async =>
      await groupTable.saveMembers(members, group: group);

  Future<bool> addMember(ID member, {required ID group}) async =>
      await groupTable.addMember(member, group: group);

  Future<bool> removeMember(ID member, {required ID group}) async =>
      await groupTable.removeMember(member, group: group);

  @override
  Future<List<ID>> getAssistants({required ID group}) async =>
      await groupTable.getAssistants(group: group);

  @override
  Future<bool> saveAssistants(List<ID> bots, {required ID group}) async =>
      await groupTable.saveAssistants(bots, group: group);

  @override
  Future<List<ID>> getAdministrators({required ID group}) async =>
      await groupTable.getAdministrators(group: group);

  @override
  Future<bool> saveAdministrators(
    List<ID> members, {
    required ID group,
  }) async => await groupTable.saveAdministrators(members, group: group);

  Future<bool> removeGroup({required ID group}) async =>
      await groupTable.removeGroup(group: group);

  // ===================== 群组历史表接口实现 =====================
  @override
  Future<bool> saveGroupHistory(
    GroupCommand content,
    ReliableMessage rMsg, {
    required ID group,
  }) async =>
      await groupHistoryTable.saveGroupHistory(content, rMsg, group: group);

  @override
  Future<List<Pair<GroupCommand, ReliableMessage>>> getGroupHistories({
    required ID group,
  }) async => await groupHistoryTable.getGroupHistories(group: group);

  @override
  Future<Pair<ResetCommand?, ReliableMessage?>> getResetCommandMessage({
    required ID group,
  }) async => await groupHistoryTable.getResetCommandMessage(group: group);

  @override
  Future<bool> clearGroupAdminHistories({required ID group}) async =>
      await groupHistoryTable.clearGroupAdminHistories(group: group);

  @override
  Future<bool> clearGroupMemberHistories({required ID group}) async =>
      await groupHistoryTable.clearGroupMemberHistories(group: group);

  // ===================== 登录命令表接口实现 =====================
  @override
  Future<Pair<LoginCommand?, ReliableMessage?>> getLoginCommandMessage(
    ID identifier,
  ) async => await loginTable.getLoginCommandMessage(identifier);

  @override
  Future<bool> saveLoginCommandMessage(
    ID identifier,
    LoginCommand content,
    ReliableMessage rMsg,
  ) async =>
      await loginTable.saveLoginCommandMessage(identifier, content, rMsg);

  // ===================== 服务提供商表接口实现 =====================
  @override
  Future<List<ProviderInfo>> allProviders() async =>
      await providerTable.allProviders();

  @override
  Future<bool> addProvider(ID identifier, {int chosen = 0}) async =>
      await providerTable.addProvider(identifier, chosen: chosen);

  @override
  Future<bool> updateProvider(ID identifier, {int chosen = 0}) async =>
      await providerTable.updateProvider(identifier, chosen: chosen);

  @override
  Future<bool> removeProvider(ID identifier) async =>
      await providerTable.removeProvider(identifier);

  // ===================== 服务器表接口实现 =====================
  @override
  Future<List<StationInfo>> allStations({required ID provider}) async =>
      await stationTable.allStations(provider: provider);

  @override
  Future<bool> addStation(
    ID? sid, {
    int chosen = 0,
    required String host,
    required int port,
    required ID provider,
  }) async => await stationTable.addStation(
    sid,
    chosen: chosen,
    host: host,
    port: port,
    provider: provider,
  );

  @override
  Future<bool> updateStation(
    ID? sid, {
    int chosen = 0,
    required String host,
    required int port,
    required ID provider,
  }) async => await stationTable.updateStation(
    sid,
    chosen: chosen,
    host: host,
    port: port,
    provider: provider,
  );

  @override
  Future<bool> removeStation({
    required String host,
    required int port,
    required ID provider,
  }) async => await stationTable.removeStation(
    host: host,
    port: port,
    provider: provider,
  );

  @override
  Future<bool> removeStations({required ID provider}) async =>
      await stationTable.removeStations(provider: provider);

  // ===================== 测速记录表接口实现 =====================
  @override
  Future<List<SpeedRecord>> getSpeeds(String host, int port) async =>
      await speedTable.getSpeeds(host, port);

  @override
  Future<bool> addSpeed(
    String host,
    int port, {
    required ID identifier,
    required DateTime time,
    required double duration,
    required String? socketAddress,
  }) async => await speedTable.addSpeed(
    host,
    port,
    identifier: identifier,
    time: time,
    duration: duration,
    socketAddress: socketAddress,
  );

  @override
  Future<bool> removeExpiredSpeed(DateTime? expired) async =>
      await speedTable.removeExpiredSpeed(expired);

  // ===================== 消息加密密钥表接口实现 =====================
  @override
  Future<SymmetricKey?> getCipherKey({
    required ID sender,
    required ID receiver,
    bool generate = false,
  }) async => await msgKeyTable.getCipherKey(
    sender: sender,
    receiver: receiver,
    generate: generate,
  );

  @override
  Future<void> cacheCipherKey({
    required ID sender,
    required ID receiver,
    required SymmetricKey key,
  }) async => await msgKeyTable.cacheCipherKey(
    sender: sender,
    receiver: receiver,
    key: key,
  );

  @override
  Map getGroupKeys({required ID group, required ID sender}) {
    // TODO: 待实现群组密钥获取逻辑
    Log.error('implement getGroupKeys: $group');
    return {};
  }

  @override
  bool saveGroupKeys({
    required ID group,
    required ID sender,
    required Map keys,
  }) {
    // TODO: 待实现群组密钥保存逻辑
    Log.error('implement saveGroupKeys: $group');
    return true;
  }

  // ===================== 即时消息表接口实现 =====================
  @override
  Future<Pair<List<InstantMessage>, int>> getInstantMessages(
    ID chat, {
    int start = 0,
    int? limit,
  }) async => await instantMessageTable.getInstantMessages(
    chat,
    start: start,
    limit: limit,
  );

  @override
  Future<bool> saveInstantMessage(ID chat, InstantMessage iMsg) async =>
      await instantMessageTable.saveInstantMessage(chat, iMsg);

  @override
  Future<bool> removeInstantMessage(
    ID chat,
    Envelope envelope,
    Content content,
  ) async =>
      await instantMessageTable.removeInstantMessage(chat, envelope, content);

  @override
  Future<bool> removeInstantMessages(ID chat) async =>
      await instantMessageTable.removeInstantMessages(chat);

  Future<int> burnMessages(DateTime expired) async =>
      await instantMessageTable.burnMessages(expired);

  // ===================== 会话表接口实现 =====================
  @override
  Future<List<Conversation>> getConversations() async =>
      await conversationTable.getConversations();

  @override
  Future<bool> addConversation(Conversation chat) async =>
      await conversationTable.addConversation(chat);

  @override
  Future<bool> updateConversation(Conversation chat) async =>
      await conversationTable.updateConversation(chat);

  @override
  Future<bool> removeConversation(ID chat) async =>
      await conversationTable.removeConversation(chat);

  Future<int> burnConversations(DateTime expired) async =>
      await conversationTable.burnConversations(expired);

  // ===================== 消息追踪表接口实现 =====================
  @override
  Future<bool> addTrace(
    String trace,
    ID cid, {
    required ID sender,
    required int sn,
    required String? signature,
  }) async => await traceTable.addTrace(
    trace,
    cid,
    sender: sender,
    sn: sn,
    signature: signature,
  );

  @override
  Future<List<String>> getTraces(ID sender, int sn, String? signature) async =>
      await traceTable.getTraces(sender, sn, signature);

  @override
  Future<bool> removeTraces(ID sender, int sn, String? signature) async =>
      await traceTable.removeTraces(sender, sn, signature);

  @override
  Future<bool> removeAllTraces(ID cid) async =>
      await traceTable.removeAllTraces(cid);

  // ===================== 应用自定义信息表接口实现 =====================
  @override
  Future<Mapper?> getAppCustomizedInfo(String key, {String? mod}) async =>
      await appInfoTable.getAppCustomizedInfo(key, mod: mod);

  @override
  Future<bool> saveAppCustomizedInfo(
    Mapper content,
    String key, {
    Duration? expires,
  }) async =>
      await appInfoTable.saveAppCustomizedInfo(content, key, expires: expires);

  @override
  Future<bool> clearExpiredAppCustomizedInfo() async =>
      await appInfoTable.clearExpiredAppCustomizedInfo();

  @override
  Future<Map<String, dynamic>?> getLoginRecordMap(ID identifier) async =>
      await loginTable.getLoginRecordMap(identifier);

  @override
  Future<bool> saveLoginRecordWithToken(
    ID identifier,
    LoginCommand content,
    ReliableMessage rMsg, {
    String? token,
  }) async =>
      await loginTable.saveLoginRecordWithToken(identifier, content, rMsg);
}
