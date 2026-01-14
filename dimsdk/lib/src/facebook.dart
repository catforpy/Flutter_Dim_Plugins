/* license: https://mit-license.org
 *
 *  ObjectKey : Object & Key kits
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

import 'package:dimsdk/core.dart';
import 'package:dimsdk/dimp.dart';
import 'package:dimsdk/mkm.dart';

/// Facebook核心接口
/// 管理用户/群组实体，提供密钥查询、本地用户选择等核心能力
abstract class Facebook implements EntityDelegate, UserDataSource, GroupDataSource {
  
  // 受保护方法：获取营房（实体管理器）
  Barrack? get barrack;

  // 受保护方法：获取档案管理员（数据持久化）
  Archivist? get archivist;

  /// 为接收方选择本地用户
  ///
  /// @param receiver - 用户/群组ID
  /// @return 匹配的本地用户ID
  Future<ID?> selectLocalUser(ID receiver) async {
    assert(archivist != null, '档案管理员未就绪');
    List<ID>? users = await archivist?.getLocalUsers();
    //
    //  1. 基础校验
    //
    if (users == null || users.isEmpty) {
      assert(false, '本地用户列表不能为空');
      return null;
    } else if(receiver.isBroadcast){
      // 广播消息可被任意人解密，直接返回第一个本地用户
      return users.first;
    }
    //
    //  2. 根据接收方类型匹配本地用户
    //
    if(receiver.isUser){
      // 个人消息：匹配接收方为本地用户的情况
      for (ID item in users) {
        if (receiver == item) {
          // 讨论：是否将此用户设为当前用户？
          return item;
        }
      }
    }else if (receiver.isGroup){
      // 群组消息（未指定具体接收人）
      //
      // 消息处理器在解密前会检查群组信息，因此可确定群组元数据和成员列表已存在
      List<ID> members = await getMembers(receiver);
      if (members.isEmpty) {
        assert(false, '群组成员未找到: $receiver');
        return null;
      }
      // 匹配本地用户中属于该群组的成员
      for (ID item in users) {
        if (members.contains(item)) {
          // 讨论：是否将此用户设为当前用户？
          return item;
        }
      }
    }else{
      assert(false, '接收方ID错误: $receiver');
    }
    // 无匹配的本地用户
    return null;
  }

  //
  //  实体代理方法实现
  //

  @override
  Future<User?> getUser(ID identifier) async {
    assert(identifier.isUser, '用户ID错误: $identifier');
    assert(barrack != null, '营房未就绪');
    //
    //  1. 从用户缓存中获取
    //
    User? user = barrack?.getUser(identifier);
    if (user != null) {
      return user;
    }
    //
    //  2. 检查签证密钥
    //
    if (identifier.isBroadcast) {
      // 广播用户无需检查签证密钥
    } else {
      EncryptKey? visaKey = await getPublicKeyForEncryption(identifier);
      if (visaKey == null) {
        assert(false, '签证密钥未找到: $identifier');
        return null;
      }
      // 注意：若签证密钥存在，则签证和元数据也必定存在
    }
    //
    //  3. 创建用户并缓存
    //
    user = barrack?.createUser(identifier);
    if (user != null) {
      barrack?.cacheUser(user);
    }
    return user;
  }

  @override
  Future<Group?> getGroup(ID identifier) async {
    assert(identifier.isGroup, '群组ID错误: $identifier');
    assert(barrack != null, '营房未就绪');
    //
    //  1. 从群组缓存中获取
    //
    Group? group = barrack?.getGroup(identifier);
    if (group != null) {
      return group;
    }
    //
    //  2. 检查群组成员
    //
    if (identifier.isBroadcast) {
      // 广播群组无需检查成员
    } else {
      List<ID> members = await getMembers(identifier);
      if (members.isEmpty) {
        assert(false, '群组成员未找到: $identifier');
        return null;
      }
      // 注意：若成员列表存在，则群主（创始人）、公告和元数据也必定存在
    }
    //
    //  3. 创建群组并缓存
    //
    group = barrack?.createGroup(identifier);
    if (group != null) {
      barrack?.cacheGroup(group);
    }
    return group;
  }

  //
  //  用户数据源方法实现
  //

  @override
  Future<EncryptKey?> getPublicKeyForEncryption(ID user) async {
    assert(user.isUser, '用户ID错误: $user');
    assert(archivist != null, '档案管理员未就绪');
    //
    //  1. 从签证中获取公钥
    //
    EncryptKey? visaKey = await archivist?.getVisaKey(user);
    if (visaKey != null) {
      // 若签证密钥存在，优先使用其进行加密
      return visaKey;
    }
    //
    //  2. 从元数据中获取密钥
    //
    VerifyKey? metaKey = await archivist?.getMetaKey(user);
    if (metaKey is EncryptKey) {
      // 若签证密钥不存在且元数据密钥支持加密，则使用该密钥
      return metaKey as EncryptKey;
    }
    // assert(false, '获取用户加密公钥失败: $user');
    return null;
  }

  @override
  Future<List<VerifyKey>> getPublicKeysForVerification(ID user) async {
    // assert(user.isUser, '用户ID错误: $user');
    assert(archivist != null, '档案管理员未就绪');
    List<VerifyKey> keys = [];
    //
    //  1. 从签证中获取公钥
    //
    EncryptKey? visaKey = await archivist?.getVisaKey(user);
    if (visaKey is VerifyKey) {
      // 发送方可能使用通讯密钥签名消息数据，优先用签证密钥验证
      keys.add(visaKey as VerifyKey);
    }
    //
    //  2. 从元数据中获取密钥
    //
    VerifyKey? metaKey = await archivist?.getMetaKey(user);
    if (metaKey != null) {
      // 发送方也可能使用身份密钥签名消息数据，补充验证
      keys.add(metaKey);
    }
    assert(keys.isNotEmpty, '获取用户验证公钥失败: $user');
    return keys;
  }
}