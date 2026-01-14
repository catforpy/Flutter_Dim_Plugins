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

import '../client/shared.dart';

/// 屏蔽管理器（单例）：统一管理拉黑和静音功能
/// 包含拉黑列表（屏蔽消息）和静音列表（关闭通知）的增删查改及广播
class Shield {
  factory Shield() => _instance;
  static final Shield _instance = Shield._internal();
  Shield._internal();

  ///
  ///   拉黑功能（屏蔽消息）
  ///
  final _BlockShield _blockShield = _BlockShield();

  /// 获取拉黑列表
  Future<List<ID>> getBlockList() async => await _blockShield.getBlockList();
  /// 添加拉黑联系人
  Future<bool> addBlocked(ID contact) async => await _blockShield.addBlocked(contact);
  /// 移除拉黑联系人
  Future<bool> removeBlocked(ID contact) async => await _blockShield.removeBlocked(contact);
  /// 检查联系人是否被拉黑（支持群维度）
  Future<bool> isBlocked(ID contact,{ID? group}) async => 
      await _blockShield.isBlocked(contact, group: group);

  /// 广播拉黑列表到所有基站
  /// 目的：让基站在第一时间拦截被拉黑用户的消息
  Future<void> broadcastBlockList() async {
    GlobalVariable shared = GlobalVariable();
    var messenger = shared.messenger;
    if (messenger == null) {
      Log.error('messenger not set');
      return;
    }
    List<ID> contacts = await getBlockList();
    Log.info('broadcast block-list command: $contacts');
    // 排除管理员（管理员不可拉黑）
    List<ID> managers = shared.config.managers;
    if(managers.isNotEmpty){
      Log.info('check managers: $managers');
      Set<ID> blockList = contacts.toSet();
      blockList.removeWhere((did) => managers.contains(did));
      if(blockList.length < contacts.length){
        Log.info('broadcast block-list command: $blockList (${contacts.length} -> ${blockList.length})');
        contacts = blockList.toList();
      }
    }
    // 创建拉黑列表命令
    BlockCommand command = BlockCommand.fromList(contacts);
    // 广播到所有基站（优先级1）
    await messenger.sendContent(command, sender: null, receiver: Station.EVERY, priority: 1);
  }

  ///
  ///   静音功能（关闭通知）
  ///
  final _MuteShield _muteShield = _MuteShield();

  /// 获取静音列表
  Future<List<ID>> getMuteList() async => await _muteShield.getMuteList();
  /// 添加静音联系人
  Future<bool> addMuted(ID contact) async => await _muteShield.addMuted(contact);
  /// 移除静音联系人
  Future<bool> removeMuted(ID contact) async => await _muteShield.removeMuted(contact);
  /// 检查联系人是否被静音
  Future<bool> isMuted(ID contact) async => await _muteShield.isMuted(contact);

  /// 广播静音列表到当前基站
  /// 目的：仅当前基站知晓静音状态，其他基站会感知用户漫游状态，仅最后漫游的基站推送通知
  Future<void> broadcastMuteList() async {
    GlobalVariable shared = GlobalVariable();
    var messenger = shared.messenger;
    if (messenger == null) {
      Log.error('messenger not set');
      return;
    }
    List<ID> contacts = await getMuteList();
    Log.info('broadcast mute-list command: $contacts');
    // 创建静音列表命令
    MuteCommand command = MuteCommand.fromList(contacts);
    // 发送到任意基站（仅当前连接的基站，优先级1）
    await messenger.sendContent(command, sender: null, receiver: Station.ANY, priority: 1);
  }
}

/// 屏蔽功能基类：封装拉黑/静音的通用逻辑（缓存、加载、检查）
abstract class _BaseShield {
  /// 缓存： ID -> 是否屏蔽
  final Map<ID,bool> _map = {};
  /// 缓存： 屏蔽列表
  List<ID>? _list;
  /// 当前用户（用于区分不同用户的屏蔽列表）
  User? _user;

  /// 清空缓存（保留_map，仅清空_list）
  void _clear(){
    _list = null;
  }

  /// 检查联系人是否被屏蔽
  /// [contact] 联系人ID
  /// [current] 当前用户
  /// 返回是否被屏蔽
  Future<bool> _check(ID contact, User current) async {
    // 确保数据已加载
    await _get(current);
    // 从缓存获取结果
    return _map[contact] ?? false;
  }

  /// 获取当前用户的屏蔽列表（缓存优先）
  /// [current] 当前用户
  /// 返回屏蔽列表
  Future<List<ID>> _get(User current) async {
    // 用户切换则清空缓存
    if(_user != current){
      _user = current;
      _clear();
    }
    List<ID>? contacts = _list;
    if(contacts == null){
      // 缓存为空，清空map并重新加载
      _map.clear();
      contacts = await _load(current);
      // 填充map缓存
      for(ID item in contacts){
        _map[item] = true;
      }
      _list = contacts;
    }
    return contacts;
  }

  /// 从数据库加载屏蔽列表（由子类实现）
  /// [current] 当前用户
  Future<List<ID>> _load(User current);

  /// 获取当前登录用户
  Future<User?> get currentUser async {
    GlobalVariable shared = GlobalVariable();
    User? current = await shared.facebook.currentUser;
    assert(current != null, 'current user not set');
    return current;
  }
}

/// 拉黑功能实现类：继承BaseShield，实现拉黑列表的数据库操作
class _BlockShield extends _BaseShield {

  /// 获取拉黑列表
  Future<List<ID>> getBlockList() async {
    User? current = await currentUser;
    if(current == null){
      return [];
    }
    return await _get(current);
  }

  /// 检查联系人是否被拉黑（支持群维度）
  /// [contact] 联系人ID
  /// [group] 群ID（可选）
  /// 返回是否被拉黑
  Future<bool> isBlocked(ID contact, {required ID? group, req}) async {
    User? current = await currentUser;
    if(current == null){
      return false;
    }
    if (group != null/* && !group.isBroadcast*/) {
      // 检查群是否被拉黑
      return await _check(group, current);
    }
    // 检查联系人是否被拉黑
    return await _check(contact, current);
  }

  /// 添加拉黑联系人
  /// [contact] 联系人ID
  /// 返回是否添加成功
  Future<bool> addBlocked(ID contact) async {
    User? current = await currentUser;
    if (current == null) {
      return false;
    }
    // 清空缓存，强制重新加载
    _clear();
    GlobalVariable shared = GlobalVariable();
    return await shared.database.addBlocked(contact, user: current.identifier);
  }

  /// 移除拉黑联系人
  /// [contact] 联系人ID
  /// 返回是否移除成功
  Future<bool> removeBlocked(ID contact) async {
    User? current = await currentUser;
    if (current == null) {
      return false;
    }
    // 清空缓存，强制重新加载
    _clear();
    GlobalVariable shared = GlobalVariable();
    return await shared.database.removeBlocked(contact, user: current.identifier);
  }

  /// 从数据库加载拉黑列表
  @override
  Future<List<ID>> _load(User current) async {
    GlobalVariable shared = GlobalVariable();
    return await shared.database.getBlockList(user: current.identifier);
  }
}

/// 静音功能实现类：继承BaseShield，实现静音列表的数据库操作
class _MuteShield extends _BaseShield {

  /// 获取静音列表
  Future<List<ID>> getMuteList() async {
    User? current = await currentUser;
    if (current == null) {
      return [];
    }
    return await _get(current);
  }

  /// 检查联系人是否被静音
  /// [contact] 联系人ID
  /// 返回是否被静音
  Future<bool> isMuted(ID contact) async {
    User? current = await currentUser;
    if (current == null) {
      return false;
    }
    return await _check(contact, current);
  }

  /// 添加静音联系人
  /// [contact] 联系人ID
  /// 返回是否添加成功
  Future<bool> addMuted(ID contact) async {
    User? current = await currentUser;
    if (current == null) {
      return false;
    }
    // 清空缓存，强制重新加载
    _clear();
    GlobalVariable shared = GlobalVariable();
    return await shared.database.addMuted(contact, user: current.identifier);
  }

  /// 移除静音联系人
  /// [contact] 联系人ID
  /// 返回是否移除成功
  Future<bool> removeMuted(ID contact) async {
    User? current = await currentUser;
    if (current == null) {
      return false;
    }
    // 清空缓存，强制重新加载
    _clear();
    GlobalVariable shared = GlobalVariable();
    return await shared.database.removeMuted(contact, user: current.identifier);
  }

  /// 从数据库加载静音列表
  @override
  Future<List<ID>> _load(User current) async {
    GlobalVariable shared = GlobalVariable();
    return await shared.database.getMuteList(user: current.identifier);
  }
}