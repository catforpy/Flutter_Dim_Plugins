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
import 'package:dim_client/common.dart';

import 'group_admin.dart';
import 'group_member.dart';


/// 群组缓存管理器：实现GroupDBI接口，整合成员和管理员操作
class GroupCache with Logging implements GroupDBI {
  /// 构造方法：初始化成员和管理员表实例
  GroupCache() : _memberTable = MemberCache(), _adminTable = AdminCache();

  /// 成员表实例
  final MemberCache _memberTable;
  /// 管理员表实例
  final AdminCache _adminTable;

  /// 获取群组创始人
  /// [group] 群组ID
  /// 返回创始人ID（待实现）
  @override
  Future<ID?> getFounder({required ID group}) async {
    // TODO: implement getFounder
    logWarning('implement getFounder: $group');
    return null;
  }

  /// 获取群组所有者
  /// [group] 群组ID
  /// 返回所有者ID（待实现）
  @override
  Future<ID?> getOwner({required ID group}) async {
    // TODO: implement getOwner
    logWarning('implement getOwner: $group');
    return null;
  }

  /// 获取群组成员列表
  /// [group] 群组ID
  /// 返回成员列表
  @override
  Future<List<ID>> getMembers({required ID group}) async =>
      await _memberTable.getMembers(group);

  /// 保存群组成员列表
  /// [members] 成员列表
  /// [group] 群组ID
  /// 返回操作是否成功
  @override
  Future<bool> saveMembers(List<ID> members, {required ID group}) async =>
      await _memberTable.saveMembers(members, group);

  /// 添加群组成员
  /// [member] 成员ID
  /// [group] 群组ID
  /// 返回操作是否成功
  Future<bool> addMember(ID member, {required ID group}) async =>
      await _memberTable.addMember(member, group: group);

  /// 移除群组成员
  /// [member] 成员ID
  /// [group] 群组ID
  /// 返回操作是否成功
  Future<bool> removeMember(ID member, {required ID group}) async =>
      await _memberTable.removeMember(member, group: group);

  /// 获取群组助手列表
  /// [group] 群组ID
  /// 返回助手列表（待实现）
  @override
  Future<List<ID>> getAssistants({required ID group}) async {
    // TODO: implement getAssistants
    logWarning('implement getAssistants: $group');
    return [];
  }

  /// 保存群组助手列表
  /// [bots] 助手列表
  /// [group] 群组ID
  /// 返回操作是否成功（待实现）
  @override
  Future<bool> saveAssistants(List<ID> bots, {required ID group}) async {
    // TODO: implement saveAssistants
    logWarning('implement saveAssistants: $group, $bots');
    return false;
  }

  /// 获取群组管理员列表
  /// [group] 群组ID
  /// 返回管理员列表
  @override
  Future<List<ID>> getAdministrators({required ID group}) async =>
      await _adminTable.getAdministrators(group);

  /// 保存群组管理员列表
  /// [admins] 管理员列表
  /// [group] 群组ID
  /// 返回操作是否成功
  @override
  Future<bool> saveAdministrators(List<ID> admins, {required ID group}) async =>
      await _adminTable.saveAdministrators(admins, group);

  /// 添加群组管理员
  /// [admin] 管理员ID
  /// [group] 群组ID
  /// 返回操作是否成功
  Future<bool> addAdministrator(ID admin, {required ID group}) async =>
      await _adminTable.addAdministrator(admin, group: group);

  /// 移除群组管理员
  /// [admin] 管理员ID
  /// [group] 群组ID
  /// 返回操作是否成功
  Future<bool> removeAdministrator(ID admin, {required ID group}) async =>
      await _adminTable.removeAdministrator(admin, group: group);

  /// 移除群组
  /// [group] 群组ID
  /// 返回操作是否成功（待实现）
  Future<bool> removeGroup({required ID group}) async {
    // TODO: implement removeGroup
    logWarning('implement removeGroup: $group');
    return false;
  }

}