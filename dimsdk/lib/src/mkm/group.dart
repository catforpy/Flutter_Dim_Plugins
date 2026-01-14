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

/// 群组实体核心接口
/// 继承 Entity 接口，新增群组专属能力和角色体系，
/// 核心角色：创建者（永久）、所有者（可变更）、成员、助手（机器人）
abstract interface class Group implements Entity{
  
  /// 群组公告文档（群组核心配置，包含群名称/公告/权限等）
  Future<Bulletin?> get bulletin;

  /// 群组创建者（永久不变，与元数据公钥对应）
  Future<ID> get founder;
  
  /// 群组所有者（可变更，通常是第一个成员）
  Future<ID> get owner;

  // 注意：所有者必须是群成员（通常是第一个成员）
  /// 群成员列表
  Future<List<ID>> get members;

  /// 群组助手（机器人/Bot，辅助管理群组）
  Future<List<ID>> get assistants;
}

/// 群组数据获取源接口
/// 继承 EntityDataSource，新增群组专属数据的获取规范，
/// 定义创建者/所有者/成员/助手的获取方法，支持不同存储方案
abstract interface class GroupDataSource implements EntityDataSource {
  /// 获取群组创建者ID
  /// @param group - 群组ID
  /// @return 创建者ID，无则返回null
  Future<ID?> getFounder(ID group);

  /// 获取群组所有者ID
  /// @param group - 群组ID
  /// @return 所有者ID，无则返回null
  Future<ID?> getOwner(ID group);

  /// 获取群成员列表
  /// @param group - 群组ID
  /// @return 成员ID列表
  Future<List<ID>> getMembers(ID group);

  /// 获取群组助手（机器人）列表
  /// @param group - 群组ID
  /// @return 助手ID列表
  Future<List<ID>> getAssistants(ID group);
}

/// 群组基类实现，提供通用能力
class BaseGroup extends BaseEntity implements Group {
  /// 构造方法：初始化群组基类
  /// @param id - 群组ID
  BaseGroup(super.id);

  /// 群组创建者缓存（创建者永不改变，缓存提升性能）
  ID? _founder;

  /// 强类型数据获取源：强制转换为 GroupDataSource，保证类型安全
  @override
  GroupDataSource? get dataSource {
    var facebook = super.dataSource;
    if (facebook is GroupDataSource) {
      return facebook;
    }
    assert(facebook == null, '群组数据源类型错误: $facebook');
    return null;
  }

  //===== Group 接口实现 =====
  @override
  Future<Bulletin?> get bulletin async =>
      // 自动筛选最新有效公告文档
      DocumentUtils.lastBulletin(await documents);

  @override
  Future<ID> get founder async {
    // 缓存创建者，避免重复获取
    _founder ??= await dataSource!.getFounder(identifier);
    return _founder!;
  }

  @override
  Future<ID> get owner async =>
      // 委托数据源获取所有者ID
      (await dataSource!.getOwner(identifier))!;

  @override
  Future<List<ID>> get members async =>
      // 委托数据源获取成员列表
      await dataSource!.getMembers(identifier);

  @override
  Future<List<ID>> get assistants async =>
      // 委托数据源获取助手列表
      await dataSource!.getAssistants(identifier);
}