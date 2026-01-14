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
import 'package:dim_client/plugins.dart';

/// 联系人备注模型
/// 包含联系人ID、备注名、备注描述信息
class ContactRemark with Logging {
  /// 构造方法
  /// [identifier] - 联系人ID
  /// [alias] - 备注名
  /// [description] - 备注描述
  ContactRemark(this.identifier, {required this.alias, required this.description});

  final ID identifier;      // 联系人唯一标识
  String alias;             // 联系人备注名
  String description;       // 联系人备注描述
  
  /// 重写toString，便于日志打印和调试
  @override
  String toString(){
    String clazz = className;
    return '<$clazz id="$identifier" alias="$alias" desc="$description" />';
  }

  /// 创建空备注实例（备注名和描述为空字符串）
  /// [identifier] - 联系人ID
  /// @return 空备注实例
  static ContactRemark empty(ID identifier) =>
      ContactRemark(identifier, alias: '', description: '');
}

/// 备注数据库接口
/// 用于管理用户对联系人的备注信息
abstract class RemarkDBI {

  /// 获取指定联系人的备注信息
  /// [contact] - 联系人ID
  /// [user] - 所属用户ID（当前登录用户）
  /// @return 备注信息（null表示无备注）
  Future<ContactRemark?> getRemark(ID contact, {required ID user});

  /// 设置/更新联系人的备注信息
  /// [remark] - 备注信息
  /// [user] - 所属用户ID（当前登录用户）
  /// @return 操作成功返回true
  Future<bool> setRemark(ContactRemark remark, {required ID user});
}

/// 黑名单数据库接口
/// 用于管理用户的联系人黑名单
abstract class BlockedDBI{

  /// 获取用户的黑名单列表
  /// [user] - 所属用户ID（当前登录用户）
  /// @return 黑名单联系人ID列表
  Future<List<ID>> getBlockList({required ID user});

  /// 保存用户的黑名单列表（覆盖原有列表）
  /// [contacts] - 黑名单联系人ID列表
  /// [user] - 所属用户ID（当前登录用户）
  /// @return 操作成功返回true
  Future<bool> saveBlockList(List<ID> contacts, {required ID user});

  /// 添加联系人到黑名单
  /// [contact] - 联系人ID
  /// [user] - 所属用户ID（当前登录用户）
  /// @return 操作成功返回true
  Future<bool> addBlocked(ID contact, {required ID user});

  /// 从黑名单移除联系人
  /// [contact] - 联系人ID
  /// [user] - 所属用户ID（当前登录用户）
  /// @return 操作成功返回true
  Future<bool> removeBlocked(ID contact, {required ID user});
}

/// 静音列表数据库接口
/// 用于管理用户的联系人静音列表（免打扰）
abstract class MutedDBI {

  /// 获取用户的静音列表
  /// [user] - 所属用户ID（当前登录用户）
  /// @return 静音联系人ID列表
  Future<List<ID>> getMuteList({required ID user});

  /// 保存用户的静音列表（覆盖原有列表）
  /// [contacts] - 静音联系人ID列表
  /// [user] - 所属用户ID（当前登录用户）
  /// @return 操作成功返回true
  Future<bool> saveMuteList(List<ID> contacts, {required ID user});

  /// 添加联系人到静音列表
  /// [contact] - 联系人ID
  /// [user] - 所属用户ID（当前登录用户）
  /// @return 操作成功返回true
  Future<bool> addMuted(ID contact, {required ID user});

  /// 从静音列表移除联系人
  /// [contact] - 联系人ID
  /// [user] - 所属用户ID（当前登录用户）
  /// @return 操作成功返回true
  Future<bool> removeMuted(ID contact, {required ID user});
}