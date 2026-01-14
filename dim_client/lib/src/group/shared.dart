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
import 'package:flutter/cupertino.dart';

import '../common/facebook.dart';
import '../common/messenger.dart';

import 'admin.dart';
import 'delegate.dart';
import 'emitter.dart';
import 'manager.dart';

/// 共享群组管理器（单例）
/// 统一管理群组相关的所有操作，提供简洁的对外接口
class SharedGroupManager implements GroupDataSource {
  /// 单例工厂方法
  factory SharedGroupManager() => _instance;
  /// 单例实例
  static final SharedGroupManager _instance = SharedGroupManager._internal();
  /// 私有构造方法
  SharedGroupManager._internal();

  // Facebook弱引用（用户信息管理）
  WeakReference<CommonFacebook>? _barrack;
  // Messenger弱引用（消息收发）
  WeakReference<CommonMessenger>? _transceiver;

  /// 获取Facebook实例
  CommonFacebook? get facebook => _barrack?.target;
  /// 获取Messenger实例
  CommonMessenger? get messenger => _transceiver?.target;

  /// 设置Facebook实例（清空现有代理）
  set facebook(CommonFacebook? delegate){
    _barrack = delegate == null ? null : WeakReference(delegate);
    _clearDelegates();
  }
  /// 设置Messenger实例（清空现有代理）
  set messenger(CommonMessenger? delegate){
    _transceiver = delegate == null ? null : WeakReference(delegate);
    _clearDelegates();
  }

  //
  //  各类代理对象（懒加载）
  //
  GroupDelegate? _delegate;
  GroupManager? _manager;
  AdminManager? _adminManager;
  GroupEmitter? _emitter;

  /// 清空所有代理对象（重新设置核心组件时调用）
  void _clearDelegates(){
    _delegate = null;
    _manager = null;
    _adminManager = null;
    _emitter = null;
  }

  /// 懒加载获取GroupDelegate(单例)
  /// 核心：所有其他组件都依赖这个Delegate,封装基础的数据源调用
  GroupDelegate get delegate{
    GroupDelegate? target = _delegate;
    if(target == null){
      // 初始化Delegate，依赖已设置的Facebook/Messenger
      _delegate = target = GroupDelegate(facebook!, messenger!);
    }
    return target;
  }

  /// 懒加载获取GroupManager（单例）
  /// 核心：提供群组创建、重置成员、邀请、退出等核心操作
  GroupManager get manager{
    GroupManager? target = _manager;
    if(target == null){
      _manager = target = GroupManager(delegate);
    }
    return target;
  }

  /// 懒加载获取AdminManager（单例）
  /// 核心：处理群组管理员相关操作（更新管理员列表、广播群组文档）
  AdminManager get adminManager {
    AdminManager? target = _adminManager;
    if (target == null) {
      _adminManager = target = AdminManager(delegate);
    }
    return target;
  }

  /// 懒加载获取GroupEmitter（单例）
  /// 核心：处理群组消息的发送逻辑（拆分、转发、加密签名）
  GroupEmitter get emitter {
    GroupEmitter? target = _emitter;
    if (target == null) {
      _emitter = target = GroupEmitter(delegate);
    }
    return target;
  }

  /// 构建群组名称（桥接Delegate的实现）
  /// [members] 群成员列表
  /// @return 生成的群组名称
  Future<String> buildGroupName(List<ID> members) async =>
      await delegate.buildGroupName(members);

  //
  //  Entity DataSource 接口实现（桥接Delegate）
  //  作用：对外提供统一的数据源接口，底层由Delegate调用Facebook实现
  //

  /// 获取群组的Meta（元数据）
  @override
  Future<Meta?> getMeta(ID group) async => await delegate.getMeta(group);

  /// 获取群组的所有文档（如Bulletin公告）
  @override
  Future<List<Document>> getDocuments(ID group) async =>
      await delegate.getDocuments(group);
  
  /// 获取群组的Bulletin公告文档（便捷方法）
  Future<Bulletin?> getBulletin(ID group) async => await delegate.getBulletin(group);

  //
  //  Group DataSource 接口实现（桥接Delegate）
  //  作用：对外提供群组相关的核心数据查询接口
  //

  /// 获取群组创始人ID
  @override
  Future<ID?> getFounder(ID group) async => await delegate.getFounder(group);

  /// 获取群组群主ID
  Future<ID?> getOwner(ID group) async => await delegate.getOwner(group);

  /// 获取群组机器人（助理）列表
  @override
  Future<List<ID>> getAssistants(ID group) async =>
      await delegate.getAssistants(group);

  /// 获取群成员列表
  @override
  Future<List<ID>> getMembers(ID group) async => await delegate.getMembers(group);

  /// 获取群组管理员列表
  Future<List<ID>> getAdministrators(ID group) async =>
      await delegate.getAdministrators(group);

  /// 校验指定用户是否是群组群主
  /// [user] 待校验的用户ID
  /// [group] 群组ID
  /// @return true=是群主，false=不是
  Future<bool> isOwner(ID user, {required ID group}) async =>
      await delegate.isOwner(user, group: group);

  /// 广播群组公告文档到所有成员/节点
  /// [doc] 要广播的Bulletin文档
  /// @return true=广播成功，false=失败
  Future<bool> broadcastGroupDocument(Bulletin doc) async =>
      await adminManager.broadcastGroupDocument(doc);

  //
  //  群组管理核心操作（对外提供统一入口，底层调用Manager/Admin/Emitter）
  //

  /// 创建新群组（封装GroupManager的createGroup）
  /// [members] 初始群成员列表
  /// @return 新创建的群组ID（失败返回null）
  Future<ID?> createGroup(List<ID> members) async =>
      await manager.createGroup(members);

  /// 更新群组管理员列表（封装AdminManager的实现）
  /// [newAdmins] 新的管理员列表
  /// [group] 群组ID
  /// @return true=更新成功，false=失败
  Future<bool> updateAdministrators(List<ID> newAdmins, {required ID group}) async =>
      await adminManager.updateAdministrators(newAdmins, group: group);

  /// 重置群成员列表（封装GroupManager的resetMembers）
  /// [newMembers] 新的成员列表
  /// [group] 群组ID
  /// @return true=重置成功，false=失败
  Future<bool> resetGroupMembers(List<ID> newMembers, {required ID group}) async =>
      await manager.resetMembers(newMembers, group: group);

  /// 踢出群成员（自定义逻辑，基于resetMembers实现）
  /// [expelMembers] 要踢出的成员列表
  /// [group] 群组ID
  /// @return true=踢出成功，false=失败
  Future<bool> expelGroupMembers(List<ID> expelMembers,{required ID group}) async{
    // 参数校验：必须是群组ID，且踢出列表非空
    assert(group.isGroup && expelMembers.isNotEmpty, 'params error: $group, $expelMembers');

    // 获取当前登录用户（校验权限）
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;
    // 获取当前群成员列表
    List<ID> oldMembers = await delegate.getMembers(group);

    // 权限校验：是否是群主/管理员（只有群主/管理员能踢人）
    bool isOwner = await delegate.isOwner(me, group: group);
    bool isAdmin = await delegate.isAdministrator(me, group: group);

    // 检查权限
    bool canReset = isOwner || isAdmin;
    if (canReset) {
      // 有权限：创建成员列表副本，移除要踢出的成员
      List<ID> members = [...oldMembers];
      for (ID item in expelMembers) {
        members.remove(item);
      }
      // 调用resetMembers完成踢人操作（重置成员列表）
      return await resetGroupMembers(members, group: group);
    }

    // 无权限：抛出异常
    throw Exception('Cannot expel members from group: $group');
  }

  /// 邀请新成员加入群组（封装GroupManager的inviteMembers）
  /// [newMembers] 待邀请的成员列表
  /// [group] 群组ID
  /// @return true=邀请成功，false=失败
  Future<bool> inviteGroupMembers(List<ID> newMembers, {required ID group}) async =>
      await manager.inviteMembers(newMembers, group: group);

  /// 退出群组（封装GroupManager的quitGroup）
  /// [group] 要退出的群组ID
  /// @return true=退出成功，false=失败
  Future<bool> quitGroup({required ID group}) async =>
      await manager.quitGroup(group: group);

  //
  //  群组消息发送（封装GroupEmitter的实现）
  //

  /// 发送群组即时消息（封装GroupEmitter的sendInstantMessage）
  /// [iMsg] 要发送的即时消息
  /// [priority] 消息优先级（默认0）
  /// @return 发送成功返回可靠消息，失败返回null
  Future<ReliableMessage?> sendInstantMessage(InstantMessage iMsg, {int priority = 0}) async {
    // 参数校验：必须是群组消息（内容中包含群组ID）
    assert(iMsg.content.group != null, 'group message error: $iMsg');
    // 设置群组消息标记（GF=Group Flag），用于通知层识别群组消息
    iMsg['GF'] = true;  // group flag for notification
    // 调用Emitter发送消息
    return await emitter.sendInstantMessage(iMsg, priority: priority);
  }
  

  
  
}