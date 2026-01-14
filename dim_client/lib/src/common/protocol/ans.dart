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

/// ANS（别名系统）命令接口
/// 用于查询/响应别名与ID的映射关系
/// 数据结构规范：
/// {
///     type : 0x88,        // 命令类型
///     sn   : 123,         // 序列号
///     command : "ans",    // 命令名称
///     names   : "...",    // 查询的别名（多个别名用空格分隔）
///     records : {         // 响应的记录（别名->ID映射）
///         "{alias}": "{ID}",
///     }
/// }
abstract interface class AnsCommand implements Command {
  
  static const String ANS = 'ans';  // 命令名称常量

  /// 获取查询/响应的别名列表
  /// 内部会将names字符串按空格分割为列表
  List<String> get names;

  /// 获取/设置别名-ID映射记录
  /// 仅在响应消息中存在，查询消息中为null
  Map<String,String>? get records;
  set records(Map? info);

  //
  //  工厂方法
  //

  /// 创建ANS查询命令
  /// [names] 要查询的别名（多个用空格分隔）
  /// 返回：ANS查询命令实例
  static AnsCommand query(String names) => BaseAnsCommand.from(names,null);

  /// 创建ANS响应命令
  /// [names] 对应的查询别名
  /// [records] 别名-ID映射记录
  /// 返回：ANS响应命令实例
  static AnsCommand response(String names, Map<String,String> records) =>
      BaseAnsCommand.from(names, records);
}

/// ANS命令实现类
/// 继承BaseCommand，实现AnsCommand接口的具体逻辑
class BaseAnsCommand extends BaseCommand implements AnsCommand{
  /// 从字典初始化ANS命令
  /// [dict] 包含ANS命令字段的字典
  BaseAnsCommand(super.dict);

  /// 构造方法：创建ANS命令
  /// [names] 别名字符串（多个用空格分隔）
  /// [records] 别名-ID映射记录（响应时传入，查询时为null）
  BaseAnsCommand.from(String names, Map<String, String>? records) :
        super.fromName(AnsCommand.ANS){
    assert(names.isNotEmpty,'query names should not empty');
    this['names'] = names;    // 设置别名字段
    if(records != null){
      this['records'] = records;  //设置映射记录字段
    }
  }

  /// 实现names获取逻辑：将字符串按空格分割为列表
  @override
  List<String> get names{
    String? string = getString('names');
    return string == null ? [] : string.split(' ');
  }
  /// 实现records获取逻辑：直接从字典中获取
  @override
  Map<String, String>? get records => this['records'];
  
  @override
  set records(Map? info) => this['records'] = info;
}