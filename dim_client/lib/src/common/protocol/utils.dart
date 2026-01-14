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

/// 广播群组工具类
/// 用于处理广播群组（如everyone@everywhere）的创始人、群主、成员等信息
abstract interface class BroadcastUtils {

  /// 获取广播群组的种子名称（内部方法）
  /// [group] 群组ID
  /// 返回：群组名称（非everyone则返回名称，否则返回null）
  static String? getGroupSeed(ID group){
    String? name = group.name;
    if(name != null){
      int len = name.length;
      // 过滤空名称或“everyone”（8个字符）
      if(len == 0 || (len == 8 && name.toLowerCase() == 'everyone')){
        name = null;
      }
    }
    return name;
  }

  /// 获取广播群组的创始人ID（保护方法）
  /// [group] 广播群组ID
  /// 返回：创始人ID
  static ID getBroadcastFounder(ID group){
    String? name = getGroupSeed(group);
    if(name == null){
      // 共识： everyone@everywhere群组的创始人是Alibert Moky
      return ID.FOUNDER;
    }else{
      // 讨论：xxx@everywhere群组的创始人应该是谁？
      //       anyone@anywhere 或 xxx.founder@anywhere
      return ID.parse('$name.founder@anywhere')!;
    }
  }

  /// 获取广播群组的群主ID（保护方法）
  /// [group] 广播群组ID
  /// 返回：群主ID
  static ID getBroadcastOwner(ID group){
    String? name = getGroupSeed(group);
    if(name == null){
      // 共识：everyone@everywhere群组的群主是anyone@anywhere
      return ID.ANYONE;
    }else{
      // 讨论：xxx@everywhere群组的群主应该是谁？
      //       anyone@anywhere 或 xxx.owner@anywhere
      return ID.parse('$name.owner@anywhere')!;
    }
  }

  /// 获取广播群组的成员列表（保护方法）
  /// [group] 广播群组ID
  /// 返回：成员ID列表
  static List<ID> getBroadcastMembers(ID group) {
    String? name = getGroupSeed(group);
    if (name == null) {
      // 共识：everyone@everywhere群组的成员是anyone@anywhere
      return [ID.ANYONE];
    } else {
      // 讨论：xxx@everywhere群组的成员应该是谁？
      //       anyone@anywhere 或 xxx.member@anywhere
      ID owner = ID.parse('$name.owner@anywhere')!;
      ID member = ID.parse('$name.member@anywhere')!;
      return [owner, member];
    }
  }
}