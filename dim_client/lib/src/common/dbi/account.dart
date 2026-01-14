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

import 'package:dim_client/ok.dart';
import 'package:dim_client/plugins.dart';

/// 私钥数据库接口
/// 负责用户私钥的存储和查询，支持不同用途（签名/解密）的密钥管理
abstract interface class PrivateKeyDBI {

  /// 秘钥类型常量：匹配元数据（Meta）的秘钥
  static const String kMeta = 'M';
  /// 秘钥类型常量：匹配签证（Visa）的秘钥
  static const String kVisa = 'V';

  /// 保存用户私钥
  /// @param key - 私钥对象
  /// @param type - 密钥类型（'M'匹配meta.key；'V'匹配visa.key）
  /// @param user - 用户ID
  /// @param sign - 是否用于签名（默认1=是）
  /// @param decrypt - 是否用于解密（必填）
  /// @return 操作结果：false=失败
  Future<bool> savePrivateKey(PrivateKey key,String type,ID user,
      {int sign = 1,required int decrypt});

  /// 获取用户用于解密的所有私钥
  /// @param user - 用户ID
  /// @return 解密密钥列表
  Future<List<DecryptKey>> getPrivateKeysForDecryption(ID user);

  /// 获取用户用于签名的私钥（第一个匹配的）
  /// @param user - 用户ID
  /// @return 签名私钥（null=未找到）
  Future<PrivateKey?> getPrivateKeyForSignature(ID user);

  /// 获取用户用于签证（Visa）签名的私钥
  /// @param user - 用户ID
  /// @return 匹配meta.key的私钥（null=未找到）
  Future<PrivateKey?> getPrivateKeyForVisaSignature(ID user);

  //
  //  便捷转换方法
  //

  /// 将私钥列表转换为解密密钥列表
  /// @param privateKeys - 私钥列表
  /// @return 解密密钥列表（过滤出DecryptKey类型）
  static List<DecryptKey> convertDecryptKeys(Iterable<PrivateKey> privateKeys){
    List<DecryptKey> decryptKeys = [];
    for(PrivateKey key in privateKeys){
      if(key is DecryptKey){
        decryptKeys.add(key as DecryptKey);
      }
    }
    return decryptKeys;
  }

  /// 将解密密钥列表转换为私钥列表
  /// @param decryptKeys - 解密密钥列表
  /// @return 私钥列表（过滤出PrivateKey类型）
  static List<PrivateKey> convertPrivateKeys(Iterable<DecryptKey> decryptKeys){
    List<PrivateKey> privateKeys = [];
    for(DecryptKey key in decryptKeys){
      if(key is PrivateKey){
        privateKeys.add(key as PrivateKey);
      }
    }
    return privateKeys;
  }

  /// 将私钥列表转换为字典列表（用于存储）
  /// @param privateKeys - 私钥列表
  /// @return 字典列表（每个私钥转为Map）
  static List<Map> revertPrivateKeys(Iterable<PrivateKey> privateKeys) {
    List<Map> array = [];
    for (PrivateKey key in privateKeys) {
      array.add(key.toMap());
    }
    return array;
  }

  /// 将密钥插入列表并调整顺序（保持最新在前，最多保留3个）
  /// @param key - 要插入的密钥
  /// @param privateKeys - 现有密钥列表
  /// @return 调整后的列表（null=无变化）
  static List<PrivateKey>? insertKey(PrivateKey key, List<PrivateKey> privateKeys) {
    int index = findKey(key, privateKeys);
    if (index == 0) {
      // 密钥已在首位，无变化
      return null;
    } else if (index > 0) {
      // 密钥在列表中，移到首位
      privateKeys.removeAt(index);
    } else if (privateKeys.length > 2) {
      // 列表超过3个，移除最后一个
      privateKeys.removeAt(privateKeys.length - 1);
    }
    // 插入到首位
    privateKeys.insert(0, key);
    return privateKeys;
  }

  /// 在列表中查找指定密钥（通过data字段匹配）
  /// @param key - 要查找的密钥
  /// @param privateKeys - 密钥列表
  /// @return 索引位置（-1=未找到）
  static int findKey(PrivateKey key, List<PrivateKey> privateKeys) {
    String? data = key.getString("data");
    assert(data != null && data.isNotEmpty, 'key data error: $key');
    PrivateKey item;
    for (int index = 0; index < privateKeys.length; ++index) {
      item = privateKeys.elementAt(index);
      if (item.getString('data') == data) {
        return index;
      }
    }
    return -1;
  }
}


/// 元数据数据库接口
/// 负责元数据（Meta）的存储和查询
abstract interface class MetaDBI {

  /// 保存实体的元数据
  /// @param meta - 元数据对象
  /// @param entity - 实体ID（用户/群组）
  /// @return 操作结果：false=失败
  Future<bool> saveMeta(Meta meta, ID entity);

  /// 获取实体的元数据
  /// @param entity - 实体ID（用户/群组）
  /// @return 元数据（null=未找到）
  Future<Meta?> getMeta(ID entity);

}

/// 文档数据库接口
/// 负责各类文档（Document）的存储和查询（如Visa、Profile等）
abstract interface class DocumentDBI {

  /// 保存文档
  /// @param doc - 文档对象
  /// @return 操作结果：false=失败
  Future<bool> saveDocument(Document doc);

  /// 获取实体的所有文档
  /// @param entity - 实体ID（用户/群组）
  /// @return 文档列表
  Future<List<Document>> getDocuments(ID entity);

}

/// 用户数据库接口
/// 负责本地用户列表的管理
abstract interface class UserDBI {

  /// 获取本地用户列表
  /// @return 本地用户ID列表
  Future<List<ID>> getLocalUsers();

  /// 保存本地用户列表
  /// @param users - 本地用户ID列表
  /// @return 操作结果：false=失败
  Future<bool> saveLocalUsers(List<ID> users);

}

/// 联系人数据库接口
/// 负责用户联系人列表的管理
abstract interface class ContactDBI {

  /// 获取指定用户的联系人列表
  /// @param user - 用户ID
  /// @return 联系人ID列表
  Future<List<ID>> getContacts({required ID user});

  /// 保存指定用户的联系人列表
  /// @param contacts - 联系人ID列表
  /// @param user - 用户ID
  /// @return 操作结果：false=失败
  Future<bool> saveContacts(List<ID> contacts, {required ID user});

}

/// 群组数据库接口
/// 负责群组信息（创始人/群主/成员/管理员/机器人）的管理
abstract interface class GroupDBI {

  /// 获取群组创始人
  /// @param group - 群组ID
  /// @return 创始人ID（null=未找到）
  Future<ID?> getFounder({required ID group});

  /// 获取群组群主
  /// @param group - 群组ID
  /// @return 群主ID（null=未找到）
  Future<ID?> getOwner({required ID group});

  //
  //  群组成员相关方法
  //
  
  /// 获取群组成员列表
  /// @param group - 群组ID
  /// @return 成员ID列表
  Future<List<ID>> getMembers({required ID group});

  /// 保存群组成员列表
  /// @param members - 成员ID列表
  /// @param group - 群组ID
  /// @return 操作结果：false=失败
  Future<bool> saveMembers(List<ID> members, {required ID group});

  //
  //  群组机器人相关方法
  //
  
  /// 获取群组机器人（助手）列表
  /// @param group - 群组ID
  /// @return 机器人ID列表
  Future<List<ID>> getAssistants({required ID group});

  /// 保存群组机器人（助手）列表
  /// @param bots - 机器人ID列表
  /// @param group - 群组ID
  /// @return 操作结果：false=失败
  Future<bool> saveAssistants(List<ID> bots, {required ID group});

  //
  //  群组管理员相关方法
  //
  
  /// 获取群组管理员列表
  /// @param group - 群组ID
  /// @return 管理员ID列表
  Future<List<ID>> getAdministrators({required ID group});

  /// 保存群组管理员列表
  /// @param members - 管理员ID列表
  /// @param group - 群组ID
  /// @return 操作结果：false=失败
  Future<bool> saveAdministrators(List<ID> members, {required ID group});

}

/// 群组历史记录数据库接口
/// 负责群组命令历史的存储和查询
abstract interface class GroupHistoryDBI {

  /// 保存群组命令历史
  /// 支持的命令类型：invite/expel(废弃)/join/quit/reset/resign
  /// @param content - 群组命令内容
  /// @param rMsg - 可靠消息对象
  /// @param group - 群组ID
  /// @return 操作结果：false=失败
  Future<bool> saveGroupHistory(GroupCommand content, ReliableMessage rMsg, {required ID group});

  /// 加载群组命令历史
  /// 支持的命令类型：invite/expel(废弃)/join/quit/reset/resign
  /// @param group - 群组ID
  /// @return 命令-消息对列表
  Future<List<Pair<GroupCommand, ReliableMessage>>> getGroupHistories({required ID group});

  /// 加载最后一条reset群组命令
  /// @param group - 群组ID
  /// @return reset命令-消息对（null=未找到）
  Future<Pair<ResetCommand?, ReliableMessage?>> getResetCommandMessage({required ID group});

  /// 清空群组成员相关命令历史
  /// 清空的命令类型：invite/expel(废弃)/join/quit/reset
  /// @param group - 群组ID
  /// @return 操作结果：false=失败
  Future<bool> clearGroupMemberHistories({required ID group});

  /// 清空群组管理员相关命令历史
  /// 清空的命令类型：resign
  /// @param group - 群组ID
  /// @return 操作结果：false=失败
  Future<bool> clearGroupAdminHistories({required ID group});

}

/// 账户数据库总接口
/// 整合所有账户相关的数据库接口，提供统一的账户数据访问入口
abstract interface class AccountDBI implements PrivateKeyDBI,
                                               MetaDBI, DocumentDBI,
                                               UserDBI, ContactDBI,
                                               GroupDBI, GroupHistoryDBI {

}