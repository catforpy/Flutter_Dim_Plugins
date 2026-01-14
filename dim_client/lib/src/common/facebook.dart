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
import 'package:dimsdk/dimsdk.dart';

/// 通用Facebook抽象类（带数据库支持）
/// 实现用户/群组管理、Meta/文档获取、当前用户管理等核心功能
abstract class CommonFacebook extends Facebook with Logging {
  /// 构造方法
  /// [database] 账户数据库接口
  CommonFacebook(this.database);

  /// 账户数据库接口
  final AccountDBI database;

  /// 档案管理员实例（兵营）
  CommonArchivist? _barrack;
  /// 实体检查器实例
  EntityChecker? entityChecker;

  /// 当前登录用户
  User? _currentUser;

  @override
  Archivist? get archivist => _barrack;

  @override
  CommonArchivist? get barrack => _barrack;
  set barrack(CommonArchivist? archivist) => _barrack = archivist;

  //
  //  当前用户管理
  //

  /// 获取当前登录用户（用于签名和发送消息）
  /// 返回：当前用户（无本地用户返回null）
  Future<User?> get currentUser async {
    // 优先从缓存获取当前用户
    User? current = _currentUser;
    if (current != null) {
      return current;
    }
    // 从数据库获取本地用户列表
    List<ID> array = await database.getLocalUsers();
    if (array.isEmpty) {
      // 无本地用户
      return null;
    }
    // 断言：本地用户无签名私钥（调试模式触发）
    assert(await getPrivateKeyForSignature(array.first) != null, 'user error: ${array.first}');
    // 获取第一个本地用户作为当前用户
    current = await getUser(array.first);
    _currentUser = current;
    return current;
  }

  /// 设置当前登录用户
  /// [user] 要设置的用户
  Future<void> setCurrentUser(User user) async {
    // 设置用户数据源为当前Facebook实例（为空时）
    user.dataSource ??= this;
    _currentUser = user;
  }

  /// 选择本地用户（用于解密消息）
  /// [receiver] 消息接收方ID
  /// 返回：用于解密的本地用户ID
  @override
  Future<ID?> selectLocalUser(ID receiver) async {
    User? user = _currentUser;
    if (user != null) {
      ID current = user.identifier;
      if (receiver.isBroadcast) {
        // 广播消息可被任何人解密，直接返回当前用户
        return current;
      } else if (receiver.isGroup) {
        // 群组消息（接收方未指定）
        // 信使会先检查群组信息，因此群组的Meta和成员必存在
        List<ID> members = await getMembers(receiver);
        if (members.isEmpty) {
          // 断言：群成员为空（调试模式触发）
          assert(false, 'members not found: $receiver');
          return null;
        } else if (members.contains(current)) {
          // 当前用户是群成员，返回当前用户
          return current;
        }
      } else if (receiver == current) {
        // 接收方是当前用户，直接返回
        return current;
      }
    }
    // 检查其他本地用户（调用父类方法）
    return await super.selectLocalUser(receiver);
  }

  //
  //  文档获取工具方法
  //

  /// 获取指定类型的最新文档
  /// [identifier] 实体ID
  /// [type] 文档类型（可选，默认获取所有类型）
  /// 返回：最新的文档（无对应类型返回null）
  Future<Document?> getDocument(ID identifier, [String? type]) async {
    // 获取实体的所有文档
    List<Document> documents = await getDocuments(identifier);
    // 获取指定类型的最新文档
    Document? doc = DocumentUtils.lastDocument(documents, type);
    // 兼容处理：VISA类型未找到时，尝试获取PROFILE类型
    if (doc == null && type == DocumentType.VISA) {
      doc = DocumentUtils.lastDocument(documents, DocumentType.PROFILE);
    }
    return doc;
  }

  /// 获取用户的最新Visa文档
  /// [user] 用户ID
  /// 返回：最新的Visa文档（无返回null）
  Future<Visa?> getVisa(ID user) async {
    List<Document> documents = await getDocuments(user);
    return DocumentUtils.lastVisa(documents);
  }

  /// 获取群组的最新Bulletin文档
  /// [group] 群组ID
  /// 返回：最新的Bulletin文档（无返回null）
  Future<Bulletin?> getBulletin(ID group) async {
    List<Document> documents = await getDocuments(group);
    return DocumentUtils.lastBulletin(documents);
  }

  /// 获取实体的显示名称
  /// [identifier] 实体ID
  /// 返回：文档中的名称（无则返回匿名名称）
  Future<String> getName(ID identifier) async {
    // 根据实体类型确定文档类型
    String type;
    if (identifier.isUser) {
      type = DocumentType.VISA;
    } else if (identifier.isGroup) {
      type = DocumentType.BULLETIN;
    } else {
      type = '*';
    }
    // 从文档中获取名称
    Document? doc = await getDocument(identifier, type);
    if (doc != null) {
      String? name = doc.name;
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }
    // 文档中无名称，返回匿名名称
    return Anonymous.getName(identifier);
  }

  /// 获取用户的头像
  /// [user] 用户ID
  /// 返回：用户头像（无返回null）
  Future<PortableNetworkFile?> getAvatar(ID user) async {
    Visa? doc = await getVisa(user);
    return doc?.avatar;
  }

  //
  //  Entity DataSource 接口实现
  //

  /// 获取实体的Meta（自动检查是否需要查询）
  /// [identifier] 实体ID
  /// 返回：实体的Meta（无返回null）
  @override
  Future<Meta?> getMeta(ID identifier) async {
    // 从数据库获取Meta
    var meta = await database.getMeta(identifier);
    // 检查是否需要查询Meta（非阻塞调用）
    /*await */entityChecker?.checkMeta(identifier, meta);
    return meta;
  }

  /// 获取实体的文档列表（自动检查是否需要查询）
  /// [identifier] 实体ID
  /// 返回：实体的文档列表（无返回空列表）
  @override
  Future<List<Document>> getDocuments(ID identifier) async {
    // 从数据库获取文档列表
    var docs = await database.getDocuments(identifier);
    // 检查是否需要查询文档（非阻塞调用）
    /*await */entityChecker?.checkDocuments(identifier, docs);
    return docs;
  }

  //
  //  User DataSource 接口实现
  //

  /// 获取用户的联系人列表
  /// [user] 用户ID
  /// 返回：联系人ID列表
  @override
  Future<List<ID>> getContacts(ID user) async =>
      await database.getContacts(user: user);

  /// 获取用户的解密私钥列表
  /// [user] 用户ID
  /// 返回：解密私钥列表
  @override
  Future<List<DecryptKey>> getPrivateKeysForDecryption(ID user) async =>
      await database.getPrivateKeysForDecryption(user);

  /// 获取用户的签名私钥
  /// [user] 用户ID
  /// 返回：签名私钥（无返回null）
  @override
  Future<SignKey?> getPrivateKeyForSignature(ID user) async =>
      await database.getPrivateKeyForSignature(user);

  /// 获取用户的Visa签名私钥
  /// [user] 用户ID
  /// 返回：Visa签名私钥（无返回null）
  @override
  Future<SignKey?> getPrivateKeyForVisaSignature(ID user) async =>
      await database.getPrivateKeyForVisaSignature(user);

  //
  //  组织结构管理（需子类实现）
  //

  /// 获取群组的管理员列表
  /// [group] 群组ID
  /// 返回：管理员ID列表
  Future<List<ID>> getAdministrators(ID group);

  /// 保存群组的管理员列表
  /// [admins] 管理员ID列表
  /// [group] 群组ID
  /// 返回：true=保存成功，false=保存失败
  Future<bool> saveAdministrators(List<ID> admins, ID group);

  /// 保存群组的成员列表
  /// [newMembers] 新成员ID列表
  /// [group] 群组ID
  /// 返回：true=保存成功，false=保存失败
  Future<bool> saveMembers(List<ID> newMembers, ID group);
}