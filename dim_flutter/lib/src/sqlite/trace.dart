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
import 'package:dim_client/sdk.dart';

import '../common/dbi/message.dart';

import 'helper/sqlite.dart';
import 'message.dart';

/// 从查询结果集中提取追踪ID
/// [resultSet]: SQL查询结果集
/// [index]: 结果集索引（此处未使用）
/// 返回追踪ID字符串
String _extractTrace(ResultSet resultSet, int index) {
  return resultSet.getString('trace')!; // 获取trace字段值（强制非空）
}

/// 消息追踪记录表处理器
/// 实现TraceDBI接口，负责消息追踪记录的数据库CRUD操作
class TraceTable extends DataTableHandler<String> implements TraceDBI {
  /// 构造函数：初始化数据库连接器和数据提取方法
  TraceTable() : super(MessageDatabase(), _extractTrace);

  /// 数据表名称
  static const String _table = MessageDatabase.tTrace;
  /// 查询字段：仅查询trace字段
  static const List<String> _selectColumns = ["trace"];
  /// 插入字段：cid(会话ID)、sender(发送者ID)、sn(序列号)、signature(签名)、trace(追踪ID)
  static const List<String> _insertColumns = ["cid", "sender", "sn", "signature", "trace"];

  /// 添加消息追踪记录
  /// [trace]: 追踪ID
  /// [cid]: 会话ID
  /// [sender]: 发送者ID（必填）
  /// [sn]: 消息序列号（必填）
  /// [signature]: 消息签名（可选）
  /// 返回是否添加成功
  @override
  Future<bool> addTrace(String trace, ID cid,
      {required ID sender, required int sn, required String? signature}) async {
    // 处理签名：空值转为空字符串，超长则截取后8位
    if (signature == null) {
      signature = '';
    } else if (signature.length > 8) {
      signature = signature.substring(signature.length - 8);
    }
    // 准备插入数据
    List values = [cid.toString(), sender.toString(), sn, signature, trace];
    // 执行插入操作，返回值>0表示成功
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

  /// 获取指定条件的消息追踪记录
  /// [sender]: 发送者ID
  /// [sn]: 消息序列号
  /// [signature]: 消息签名（可选）
  /// 返回追踪ID列表
  @override
  Future<List<String>> getTraces(ID sender, int sn, String? signature) async {
    SQLConditions cond;
    if (signature != null) {
      // 处理签名：超长则截取后8位
      if (signature.length > 8) {
        signature = signature.substring(signature.length - 8);
      }
      // 条件：signature等于目标签名
      cond = SQLConditions(left: 'signature', comparison: '=', right: signature);
      if (sn > 0) {
        // 追加条件：OR sn等于目标序列号
        cond.addCondition(SQLConditions.kOr, left: 'sn', comparison: '=', right: sn);
      }
    } else if (sn > 0) {
      // 条件：sn等于目标序列号
      cond = SQLConditions(left: 'sn', comparison: '=', right: sn);
    } else {
      // 无sn和signature，记录错误并返回空列表
      Log.error('failed to get trace without sn or signature: $sender');
      return [];
    }
    // 追加条件：AND sender等于目标发送者ID
    cond.addCondition(SQLConditions.kAnd,
        left: 'sender', comparison: '=', right: sender.toString());
    // SELECT * FROM t_trace WHERE (signature='...' OR sn='123') AND sender='abc'
    // 执行查询并返回追踪ID列表
    return await select(_table, columns: _selectColumns, conditions: cond);
  }

  /// 移除指定条件的消息追踪记录
  /// [sender]: 发送者ID
  /// [sn]: 消息序列号
  /// [signature]: 消息签名（可选）
  /// 返回是否移除成功
  @override
  Future<bool> removeTraces(ID sender, int sn, String? signature) async {
    // 构建删除条件：sender等于目标发送者ID AND sn等于目标序列号
    SQLConditions cond;
    cond = SQLConditions(left: 'sender', comparison: '=', right: sender.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'sn', comparison: '=', right: sn);
    if (signature != null) {
      // 处理签名：超长则截取后8位
      if (signature.length > 8) {
        signature = signature.substring(signature.length - 8);
      }
      // 追加条件：AND signature等于目标签名
      cond.addCondition(SQLConditions.kAnd,
          left: 'signature', comparison: '=', right: signature);
    }
    // 执行删除操作，返回值>=0表示成功
    return await delete(_table, conditions: cond) >= 0;
  }

  /// 移除指定会话的所有消息追踪记录
  /// [cid]: 会话ID
  /// 返回是否移除成功
  @override
  Future<bool> removeAllTraces(ID cid) async {
    // 构建删除条件：cid等于目标会话ID
    SQLConditions cond;
    cond = SQLConditions(left: 'cid', comparison: '=', right: cid.toString());
    // 执行删除操作，返回值>=0表示成功
    return await delete(_table, conditions: cond) >= 0;
  }

}