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

import 'dart:typed_data';

import 'package:dimsdk/dimp.dart';
import 'package:dimsdk/mkm.dart';

/// 用户实体核心接口
/// 继承 Entity 接口，定义用户专属能力：
/// 1. 基础信息：签证文档、联系人列表；
/// 2. 安全能力：验签、加密（所有用户），签名、解密（仅本地用户）；
/// 3. 签证管理：签名/验证签证文档。
abstract interface class User implements Entity {
  /// 用户签证文档（身份扩展信息，包含昵称/头像/公钥等）
  Future<Visa?> get visa;

  /// 获取用户所有联系人列表
  /// @return 联系人ID列表
  Future<List<ID>> get contacts;

  /// 使用用户公钥验证数据和签名
  /// 核心逻辑：尝试所有验签公钥，任一匹配即通过
  /// @param data - 消息数据
  /// @param signature - 消息签名
  /// @return 验证通过返回true，否则返回false
  Future<bool> verify(Uint8List data, Uint8List signature);

  /// 加密数据（优先使用签证公钥，无则使用元数据公钥）
  /// 支持密钥轮换，提升安全性
  /// @param plaintext - 明文数据
  /// @return 加密后的数据
  Future<Uint8List> encrypt(Uint8List plaintext);

  //===== 本地用户专属接口（需私钥，仅本地可执行）=====
  /// 使用用户私钥签名数据
  /// @param data - 消息数据
  /// @return 签名结果
  Future<Uint8List> sign(Uint8List data);

  /// 使用用户私钥解密密文数据
  /// 核心逻辑：尝试所有解密私钥，任一成功即返回
  /// @param ciphertext - 密文数据
  /// @return 解密后的明文，失败返回null
  Future<Uint8List?> decrypt(Uint8List ciphertext);

  //===== 签证管理接口 =====
  /// 签名签证文档（仅本地用户可执行）
  /// @param doc - 待签名的签证文档
  /// @return 签名后的签证文档，失败返回null
  Future<Visa?> signVisa(Visa doc);

  /// 验证签证文档（所有用户可执行）
  /// @param doc - 待验证的签证文档
  /// @return 验证通过返回true，否则返回false
  Future<bool> verifyVisa(Visa doc);
}

/// 用户数据获取源接口
/// 继承 EntityDataSource，定义用户专属数据（尤其是密钥）的获取规范，
/// 剥离密钥管理逻辑，支持不同存储方案（本地安全存储/硬件加密）。
abstract interface class UserDataSource implements EntityDataSource {
  /// 获取用户联系人列表
  /// @param user - 用户ID
  /// @return 联系人ID列表
  Future<List<ID>> getContacts(ID user);

  /// 获取用户加密公钥（优先签证公钥）
  /// @param user - 用户ID
  /// @return 加密公钥，无则返回null
  Future<EncryptKey?> getPublicKeyForEncryption(ID user);

   /// 获取用户验签公钥列表（签证+元数据）
  /// @param user - 用户ID
  /// @return 验签公钥列表
  Future<List<VerifyKey>> getPublicKeysForVerification(ID user);

  /// 获取用户解密私钥列表
  /// @param user - 用户ID
  /// @return 解密私钥列表
  Future<List<DecryptKey>> getPrivateKeysForDecryption(ID user);

  /// 获取用户签名私钥
  /// @param user - 用户ID
  /// @return 签名私钥，无则返回null
  Future<SignKey?> getPrivateKeyForSignature(ID user);

  /// 获取用户签证签名私钥（仅元数据配对私钥）
  /// @param user - 用户ID
  /// @return 签证签名私钥，无则返回null
  Future<SignKey?> getPrivateKeyForVisaSignature(ID user);
}

/// 用户基类实现，提供通用能力
/// 封装 User 接口的通用实现逻辑，核心依赖外部注入的 UserDataSource 获取密钥/联系人等数据，
/// 本身不存储敏感信息（如私钥），仅负责执行加解密、签名验签等业务流程。
class BaseUser extends BaseEntity implements User {
  /// 构造方法：初始化用户基类
  /// @param id - 用户唯一标识（ID）
  BaseUser(super.id);

  /// 强类型数据获取源：强制转换为 UserDataSource，保证类型安全
  /// 重写父类的 dataSource 获取器，将通用的 EntityDataSource 强转为 UserDataSource，
  /// 若类型不匹配则触发断言报错，避免运行时类型错误。
  @override
  UserDataSource? get dataSource {
    var facebook = super.dataSource;
    if (facebook is UserDataSource) {
      return facebook;
    }
    assert(facebook == null, '用户数据源类型错误: $facebook');
    return null;
  }

  //===== User 接口实现 =====
  /// 获取用户最新有效签证文档
  /// 从用户文档列表中筛选出最新的、有效的 Visa 文档，
  /// 签证文档包含用户昵称、头像、最新公钥等扩展身份信息。
  /// @return 最新有效签证文档，无则返回 null
  @override
  Future<Visa?> get visa async =>
      //筛选最新有效签证文档
      DocumentUtils.lastVisa(await documents);

  /// 获取用户所有联系人列表
  /// 委托给 UserDataSource 实现具体的联系人获取逻辑（如从本地数据库/服务器拉取），
  /// 本方法仅做统一入口封装，不处理具体存储细节。
  /// @return 联系人ID列表（非空，数据源未设置会触发断言）
  @override
  Future<List<ID>> get contacts async =>
      // 委托数据源获取联系人列表
      await dataSource!.getContacts(identifier);

  /// 使用用户公钥验证数据和签名的合法性
  /// 核心逻辑：遍历数据源提供的所有验签公钥（签证公钥 + 元数据公钥），
  /// 只要有一个公钥验证通过，即判定签名合法；全部失败则返回 false。
  /// @param data - 原始消息数据（待验证的明文）
  /// @param signature - 消息签名（私钥对 data 签名的结果）
  /// @return 验证通过返回 true，否则返回 false；数据源未设置/无验签公钥会触发断言
  @override
  Future<bool> verify(Uint8List data, Uint8List signature) async {
    UserDataSource? facebook = dataSource;
    assert(facebook != null, '用户数据源未设置');
    // 获取所有验签公钥（签证公钥 + 元数据公钥）
    List<VerifyKey>? keys = await facebook?.getPublicKeysForVerification(identifier);
    if (keys == null || keys.isEmpty) {
      assert(false, '获取验签公钥失败: $identifier');
      return false;
    }
    // 尝试所有公钥验签，任一匹配即通过
    for (VerifyKey pKey in keys) {
      if (pKey.verify(data, signature)) {
        return true;
      }
    }
    // 验签失败（TODO：检查签证是否过期，获取最新文档重试）
    return false;
  }

  /// 加密明文数据（仅对其他用户使用，本地用户加密用自己的公钥无意义）
  /// 核心逻辑：优先使用用户最新签证文档中的加密公钥（支持密钥轮换），
  /// 若无则使用元数据公钥；加密算法由公钥类型决定（如RSA/AES）。
  /// @param plaintext - 待加密的明文数据
  /// @return 加密后的密文数据；数据源未设置/无加密公钥会触发断言
  @override
  Future<Uint8List> encrypt(Uint8List plaintext) async {
    UserDataSource? facebook = dataSource;
    assert(facebook != null, '用户数据源未设置');
    // 优先使用签证公钥加密（支持密钥轮换，提升安全性）
    EncryptKey? pKey = await facebook?.getPublicKeyForEncryption(identifier);
    assert(pKey != null, '获取加密公钥失败: $identifier');
    return pKey!.encrypt(plaintext);
  }

  //===== 本地用户专属方法实现（需私钥，仅本地可执行）=====
  /// 使用本地用户私钥对数据签名
  /// 仅本地用户可调用（远程用户无私钥），签名结果可用于身份认证、消息防篡改。
  /// @param data - 待签名的原始数据
  /// @return 私钥签名后的字节数据；数据源未设置/无签名私钥会触发断言
  @override
  Future<Uint8List> sign(Uint8List data) async {
    UserDataSource? facebook = dataSource;
    assert(facebook != null, '用户数据源未设置');
    // 获取本地用户的签名私钥（从安全存储中读取）
    SignKey? sKey = await facebook?.getPrivateKeyForSignature(identifier);
    assert(sKey != null, '获取签名私钥失败: $identifier');
    return sKey!.sign(data);
  }

  /// 使用本地用户私钥解密密文数据
  /// 仅本地用户可调用，核心逻辑：遍历所有解密私钥（支持密钥轮换），
  /// 尝试解密，任一私钥解密成功即返回明文，全部失败则返回 null。
  /// @param ciphertext - 待解密的密文数据
  /// @return 解密后的明文数据，解密失败/无解密私钥返回 null；数据源未设置会触发断言
  @override
  Future<Uint8List?> decrypt(Uint8List ciphertext) async {
    UserDataSource? facebook = dataSource;
    assert(facebook != null, '用户数据源未设置');
    // 获取本地用户的所有解密私钥（支持密钥轮换，兼容旧密钥）
    List<DecryptKey>? keys = await facebook?.getPrivateKeysForDecryption(identifier);
    if (keys == null || keys.isEmpty) {
      assert(false, '获取解密私钥失败: $identifier');
      return null;
    }
    // 尝试所有私钥解密，任一成功即返回明文
    Uint8List? plaintext;
    for (DecryptKey key in keys) {
      plaintext = key.decrypt(ciphertext);
      if (plaintext != null) {
        return plaintext;
      }
    }
    // 解密失败（TODO：检查签证密钥是否变更，推送新签证给对方）
    return null;
  }

  /// 签名签证文档（仅本地用户可执行）
  /// 核心规则：仅使用元数据配对的私钥签名签证，保证签证的合法性和不可篡改性，
  /// 签名后的签证可对外发布，供其他用户验证身份。
  /// @param doc - 待签名的签证文档（ID需与当前用户ID一致）
  /// @return 签名后的签证文档，签名失败/无签证签名私钥返回 null；ID不匹配/数据源未设置会触发断言
  @override
  Future<Visa?> signVisa(Visa doc) async {
    ID did = doc.identifier;
    // 校验签证ID与用户ID一致性，避免签错他人签证
    assert(did == identifier, '签证ID不匹配: $identifier, $did');
    UserDataSource? facebook = dataSource;
    assert(facebook != null, '用户数据源未设置');
    // 仅使用元数据配对私钥签名签证（核心安全规则，区别于普通消息签名）
    SignKey? sKey = await facebook?.getPrivateKeyForVisaSignature(did);
    if (sKey == null) {
      assert(false, '获取签证签名私钥失败: $did');
      return null;
    }
    // 调用签证文档的签名方法，完成签名
    if (doc.sign(sKey) == null) {
      assert(false, '签证签名失败: $did, $doc');
      return null;
    }
    return doc;
  }

  /// 验证签证文档的合法性
  /// 核心规则：仅使用用户元数据公钥验证签证签名（元数据不可篡改，保证根信任），
  /// 签证ID与当前用户ID不一致时直接返回 false。
  /// @param doc - 待验证的签证文档
  /// @return 验证通过返回 true，否则返回 false；ID不匹配直接返回 false
  @override
  Future<bool> verifyVisa(Visa doc) async {
    ID did = doc.identifier;
    // 签证ID与用户ID不一致，无需验证直接失败
    if (identifier != did) {
      return false;
    }
    // 仅使用元数据公钥验证签证（根信任，避免签证自身公钥被篡改）
    VerifyKey pKey = (await meta).publicKey;
    return doc.verify(pKey);
  }
}