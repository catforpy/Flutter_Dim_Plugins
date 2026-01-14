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

import 'package:dimsdk/dimp.dart';
import 'package:dimsdk/mkm.dart';

/// DIM 协议实体管理核心类（对象池）
/// 核心作用：负责 User/Group 实例的缓存、创建，是 DIM 身份体系的基础组件，
/// 采用「工厂模式+对象池」设计，避免重复创建实体实例，提升性能，同时保证身份体系的扩展性。
/// 核心能力：
/// 1. 对象缓存：cacheUser/cacheGroup 缓存已创建的实体实例；
/// 2. 实例获取：getUser/getGroup 从缓存获取实例，避免重复创建；
/// 3. 工厂创建：createUser/createGroup 根据 ID 类型创建不同子类实例（如 Station/Bot/ServiceProvider）。
abstract class Barrack {

  /// 缓存 User 实例
  /// 核心逻辑：将创建好的 User 实例存入对象池，后续可通过 getUser 直接获取，
  /// 避免频繁创建/销毁实例，提升性能。
  /// @param user - 待缓存的 User 实例（普通用户/Station/Bot）
  void cacheUser(User user);

  /// 缓存 Group 实例
  /// 核心逻辑：将创建好的 Group 实例存入对象池，后续可通过 getGroup 直接获取。
  /// @param group - 待缓存的 Group 实例（普通群组/ServiceProvider）
  void cacheGroup(Group group);

  /// 从缓存中获取 User 实例
  /// 核心逻辑：优先从对象池读取，未命中则返回 null（需调用 createUser 创建）。
  /// @param identifier - 用户 ID（普通用户/Station/Bot 类型）
  /// @return 缓存的 User 实例；未缓存返回 null
  User? getUser(ID identifier);

  /// 从缓存中获取 Group 实例
  /// 核心逻辑：优先从对象池读取，未命中则返回 null（需调用 createGroup 创建）。
  /// @param identifier - 群组 ID（普通群组/ServiceProvider 类型）
  /// @return 缓存的 Group 实例；未缓存返回 null
  Group? getGroup(ID identifier);

  /// 创建 User 实例（工厂方法）
  /// 核心逻辑：根据 ID 的网络类型（EntityType）创建对应的 User 子类实例，
  /// 仅当 Visa 文档包含公钥时创建（保证身份合法性），是 DIM 身份体系扩展性的核心。
  /// @param identifier - 用户 ID（必须为用户类型，非用户类型触发断言）
  /// @return User 实例（Station/Bot/BaseUser）；创建失败返回 null
  User? createUser(ID identifier) {
    // 断言校验：ID 必须为用户类型，避免创建错误的实体
    assert(identifier.isUser, 'user ID error: $identifier');
    int network = identifier.type;
    //按ID类型创建不同子类实例，适配不同实体类型
    if(network == EntityType.STATION){
      // 服务器类型 ID → 创建 Station 实例（服务器抽象为特殊用户）
      return Station.fromID(identifier);
    }else if(network == EntityType.BOT){
      // 机器人类型 ID → 创建 Bot 实例
      return Bot(identifier);
    }
    // 普通用户/ANY 类型 ID → 创建基础用户实例
    return BaseUser(identifier);
  }

  /// 创建 Group 实例（工厂方法）
  /// 核心逻辑：根据 ID 的网络类型创建对应的 Group 子类实例，
  /// 仅当群组包含成员列表时创建（保证群组合法性）。
  /// @param identifier - 群组 ID（必须为群组类型，非群组类型触发断言）
  /// @return Group 实例（ServiceProvider/BaseGroup）；创建失败返回 null
  Group? createGroup(ID identifier) {
    // 断言校验：ID 必须为群组类型，避免创建错误的实体
    assert(identifier.isGroup, 'group ID error: $identifier');
    int network = identifier.type;
    // 按 ID 类型创建不同子类实例
    if(network == EntityType.ISP){
      // 服务商类型 ID → 创建 ServiceProvider 实例（服务商抽象为特殊群组）
      return ServiceProvider(identifier);
    }
    // 普通群组/EVERY 类型 ID → 创建基础群组实例
    return BaseGroup(identifier);
  }
}

/// DIM 协议实体数据存储接口（持久层）
/// 核心作用：负责 Meta（身份元数据）、Document（身份文档）、公钥的持久化存储与查询，
/// 是 DIM 去中心化身份体系的「数据持久层接口」，具体实现由客户端/服务端自行对接数据库。
/// 核心能力：
/// 1. 数据存储：saveMeta/saveDocument 存储身份核心数据（需先验证合法性）；
/// 2. 公钥查询：getMetaKey/getVisaKey 获取身份对应的公钥（用于验签/加密）；
/// 3. 本地用户：getLocalUsers 获取持有私钥的本地用户（用于解密收到的消息）。
abstract interface class Archivist {

  /// 保存实体的 Meta 元数据（需先验证合法性）
  /// 核心逻辑：Meta 是实体的核心身份数据（包含公钥），必须先验证合法性再存储，
  /// 保证身份数据不被篡改。
  /// @param meta - 待保存的 Meta 元数据
  /// @param identifier - 实体 ID（用户/群组/服务器）
  /// @return 保存成功返回 true；失败返回 false
  Future<bool> saveMeta(Meta meta, ID identifier);

  /// 保存实体的 Document 身份文档（需先验证合法性）
  /// 核心逻辑：Document 是实体的扩展身份数据（如 Visa 签证、Profile 档案），
  /// 必须先验证签名合法性再存储，避免恶意文档。
  /// @param doc - 待保存的 Document 实例（Visa/Profile 等）
  /// @return 保存成功返回 true；失败返回 false
  Future<bool> saveDocument(Document doc);

  // ======================== 公钥查询 ========================

  /// 获取实体 Meta 对应的公钥
  /// 核心逻辑：从 Meta 中提取公钥，用于验证实体签名、加密发给该实体的消息。
  /// @param identifier - 实体 ID
  /// @return Meta 中的公钥；未找到 Meta/公钥返回 null
  Future<VerifyKey?> getMetaKey(ID identifier);

  /// 获取实体 Visa 文档对应的公钥
  /// 核心逻辑：从 Visa 签证文档中提取公钥，补充 Meta 公钥的不足（如密钥轮换）。
  /// @param identifier - 实体 ID
  /// @return Visa 中的加密公钥；未找到 Visa/公钥返回 null
  Future<EncryptKey?> getVisaKey(ID identifier);

  // ======================== 本地用户 ========================

  /// 获取所有本地用户（用于解密收到的消息）
  /// 核心逻辑：本地用户持有私钥，可解密发给自己的加密消息，
  /// 该方法返回所有本地用户 ID，用于消息解密时匹配私钥。
  /// @return 本地用户 ID 列表（持有私钥）
  Future<List<ID>> getLocalUsers();
}