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

/// 群组任免-新增管理员/助理命令类
/// 作用：封装新增群管理员、群助理（机器人）的命令，支持批量操作
class HireGroupCommand extends BaseGroupCommand implements HireCommand{
  /// 构造方法1：从字典初始化（解析网络传输的任免命令）
  HireGroupCommand([super.dict]);

  /// 构造方法2：从群组ID+管理员/助理列表初始化（创建任免命令）
  /// @param group            - 群组ID
  /// @param administrators   - 新增的管理员列表（可选）
  /// @param assistants       - 新增的助理/机器人列表（可选）
  HireGroupCommand.from(ID group,{List<ID>? administrators, List<ID>? assistants})
    :super.from(GroupCommand.HIRE, group){
      if(administrators != null){
        this['administrators'] = ID.revert(administrators);
      }
      if(assistants != null){
        this['assistants'] = ID.revert(assistants);
      }
    }

  /// 获取新增的管理员列表（null表示未设置）
  @override
  List<ID>? get administrators{
    var array = this['administrators'];
    if(array is List){
      // 将列表转换为ID对象，保证类型安全
      return ID.convert(array);
    }
    assert(array == null, '管理员ID列表解析异常: $array');
    return null;
  }

  /// 设置新增的管理员列表（同步更新字典字段）
  @override
  set administrators(List<ID>? members){
    if(members == null){
      remove('administrators');
    }else{
      this['administrators'] = ID.revert(members);
    }
  }

  /// 获取新增的助理/机器人列表（null表示未设置）
  @override
  List<ID>? get assistants{
    var array = this['assistants'];
    if(array is List){
      // 将列表项转换为ID对象，保证类型安全
      return ID.convert(array);
    }
    assert(array == null, '助理ID列表解析异常: $array');
    return null;
  }

  /// 设置新增的助理/机器人列表（同步更新字典字段）
  @override
  set assistants(List<ID>? bots){
    if(bots == null){
      remove('assistants');
    }else{
      this['assistants'] = ID.revert(bots);
    }
  }
}

/// 群组任免-移除管理员/助理命令类
/// 作用：封装移除群管理员、群助理（机器人）的命令，支持批量操作
class FireGroupCommand extends BaseGroupCommand implements FireCommand{
  /// 构造方法1：从字典初始化（解析网络传输的免职命令）
  FireGroupCommand([super.dict]);

  /// 构造方法2：从群组ID+管理员/助理列表初始化（创建免职命令）
  /// @param group - 群组ID
  /// @param administrators - 移除的管理员列表（可选）
  /// @param assistants - 移除的助理/机器人列表（可选）
  FireGroupCommand.from(ID group, {List<ID>? administrators, List<ID>? assistants})
      : super.from(GroupCommand.FIRE, group) {
    if (administrators != null) {
      this['administrators'] = ID.revert(administrators);
    }
    if (assistants != null) {
      this['assistants'] = ID.revert(assistants);
    }
  }

  /// 获取移除的管理员列表（null表示未设置）
  @override
  List<ID>? get administrators {
    var array = this['administrators'];
    if (array is List) {
      // 将列表项转为ID对象，保证类型安全
      return ID.convert(array);
    }
    assert(array == null, '管理员ID列表解析异常: $array');
    return null;
  }

  /// 设置移除的管理员列表（同步更新字典字段）
  @override
  set administrators(List<ID>? members) {
    if (members == null) {
      remove('administrators');
    } else {
      this['administrators'] = ID.revert(members);
    }
  }

  /// 获取移除的助理/机器人列表（null表示未设置）
  @override
  List<ID>? get assistants {
    var array = this['assistants'];
    if (array is List) {
      // 将列表项转为ID对象，保证类型安全
      return ID.convert(array);
    }
    assert(array == null, '助理ID列表解析异常: $array');
    return null;
  }

  /// 设置移除的助理/机器人列表（同步更新字典字段）
  @override
  set assistants(List<ID>? bots) {
    if (bots == null) {
      remove('assistants');
    } else {
      this['assistants'] = ID.revert(bots);
    }
  }
}

/// 群组管理员主动辞职命令类
/// 作用：封装管理员主动放弃群管理权限的命令，适配去中心化自主管理场景
class ResignGroupCommand extends BaseGroupCommand implements ResignCommand {
  /// 构造方法1：从字典初始化（解析网络传输的辞职命令）
  ResignGroupCommand([super.dict]);

  /// 构造方法2：从群组ID初始化（创建辞职命令）
  /// @param group - 群组ID
  ResignGroupCommand.from(ID group) : super.from(GroupCommand.RESIGN, group);
}