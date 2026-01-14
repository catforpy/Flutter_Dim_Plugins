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

import 'delegate.dart';

/// 群组管理员管理类
/// 主要负责更新群组公告中的管理员列表并广播更新后的公告文档
class AdminManager extends TripletsHelper {
  /// 构造方法
  /// [super.delegate] - 父类初始化，传入群组代理对象
  AdminManager(super.delegate);

  /// 更新公告文档中的"administrators"字段
  /// （将新文档广播给所有群成员和相邻节点）
  /// 
  /// @param group - 群组ID
  /// @param newAdmins - 新的管理员列表
  /// @return 操作失败返回false，成功返回true
  Future<bool> updateAdministrators(List<ID> newAdmins, {required ID group}) async{
    // 断言：确保传入的是群组ID
    assert(group.isGroup, 'group ID error: $group');
    // 断言：确保facebook（用户信息管理）已初始化
    assert(facebook != null, 'facebook not ready');

    //
    //  0. 获取当前登录用户
    //
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;
    // 获取当前用户用于签证签名的私钥
    SignKey? sKey = await facebook?.getPrivateKeyForVisaSignature(me);
    assert(sKey != null, 'failed to get sign key for current user: $me');

    //
    //  1. 权限校验：只有群主才能更新管理员
    //
    bool isOwner = await delegate.isOwner(me, group: group);
    if(!isOwner){
      return false;
    }

    //
    //  2. 更新公告文档
    //
    // 获取群组公告文档
    Bulletin? bulletin = await delegate.getBulletin(group);
    if(bulletin == null){
      // TODO:是否需要创建新的公告文档？
      assert(false, 'failed to get group document: $group, owner: $me');
      return false;
    }else{
      // 克隆文档用于修改（避免修改原对象）
      Document? clone = Document.parse(bulletin.copyMap(false));
      if(clone is Bulletin){
        bulletin = clone;
      }else{
        assert(false, 'bulletin error: $bulletin, $group');
        return false;
      }
    }
    // 设置管理员列表（ID.revert用于格式转换）
    bulletin.setProperty('administrators', ID.revert(newAdmins));
    // 用私钥签名文档
    var signature = sKey == null ? null : bulletin.sign(sKey);
    if(signature == null){
      assert(false, 'failed to sign document for group: $group, owner: $me');
      return false;
    }else if (!await delegate.saveDocument(bulletin)) {
      assert(false, 'failed to save document for group: $group');
      return false;
    } else {
      logInfo('group document updated: $group');
    }

    //
    //  3. 广播更新后的公告文档
    //
    return broadcastGroupDocument(bulletin);
  }

  /// 广播群组公告文档
  /// [doc] - 要广播的群组公告文档
  /// @return 广播成功返回true，失败返回false
  Future<bool> broadcastGroupDocument(Bulletin doc) async{
    // 断言：确保核心组件已初始化
    assert(facebook != null, 'facebook not ready: $facebook');
    assert(messenger != null, 'messenger not ready: $messenger');

    //
    //  0. 获取当前登录用户
    //
    User? user = await facebook?.currentUser;
    if(user == null){
      assert(false, 'failed to get current user');
      return false;
    }
    ID me = user.identifier;

    //
    //  1. 创建"document"命令并发送到当前节点
    //
    ID group = doc.identifier;
    Meta? meta = await facebook?.getMeta(group);
    // 创建文档相应命令
    Command content = DocumentCommand.response(group, meta, [doc]);
    // 发送到任意节点（优先级1）
    messenger?.sendContent(content, sender: me, receiver: Station.ANY,priority: 1);

    //
    //  2. 检查群组机器人
    //
    List<ID> bots = await delegate.getAssistants(group);
    if(bots.isNotEmpty){
      // 存在群组机器人，有机器人负责分发给所有成员
      for(ID item in bots){
        if(me == item){
          assert(false, 'should not be a bot here: $me');
          continue;
        }
        messenger?.sendContent(content, sender: me, receiver: item,priority: 1);
      }
      return true;
    }

    //
    //  3. 无机器人时直接广播给所有群成员
    //
    List<ID> members = await delegate.getMembers(group);
    if(members.isEmpty){
      assert(false, 'failed to get group members: $group');
      return false;
    }
    for(ID item in members){
      if(me == item){
        logInfo('skip cycled message: $item, $group');
        continue;
      }
      messenger?.sendContent(content, sender: me, receiver: item,priority: 1);
    }
    return true;
  }
}