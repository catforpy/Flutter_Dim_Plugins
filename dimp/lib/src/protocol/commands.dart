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

//--------  核心命令接口定义 --------

import 'package:dimp/dkd.dart';
import 'package:dimp/mkm.dart';

/// Meta命令接口（查询/响应实体Meta）
/// 作用：实现节点间的Meta同步（Meta是实体的身份核心数据）
/// 数据格式：{
///      type : i2s(0x88),   // 命令消息类型
///      sn   : 123,         // 序列号
///
///      command : "meta", // 命令名=meta
///      did     : "{ID}", // 实体ID
///      meta    : {...}   // Meta数据（null=查询，非null=响应）
///  }
abstract interface class MetaCommand implements Command{
  /// 获取实体ID（要查询/相应的目标ID）
  ID get identifier;
  
  /// 获取实体Meta（null = 查询，非Null = 相应）
  Meta? get meta;
  //-------- 工厂方法 --------

  /// 创建Meta响应命令（返回目标ID的Meta）
  /// @param identifier - 实体ID
  /// @param meta       - 实体Meta
  /// @return Meta命令实例
  static MetaCommand response(ID identifier,Meta meta) =>
   BaseMetaCommand.from(identifier, Command.META, meta);

  /// 创建Meta查询命令（请求目标ID的Meta）
  /// @param identifier - 实体ID
  /// @return Meta命令实例
  static MetaCommand query(ID identifier) => 
   BaseMetaCommand.from(identifier, Command.META, null);
}

/// Document命令接口（查询/响应实体资料）
/// 作用：实现节点间的实体资料同步（Document包含头像、昵称等信息）
/// 数据格式：{
///      type : i2s(0x88),   // 命令消息类型
///      sn   : 123,         // 序列号
///
///      command   : "documents", // 命令名=documents
///      did       : "{ID}",      // 实体ID
///      meta      : {...},       // 可选，新好友握手时附带Meta
///      documents : [...],       // 资料列表（null=查询，非null=响应）
///      last_time : 12345        // 可选，查询更新时间晚于该值的资料
///  }
abstract interface class DocumentCommand implements MetaCommand{
  /// 获取实体资料列表
  List<Document>? get documents;

  /// 获取查询的”最后更新时间“（仅查询时有效）
  DateTime? get lastTime;

  //-------- 工厂方法 --------

  /// 创建Document响应命令（返回目标ID的资料）
  /// 场景1：向新好友发送自己的Meta+资料；场景2：响应他人的资料查询
  /// @param identifier - 实体ID
  /// @param meta       - 实体Meta（可选）
  /// @param docs       - 实体资料列表（必填）
  /// @return Document命令实例
  static DocumentCommand response(ID identifier,Meta? meta,List<Document> docs) =>
    BaseDocumentCommand.from(identifier, meta, docs);

  /// 创建Document查询命令（请求目标ID的资料）
  /// 场景1：查询目标ID的全部资料；场景2：查询更新时间晚于lastTime的资料
  /// @param identifier   - 实体ID
  /// @param lastTime     - 最后更新时间（可选，null= 查询全部）
  /// @return Document命令实例
  static DocumentCommand query(ID identifier,[DateTime? lastTime]) =>
    BaseDocumentCommand.query(identifier, lastTime);
}