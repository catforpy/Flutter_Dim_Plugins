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

import 'package:dim_client/plugins.dart';

/// 黑名单命令类
/// 区块协议：忽略包含在list中的用户/群组的所有消息
/// 数据结构规范：
/// {
///     type : 0x88,        // 命令类型
///     sn   : 123,         // 序列号
///     command : "block",  // 命令名称
///     list    : []        // 黑名单列表（ID数组）
/// }
/// 特殊说明：如果list为null，表示从服务器查询黑名单
class BlockCommand extends BaseCommand {
  /// 从字典初始化黑名单命令
  /// [dict] 包含黑名单命令字段的字典
  BlockCommand(super.dict);

  static const String BLOCK = 'block';    // 命令名称常量

  /// 构造方法：从黑名单列表创建命令
  /// [contacts] 要加入黑名单的ID列表（用户/群组）
  BlockCommand.fromList(List<ID> contacts) : super.fromName(BLOCK){
    list = contacts;
  }

  /// 获取黑名单列表
  /// 内部会将字典中的list字段转换为ID类型列表
  List<ID> get list{
    List<ID>? array = this['list'];
    if(array == null){
      return [];
    }
    return ID.convert(array);   // 转换为ID类型列表
  }

  /// 设置黑名单列表
  /// [contacts] 要设置的ID列表
  set list(List<ID> contacts){
    this['list'] = ID.revert(contacts);   // 转换为字符串列表并存入字典
  }
}