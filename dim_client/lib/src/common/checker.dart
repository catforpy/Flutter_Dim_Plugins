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

import 'package:dim_client/common.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/plugins.dart';
import 'package:dim_client/sdk.dart';

/// 实体检查器抽象类
/// 用于检查Meta/文档/群成员是否需要查询、限制查询频率、记录最近操作时间等
abstract class EntityChecker with Logging {
  // ignore_for_file: non_constant_identifier_names

  /// 查询过期时间：每次查询10分钟内仅允许一次
  static Duration QUERY_EXPIRES = Duration(minutes: 10);

  /// 响应过期时间：每次响应10分钟内仅允许一次
  static Duration RESPOND_EXPIRES = Duration(minutes: 10);

  /// 查询频率检查器：Meta查询（ID→查询时间）
  final FrequencyChecker<ID> _metaQueries    = FrequencyChecker(QUERY_EXPIRES);
  /// 查询频率检查器：文档查询（ID→查询时间）
  final FrequencyChecker<ID> _docsQueries    = FrequencyChecker(QUERY_EXPIRES);
  /// 查询频率检查器：群成员查询（ID→查询时间）
  final FrequencyChecker<ID> _membersQueries = FrequencyChecker(QUERY_EXPIRES);

  /// 响应频率检查器：Visa响应（ID→响应时间）
  final FrequencyChecker<ID> _visaResponses  = FrequencyChecker(RESPOND_EXPIRES);

  /// 最近时间检查器：文档最后更新时间（ID→时间）
  final RecentTimeChecker<ID> _lastDocumentTimes = RecentTimeChecker();
  /// 最近时间检查器：群组历史最后更新时间（ID→时间）
  final RecentTimeChecker<ID> _lastHistoryTimes  = RecentTimeChecker();

  /// 群组最近活跃成员映射（群组ID→成员ID）
  final Map<ID, ID> _lastActiveMembers = {};

  // 受保护字段：账户数据库接口
  final AccountDBI database;

  /// 构造方法
  /// [database] 账户数据库接口
  EntityChecker(this.database);

  // 受保护方法：检查Meta查询是否过期
  bool isMetaQueryExpired(ID identifier)     => _metaQueries.isExpired(identifier);
  // 受保护方法：检查文档查询是否过期
  bool isDocumentQueryExpired(ID identifier) => _docsQueries.isExpired(identifier);
  // 受保护方法：检查群成员查询是否过期
  bool isMembersQueryExpired(ID identifier)  => _membersQueries.isExpired(identifier);
  // 受保护方法：检查文档响应是否过期
  bool isDocumentResponseExpired(ID identifier, bool force) =>
      _visaResponses.isExpired(identifier, force: force);

  /// 设置群组的最近活跃成员
  /// [member] 成员ID
  /// [group] 群组ID（必传）
  void setLastActiveMember(ID member, {required ID group}) =>
      _lastActiveMembers[group] = member;
  // 受保护方法：获取群组的最近活跃成员
  ID? getLastActiveMember({required ID group}) => _lastActiveMembers[group];

  /// 更新文档最后更新时间（SDT：Sender Document Time）
  /// [current] 当前时间
  /// [identifier] 实体ID
  /// 返回：true=时间更新成功，false=时间未更新
  bool setLastDocumentTime(DateTime current, ID identifier) =>
      _lastDocumentTimes.setLastTime(identifier, current);

  /// 更新群组历史最后更新时间（GHT：Group History Time）
  /// [current] 当前时间
  /// [group] 群组ID
  /// 返回：true=时间更新成功，false=时间未更新
  bool setLastGroupHistoryTime(DateTime current, ID group) =>
      _lastHistoryTimes.setLastTime(group, current);

  //
  //  Meta 检查
  //

  /// 检查是否需要查询Meta
  /// [identifier] 实体ID
  /// [meta] 已存在的Meta（可能为空）
  /// 返回：true=需要查询，false=无需查询
  Future<bool> checkMeta(ID identifier, Meta? meta) async {
    if (needsQueryMeta(identifier, meta)) {
      // 注释：原频率检查逻辑被注释，如需启用可取消注释
      // if (!isMetaQueryExpired(identifier)) {
      //   // query not expired yet
      //   return false;
      // }
      // 执行Meta查询
      return await queryMeta(identifier);
    } else {
      // 无需重复查询Meta
      return false;
    }
  }

  /// 检查是否需要查询Meta（受保护方法）
  bool needsQueryMeta(ID identifier, Meta? meta) {
    if (identifier.isBroadcast) {
      // 广播实体无Meta可查询
      return false;
    } else if (meta == null) {
      // Meta不存在，需要查询
      return true;
    }
    // 断言：Meta与ID不匹配（调试模式触发）
    assert(MetaUtils.matchIdentifier(identifier, meta), 'meta not match: $identifier, $meta');
    // Meta已存在且匹配，无需查询
    return false;
  }

  //
  //  Documents 检查
  //

  /// 检查是否需要查询/更新文档
  /// [identifier] 实体ID
  /// [documents] 已存在的文档列表
  /// 返回：true=需要查询，false=无需查询
  Future<bool> checkDocuments(ID identifier, List<Document> documents) async {
    if (needsQueryDocuments(identifier, documents)) {
      // 注释：原频率检查逻辑被注释，如需启用可取消注释
      // if (!isDocumentQueryExpired(identifier)) {
      //   // query not expired yet
      //   return false;
      // }
      // 执行文档查询
      return await queryDocuments(identifier, documents);
    } else {
      // 当前无需更新文档
      return false;
    }
  }

  /// 检查是否需要查询文档（受保护方法）
  bool needsQueryDocuments(ID identifier, List<Document> documents) {
    if (identifier.isBroadcast) {
      // 广播实体无文档可查询
      return false;
    } else if (documents.isEmpty) {
      // 文档列表为空，需要查询
      return true;
    }
    // 获取文档列表中的最新时间
    DateTime? current = getLastDocumentTime(identifier, documents);
    // 检查文档时间是否过期
    return _lastDocumentTimes.isExpired(identifier, current);
  }

  // 受保护方法：获取文档列表中的最新时间
  DateTime? getLastDocumentTime(ID identifier, List<Document> documents) {
    if (documents.isEmpty) {
      return null;
    }
    DateTime? lastTime;
    DateTime? docTime;
    // 遍历文档列表，找到最新的文档时间
    for (Document doc in documents) {
      // 断言：文档与ID不匹配（调试模式触发）
      assert(doc.identifier == identifier, 'document not match: $identifier, $doc');
      docTime = doc.time;
      if (docTime == null) {
        // 日志：文档时间错误（警告）
        // assert(false, 'document error: $doc');
        logWarning('document time error: $doc');
      } else if (lastTime == null || lastTime.isBefore(docTime)) {
        // 更新最新时间
        lastTime = docTime;
      }
    }
    return lastTime;
  }

  //
  //  Group Members 检查
  //

  /// 检查是否需要查询群成员
  /// [group] 群组ID
  /// [members] 已存在的成员列表
  /// 返回：true=需要查询，false=无需查询
  Future<bool> checkMembers(ID group, List<ID> members) async {
    if (await needsQueryMembers(group, members)) {
      // 注释：原频率检查逻辑被注释，如需启用可取消注释
      // if (!isMembersQueryExpired(group)) {
      //   // query not expired yet
      //   return false;
      // }
      // 执行群成员查询
      return await queryMembers(group, members);
    } else {
      // 当前无需更新群成员
      return false;
    }
  }

  /// 检查是否需要查询群成员（受保护方法）
  Future<bool> needsQueryMembers(ID group, List<ID> members) async {
    if (group.isBroadcast) {
      // 广播群组无成员可查询
      return false;
    } else if (members.isEmpty) {
      // 成员列表为空，需要查询
      return true;
    }
    // 获取群组历史的最新时间
    DateTime? current = await getLastGroupHistoryTime(group);
    // 检查群组历史时间是否过期
    return _lastHistoryTimes.isExpired(group, current);
  }

  /// 获取群组历史的最新时间
  /// [group] 群组ID
  /// 返回：群组历史的最新时间（无历史返回null）
  Future<DateTime?> getLastGroupHistoryTime(ID group) async {
    // 从数据库获取群组历史记录
    var array = await database.getGroupHistories(group: group);
    if (array.isEmpty) {
      return null;
    }
    DateTime? lastTime;
    GroupCommand his;
    DateTime? hisTime;
    // 遍历历史记录，找到最新的时间
    for (var pair in array) {
      his = pair.first;
      hisTime = his.time;
      if (hisTime == null) {
        // 日志：群组命令时间错误（警告）
        // assert(false, 'group command error: $his');
        logWarning('group command time error: $his');
      } else if (lastTime == null || lastTime.isBefore(hisTime)) {
        // 更新最新时间
        lastTime = hisTime;
      }
    }
    return lastTime;
  }

  // -------- 抽象查询方法（需子类实现）

  /// 发起Meta查询（需子类实现）
  /// [identifier] 实体ID
  /// 返回：false=查询重复，true=查询成功发起
  Future<bool> queryMeta(ID identifier);

  /// 发起文档查询（需子类实现）
  /// [identifier] 实体ID
  /// [documents] 已存在的文档列表
  /// 返回：false=查询重复，true=查询成功发起
  Future<bool> queryDocuments(ID identifier, List<Document> documents);

  /// 发起群成员查询（需子类实现）
  /// [group] 群组ID
  /// [members] 已存在的成员列表
  /// 返回：false=查询重复，true=查询成功发起
  Future<bool> queryMembers(ID group, List<ID> members);

  // -------- 响应方法（需子类实现）

  /// 发送Visa文档给联系人
  /// 如文档已更新，强制重新发送；否则10分钟内仅发送一次
  /// [visa] 要发送的Visa文档
  /// [receiver] 接收方ID
  /// [updated] 是否已更新（true=强制发送）
  /// 返回：true=发送成功，false=发送失败
  Future<bool> sendVisa(Visa visa, ID receiver, {bool updated = false});
}