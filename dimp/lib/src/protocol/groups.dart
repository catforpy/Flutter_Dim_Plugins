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

import 'package:dimp/dkd.dart';
import 'package:dimp/mkm.dart';

/// 历史命令基础接口
/// 作用：定义带时间戳的命令结构，是群组命令/账号命令的父接口
/// 数据格式：{
///      type : i2s(0x89),  // 消息类型标识（0x89=历史命令）
///      sn   : 123,        // 消息序列号
///
///      command : "...", // 命令名
///      time    : 0,     // 命令时间戳
///      extra   : info   // 命令参数
///  }
abstract interface class HistoryCommand implements Command{
  //-------- 账号相关命令名常量 --------
  /// 注册账号命令
  static const String REGISTER = "register";
  /// 注销账号命令
  static const String SUICIDE  = "suicide";
}

// 忽略“常量标识符应使用大写”的lint警告
// ignore_for_file: constant_identifier_names


/// 群组命令接口（继承HistoryCommand）
/// 作用：定义群组管理的核心命令结构，支持邀请/退出/重置成员/管理管理员等操作
/// 数据格式：{
///      type : i2s(0x89),  // 消息类型标识（0x89=历史命令）
///      sn   : 123,        // 消息序列号
///
///      command : "reset",   // 命令名（invite/quit/reset等）
///      time    : 123.456,   // 命令时间戳
///
///      group   : "{GROUP_ID}", // 群组ID
///      member  : "{MEMBER_ID}", // 单个成员ID
///      members : ["{MEMBER_ID}",] // 多个成员ID列表
///  }
abstract interface class GroupCommand implements HistoryCommand {
  //-------- 群组命令名常量 --------
  // 创始人/群主操作
  static const String FOUND    = "found";     // 创建群组（创始人专属：初始化群组基本信息）
  static const String ABDICATE = "abdicate";  // 退位让贤（群主专属：将群主身份转让给其他成员）
  // 成员操作
  static const String INVITE   = "invite";    // 邀请成员（群主/管理员专属：添加新成员到群组）
  static const String EXPEL    = "expel";     // 踢出成员（已废弃，用reset替代：原用于移除单个/多个成员）
  static const String JOIN     = "join";      // 加入群组（普通用户：主动申请加入群组，需群主/管理员审批）
  static const String QUIT     = "quit";      // 退出群组（普通成员：主动离开群组，无需审批）
  static const String RESET    = "reset";     // 重置成员列表（群主专属：覆盖式更新群成员列表，替代expel）
  // 管理员/助理操作
  static const String HIRE     = "hire";      // 任命管理员/助理（群主专属：添加新的管理员/机器人助理）
  static const String FIRE     = "fire";      // 解除管理员/助理（群主专属：移除已任命的管理员/机器人助理）
  static const String RESIGN   = "resign";    // 辞去管理员/助理（管理员/助理自身：主动放弃管理权限）

  /// 获取/设置单个成员ID
  /// 适用场景：仅操作单个成员时（如邀请1人、踢出1人）
  ID? get member;
  set member(ID? user);

  /// 获取/设置多个成员ID列表
  /// 适用场景：批量操作成员时（如批量邀请、批量重置成员列表）
  List<ID>? get members;
  set members(List<ID>? users);

  //-------- 工厂方法（创建各类群组命令）--------
  /// 创建通用群组命令
  /// [cmd] 命令名（如invite/reset）
  /// [group] 目标群组ID
  /// [member] 单个操作成员ID
  /// [members] 批量操作成员ID列表
  static GroupCommand create(String cmd, ID group, {ID? member, List<ID>? members}) =>
      BaseGroupCommand.from(cmd, group, member: member, members: members);

  /// 创建邀请成员命令
  /// 权限：群主/管理员
  /// [group] 目标群组ID
  /// [member] 单个邀请成员ID
  /// [members] 批量邀请成员ID列表
  static InviteCommand invite(ID group, {ID? member, List<ID>? members}) =>
      InviteGroupCommand.from(group, member: member, members: members);
  
  /// 创建踢出成员命令（已废弃，用reset替代）
  /// 原权限：群主/管理员
  /// [group] 目标群组ID
  /// [member] 单个踢出成员ID
  /// [members] 批量踢出成员ID列表
  static ExpelCommand expel(ID group, {ID? member, List<ID>? members}) =>
      ExpelGroupCommand.from(group, member: member, members: members);

  /// 创建加入群组命令
  /// 权限：普通用户（需群主/管理员审批）
  /// [group] 目标群组ID
  static JoinCommand join(ID group) => JoinGroupCommand.from(group);
  
  /// 创建退出群组命令
  /// 权限：当前群成员（自身）
  /// [group] 目标群组ID
  static QuitCommand quit(ID group) => QuitGroupCommand.from(group);

  /// 创建重置成员列表命令
  /// 权限：群主（核心操作，覆盖式更新）
  /// [group] 目标群组ID
  /// [members] 新的群成员列表（必须传，覆盖原有列表）
  static ResetCommand reset(ID group, {required List<ID> members}) =>
      ResetGroupCommand.from(group, members: members);

  /// 创建任命管理员/助理命令
  /// 权限：群主
  /// [group] 目标群组ID
  /// [administrators] 批量任命的管理员列表
  /// [assistants] 批量任命的机器人助理列表
  static HireCommand hire(ID group, {List<ID>? administrators, List<ID>? assistants}) =>
      HireGroupCommand.from(group, administrators: administrators, assistants: assistants);
  
  /// 创建解除管理员/助理命令
  /// 权限：群主
  /// [group] 目标群组ID
  /// [administrators] 批量解除的管理员列表
  /// [assistants] 批量解除的机器人助理列表
  static FireCommand fire(ID group, {List<ID>? administrators, List<ID>? assistants}) =>
      FireGroupCommand.from(group, administrators: administrators, assistants: assistants);
  
  /// 创建辞去管理员/助理命令
  /// 权限：管理员/助理自身
  /// [group] 目标群组ID
  static ResignCommand resign(ID group) => ResignGroupCommand.from(group);
}

//-------- 具体群组命令接口（空接口，用于类型标识）--------
/// 邀请成员命令接口
/// 作用：类型标识，区分邀请操作与其他群组操作
abstract interface class InviteCommand implements GroupCommand {}

/// 踢出成员命令接口（已废弃）
/// 作用：类型标识，原用于区分踢出操作，现被ResetCommand替代
abstract interface class ExpelCommand implements GroupCommand {} 

/// 加入群组命令接口
/// 作用：类型标识，区分主动加入操作
abstract interface class JoinCommand implements GroupCommand {}

/// 退出群组命令接口
/// 作用：类型标识，区分主动退出操作
abstract interface class QuitCommand implements GroupCommand {}

/// 重置成员列表命令接口
/// 作用：类型标识，区分群主覆盖式更新成员列表的操作（替代ExpelCommand）
abstract interface class ResetCommand implements GroupCommand {}

//-------- 管理员/助理相关命令接口 --------
/// 任命管理员/助理命令接口
/// 权限：群主专属
abstract interface class HireCommand implements GroupCommand {
  /// 获取/设置管理员列表
  /// 适用场景：批量任命管理员
  List<ID>? get administrators;
  set administrators(List<ID>? members);

  /// 获取/设置助理（机器人）列表
  /// 适用场景：批量添加机器人助理（如群聊机器人、消息助手）
  List<ID>? get assistants;
  set assistants(List<ID>? bots);
}

/// 解除管理员/助理命令接口
/// 权限：群主专属
/// 作用：移除已任命的管理员/机器人助理
abstract interface class FireCommand implements GroupCommand {
  /// 获取/设置要解除的管理员列表
  List<ID>? get administrators;
  set administrators(List<ID>? members);

  /// 获取/设置要解除的助理列表
  List<ID>? get assistants;
  set assistants(List<ID>? bots);
}

/// 辞去管理员/助理命令接口
/// 权限：管理员/助理自身（核心区别于FireCommand）
/// 作用：管理员/助理主动放弃管理权限，无需群主审批
abstract interface class ResignCommand implements GroupCommand {}