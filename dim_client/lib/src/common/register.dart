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
import 'dart:math';
import 'dart:typed_data';

import 'package:dimsdk/dimsdk.dart';

import 'dbi/account.dart';

/// 账户注册工具类
/// 负责生成用户/群组账户，包括私钥、Meta、ID、Visa/Bulletin等核心数据
class Register {

  /// 构造方法
  /// [database] 账户数据库接口
  Register(this.database);

  /// 账户数据库接口（用于持久化账户数据）
  final AccountDBI database;

    /// 生成用户账户（核心方法）
  /// [name] 用户名（昵称）
  /// [avatar] 头像信息（可选）
  /// 返回：生成的用户ID
  Future<ID> createUser({required String name, PortableNetworkFile? avatar}) async {
    //
    //  步骤1、生成私钥（使用飞堆成加密算法ECC）
    //
    PrivateKey idKey = PrivateKey.generate(AsymmetricAlgorithms.ECC)!;
    //
    //  步骤2、使用私钥生成Meta(ETH类型)
    //
    Meta meta = Meta.generate(MetaType.ETH, idKey);
    //
    //  步骤3、使用Meta生成ID
    //
    ID identifier = ID.generate(meta,EntityType.USER);
    //
    //  步骤4：生成Visa文档并使用私钥签名
    //
    //  生成RSA私钥（用于消息加密）
    PrivateKey? msgKey = PrivateKey.generate(AsymmetricAlgorithms.RSA);
    //  获取Visa公钥（用于加密）
    EncryptKey visaKey = msgKey!.publicKey as EncryptKey;
    //  创建Visa文档
    Visa visa = createVisa(identifier,visaKey,idKey,name:name,avatar:avatar);
    //
    //  步骤5：保存私钥、Meta、Visa到本地存储
    //
    // 保存Meta私钥（解密标识0）
    await database.savePrivateKey(idKey, PrivateKeyDBI.kMeta, identifier, decrypt: 0);
    // 保存Visa私钥（解密标识1）
    await database.savePrivateKey(msgKey, PrivateKeyDBI.kVisa, identifier, decrypt: 1);
    // 保存Meta
    await database.saveMeta(meta, identifier);
    // 保存Visa文档
    await database.saveDocument(visa);
    // OK
    return identifier;
  }

  /// 生成群组账户（核心方法）
  /// [founder] 群组创始人ID
  /// [name] 群组名称
  /// [seed] ID名称（可选，为空则随机生成）
  /// 返回：生成的群组ID
  Future<ID> createGroup(ID founder, {required String name, String? seed}) async {
    // 生成随机seed（为空时）
    if(seed == null || seed.isEmpty){
      Random random = Random();
      // 生成10000 ~ 999999999之间的随机数
      int r = random.nextInt(999990000) + 10000;
      seed = 'Group-$r';
    }
    //
    //  步骤1：获取创始人的私钥（用于Visa签名）
    //
    SignKey privateKey = (await database.getPrivateKeyForVisaSignature(founder))!;
    //
    //  步骤2：使用创始人私钥生成Meta（MKM类型）
    //
    Meta meta = Meta.generate(MetaType.MKM, privateKey,seed: seed);
    //
    //  步骤3：使用Meta生成群组ID
    //
    ID identifier = ID.generate(meta, EntityType.GROUP);
    //
    //  步骤4：生成Bulletin文档并使用创始人私钥签名
    //
    Bulletin doc = createBulletin(identifier,privateKey,name:name,founder:founder);
    //
    //  步骤5：保存Meta和Bulletin到本地存储
    //
    await database.saveMeta(meta, identifier);
    await database.saveDocument(doc);
    //
    //  步骤6：添加创始人作为第一个群成员
    //
    List<ID> members = [founder];
    await database.saveMembers(members, group: identifier);
    // OK
    return identifier;
  }

  /// 创建用户Visa文档
  /// [identifier] 用户ID
  /// [visaKey] Visa公钥（用于加密）
  /// [idKey] 签名私钥
  /// [name] 用户名
  /// [avatar] 头像信息（可选）
  /// 返回：签名后的Visa文档
  static Visa createVisa(ID identifier, EncryptKey visaKey, SignKey idKey,
      {required String name, PortableNetworkFile? avatar}) {
    assert(identifier.isUser, 'user ID error: $identifier');
    // 从用户ID创建基础visa文档
    Visa doc = BaseVisa.from(identifier);
    // 设置App ID
    doc.setProperty('app_id', 'chat.dim.tarsier');
    // 设置昵称
    doc.name = name;
    // 设置头像
    if(avatar != null){
      doc.avatar = avatar;
    }
    // 设置公钥
    doc.publicKey = visaKey;
    // 签名Visa文档
    Uint8List? sig = doc.sign(idKey);
    assert(sig != null, 'failed to sign visa: $identifier');
    return doc;
  }

  /// 创建群组Bulletin文档
  /// [identifier] 群组ID
  /// [privateKey] 创始人私钥（用于签名）
  /// [name] 群组名称
  /// [founder] 群组创始人ID
  /// 返回：签名后的Bulletin文档
  static Bulletin createBulletin(ID identifier, SignKey privateKey,
      {required String name, required ID founder}) {
    assert(identifier.isGroup, 'group ID error: $identifier');
    // 从群组ID创建基础Bulletin文档
    Bulletin doc = BaseBulletin.from(identifier);
    // 设置App ID
    doc.setProperty('app_id', 'chat.dim.tarsier');
    // 设置群组创始人
    doc.setProperty('founder', founder.toString());
    // 设置群组名称
    doc.name = name;
    // 签名Bulletin文档
    Uint8List? sig = doc.sign(privateKey);
    assert(sig != null, 'failed to sign bulletin: $identifier');
    return doc;
  }
}