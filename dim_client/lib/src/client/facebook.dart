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

import '../common/ans.dart';
import '../common/archivist.dart';
import '../common/facebook.dart';
import '../common/protocol/utils.dart';
import '../group/shared.dart';

/// 客户端档案管理员
/// 扩展CommonArchivist，处理群组数据缓存和文档保存
class ClientArchivist extends CommonArchivist {
  /// 构造方法
  ClientArchivist(super.facebook, super.database);

  /// 缓存群组信息（设置数据源为SharedGroupManager）
  @override
  void cacheGroup(Group group) {
    group.dataSource = SharedGroupManager();
    super.cacheGroup(group);
  }

  /// 保存文档（重载以处理群组公告中的管理员信息）
  @override
  Future<bool> saveDocument(Document doc) async {
    bool ok = await super.saveDocument(doc);
    // 如果是群组公告，提取并保存管理员列表
    if(ok && doc is Bulletin){
      Object? array = doc.getProperty('administrators');
      if(array is List){
        ID group = doc.identifier;
        assert(group.isGroup, 'group ID error: $group');
        List<ID> admins = ID.convert(array);
        // 保存管理员列表到数据库
        ok = await database.saveAdministrators(admins, group: group);
      }
    }
    return ok;
  }
}

/// 带地址名服务（ANS）的客户端Facebook
/// 核心功能：管理用户/群组信息，提供群组相关数据查询接口
class ClientFacebook extends CommonFacebook {
  /// 构造方法
  ClientFacebook(super.database);

  //
  //  群组数据源接口
  //

  /// 获取群组创始人
  /// [group]：群组ID
  /// 返回：创始人ID（null表示未找到）
  @override
  Future<ID?> getFounder(ID group) async {
    assert(group.isGroup, 'group ID error: $group');
    // 检查广播群组
    if(group.isBroadcast){
      return BroadcastUtils.getBroadcastFounder(group);
    }
    // 检查群组公告文档
    Bulletin? doc = await getBulletin(group);
    if(doc == null){
      return null;
    }
    // 检查本地存储
    ID? user = await database.getFounder(group: group);
    if (user != null) {
      return user;
    }
    // 从公告文档获取创始人
    user = doc.founder;
    assert(user != null, 'founder not designated for group: $group');
    return user;
  }

  /// 获取群组所有者
  /// [group]：群组ID
  /// 返回：所有者ID（null表示未找到）
  @override
  Future<ID?> getOwner(ID group) async {
    assert(group.isGroup, 'group ID error: $group');
    // 检查广播群组
    if(group.isBroadcast){
      return BroadcastUtils.getBroadcastOwner(group);
    }
    // 检查群组公告文档
    Bulletin? doc = await getBulletin(group);
    if (doc == null) {
      return null;
    }
    // 检查本地存储
    ID? user = await database.getOwner(group: group);
    if (user != null) {
      return user;
    }
    // 普通群组的所有者即创始人
    if(group.type == EntityType.GROUP){
      user = await database.getFounder(group: group);
      user ??= doc.founder;
    }
    assert(user != null, 'owner not found for group: $group');
    return user;
  }

  /// 获取群组成员
  /// [group]：群组ID
  /// 返回：成员列表（至少包含群主）
  @override
  Future<List<ID>> getMembers(ID group) async {
    assert(group.isGroup, 'group ID error: $group');
    // 检查广播群组
    if (group.isBroadcast) {
      return BroadcastUtils.getBroadcastMembers(group);
    }
    // 检查群主
    ID? owner = await getOwner(group);
    if (owner == null) {
      return [];
    }
    // 从本地存储获取成员
    var members = await database.getMembers(group: group);
    // 检查成员是否完整（自动触发缺失查询）
    await entityChecker?.checkMembers(group, members);
    // 成员为空时返回群主
    return members.isEmpty ? [owner] : members;
  }

  /// 获取群组机器人
  /// [group]：群组ID
  /// 返回：机器人列表
  @override
  Future<List<ID>> getAssistants(ID group) async {
    assert(group.isGroup, 'group ID error: $group');
    // 检查群组公告文档
    Bulletin? doc = await getBulletin(group);
    if (doc == null) {
      return [];
    }
    // 从本地存储获取
    var bots = await database.getAssistants(group: group);
    if (bots.isNotEmpty) {
      return bots;
    }
    // 从公告文档获取
    return doc.assistants ?? [];
  }

  //
  //  组织结构接口
  //

  /// 获取群组管理员
  /// [group]：群组ID
  /// 返回：管理员列表
  @override
  Future<List<ID>> getAdministrators(ID group) async {
    assert(group.isGroup, 'group ID error: $group');
    // 检查群组公告文档
    Bulletin? doc = await getBulletin(group);
    if (doc == null) {
      return [];
    }
    // 仅从本地存储获取（公告更新时已同步）
    return await database.getAdministrators(group: group);
  }

  /// 保存群组管理员
  @override
  Future<bool> saveAdministrators(List<ID> admins, ID group) async =>
      await database.saveAdministrators(admins, group: group);

  /// 保存群组成员
  @override
  Future<bool> saveMembers(List<ID> newMembers, ID group) async =>
      await database.saveMembers(newMembers, group: group);

  //
  //  地址名服务（ANS）
  //
  static AddressNameServer? ans;
}