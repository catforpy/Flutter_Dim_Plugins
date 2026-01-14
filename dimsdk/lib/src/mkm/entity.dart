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

/// 所有身份实体（用户/群组）的基类接口
/// 定义身份实体的最小契约，统一 User/Group 的基础行为，
/// 核心包含：唯一标识、实体类型、数据获取源、元数据/文档获取能力
abstract interface class Entity{
  /// 实体唯一标识（用户/群组ID）
  ID get identifier;

  /// 实体类型（对应 EntityType 枚举：用户/群组/机器人/服务器等）
  int get type;

  /// 数据获取源（弱引用，避免内存泄漏，支持动态替换）
  EntityDataSource? get dataSource;
  set dataSource(EntityDataSource? delegate);

  /// 获取实体元数据（身份合法性的核心依据，不可随意修改）
  Future<Meta> get meta;
  
  /// 获取实体文档列表（用户签证/群组公告等扩展信息）
  Future<List<Document>> get documents;
}

/// 实体数据获取源接口
/// 剥离数据存储/获取逻辑，定义元数据、文档的获取规范，
/// 支持不同存储方案（本地/网络），实现数据层与业务层解耦
abstract interface class EntityDataSource {
  /// 根据实体ID获取元数据
  /// @param identifier - 实体ID
  /// @return 元数据对象，无则返回null
  Future<Meta?> getMeta(ID identifier);

  /// 根据实体ID获取文档列表
  /// @param identifier - 实体ID
  /// @return 文档列表（签证/公告等）
  Future<List<Document>> getDocuments(ID identifier);
}

/// 实体实例化委托接口
/// 定义 User/Group 实例的创建规范，实现实体实例化的统一入口
abstract interface class EntityDelegate{
  /// 根据用户ID创建 User 实例
  /// @param identifier - 用户ID
  /// @return User实例，无则返回null
  Future<User?> getUser(ID identifier);

  /// 根据群组ID创建 Group 实例
  /// @param identifier - 群组ID
  /// @return Group实例，无则返回null
  Future<Group?> getGroup(ID identifier);
}

/// 实体基类实现，提供通用能力
class BaseEntity implements Entity{ 
  /// 构造方法：初始化实体基类
  /// @param _id - 实体唯一标识
  BaseEntity(this._id);

  /// 实体唯一标识（核心属性，不可修改）
  final ID _id;

  /// 数据获取源（弱引用，避免循环引用导致的内存泄漏）
  WeakReference<EntityDataSource>? _facebook;

  /// 相等性判断：基于ID实现，同ID即同实体
  @override
  bool operator ==(Object other){
    if(other is Entity){
      if(identical(this, other)){
        // 同一实例直接相等
        return true;
      }
      // 对比实体ID
      other = other.identifier;
    }
    return _id == other;
  }

  /// 哈希值：基于ID生成，保证相等性判断一致性
  @override
  int get hashCode => _id.hashCode;

  /// 获取运行时类名（调试用）
  String get className {
    String name = 'Entity';
    assert(() {
      name = runtimeType.toString();
      return true;
    }());
    return name;
  }

  /// 字符串格式化（调试用）
  @override
  String toString() {
    String clazz = className;
    int network = _id.address.network;
    return '<$clazz id="$_id" network=$network />';
  }

  //===== Entity 接口实现 =====
  @override
  ID get identifier => _id;

  @override
  int get type => _id.type;

  @override
  EntityDataSource? get dataSource => _facebook?.target;

  @override
  set dataSource(EntityDataSource? facebook) =>
      _facebook = facebook == null ? null : WeakReference(facebook);

  @override
  Future<Meta> get meta async =>
      // 委托数据源获取元数据，断言确保数据源已设置
      (await dataSource!.getMeta(_id))!;

  @override
  Future<List<Document>> get documents async =>
      // 委托数据源获取文档列表
      await dataSource!.getDocuments(_id);
}