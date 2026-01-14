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

///
/// Meta命令消息类（继承命令基类）
/// 设计目的：封装去中心化IM中「身份Meta查询/更新」的命令消息，
///           Meta是用户/群组的核心身份数据（包含公钥等关键信息）
///
class BaseMetaCommand extends BaseCommand implements MetaCommand {
  /// 构造方法1：从字典初始化（解析网络传输的Meta命令）
  BaseMetaCommand([super.dict]);

  /// 缓存：用户/群组ID（避免重复解析）
  ID? _id;

  /// 缓存:Meta数据（避免重复解析）
  Meta? _meta;

  /// 构造方法2：从ID+命令名称+Meta初始化（创建Meta命令）
  /// @param identifier - 用户/群组ID
  /// @param cmd - 命令名称（默认Command.META）
  /// @param meta - Meta数据（查询时为null，更新时为具体值）
  BaseMetaCommand.from(ID identifier, String? cmd, Meta? meta)
    : super.fromName(cmd ?? Command.META) {
    // 填充ID
    this['did'] = identifier.toString();
    _id = identifier;
    // 填充Meta(可选)
    if (meta != null) {
      this['meta'] = meta.toMap();
    }
    _meta = meta;
  }

  /// 获取用户/群组ID（解析失败时触发断言）
  @override
  ID get identifier {
    _id ??= ID.parse(this['did']);
    return _id!;
  }

  /// 获取Meta数据（null表示仅查询，无更新数据）
  @override
  Meta? get meta {
    _meta ??= Meta.parse(this['meta']);
    return _meta;
  }
}

///
/// 文档命令消息类（继承Meta命令类）
/// 设计目的：封装去中心化IM中「用户/群组文档查询/更新」的命令消息，
///           文档包含用户昵称、头像、群公告等非核心身份数据
///
class BaseDocumentCommand extends BaseMetaCommand implements DocumentCommand {
  /// 构造方法1：从字典初始化（解析网络传输的文档命令）
  BaseDocumentCommand([super.dict]);

  /// 缓存：文档列表（避免重复解析）
  List<Document>? _docs;

  /// 构造方法2：从ID+Meta+文档列表初始化（更新文档）
  /// @param identifier - 用户/群组ID
  /// @param meta - Meta数据（可选，更新时可附带）
  /// @param docs - 文档列表（如用户资料、群公告）
  BaseDocumentCommand.from(ID identifier, Meta? meta, List<Document>? docs)
    : super.from(identifier, Command.DOCUMENTS, meta) {
    // 填充文档列表
    if (docs != null) {
      this['documents'] = Document.revert(docs);
    }
    _docs = docs;
  }

  /// 构造方法3：从ID+最后更新时间初始化（查阅文档）
  /// @param identifier - 用户/群组ID
  /// @param lastTime -最后更新时间（仅查询该时间之后的文档）
  BaseDocumentCommand.query(ID identifier, DateTime? lastTime)
    : super.from(identifier, Command.DOCUMENTS, null) {
    // 填充最后更新时间（增量查询）
    if (lastTime != null) {
      setDateTime('last_time', lastTime);
    }
  }

  /// 获取文档列表（null表示无文档/仅查询）
  @override
  List<Document>? get documents {
    if (_docs == null) {
      var docs = this['documents'];
      if (docs is List) {
        _docs = Document.convert(docs);
      }
    }
    return _docs;
  }

  /// 获取最后更新时间（增量查询时使用,null表示查询全部）
  @override
  DateTime? get lastTime => getDateTime('last_time');
}
