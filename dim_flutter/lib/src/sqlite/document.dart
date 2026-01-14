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
import 'package:dim_client/common.dart';

import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';

import 'entity.dart';


/// 获取文档类型
/// [document] 文档对象
/// 返回文档类型字符串
String getDocumentType(Document document) {
  // return DocumentUtils.getDocumentType(document) ?? '';
  var type = document.getString('type');
  if (type != null && type.isNotEmpty) {
    return Converter.getString(type) ?? '';
  }
  // 根据ID类型推断文档类型
  var did = document.identifier;
  if (did.isUser) {
    return DocumentType.VISA;        // 用户ID -> 签证文档
  } else if (did.isGroup) {
    return DocumentType.BULLETIN;    // 群组ID -> 公告文档
  } else {
    return DocumentType.PROFILE;     // 其他 -> 资料文档
  }
}


/// 从数据库结果集中提取文档对象
/// [resultSet] 数据库查询结果集
/// [index] 行索引
/// 返回文档对象
Document _extractDocument(ResultSet resultSet, int index) {
  String? did = resultSet.getString('did');          // 文档ID
  String? type = resultSet.getString('type');        // 文档类型
  String? data = resultSet.getString('data');        // 文档内容
  String? signature = resultSet.getString('signature'); // 签名
  ID? identifier = ID.parse(did);
  
  // 断言验证数据有效性
  assert(identifier != null, 'did error: $did');
  assert(data != null && signature != null, 'document error: $data, $signature');
  
  // 处理空类型
  if (type == null || type.isEmpty) {
    type = '*';
  }
  
  // 解析签名
  TransportableData? ted = TransportableData.parse(signature);
  // 创建文档对象
  Document doc = Document.create(type, identifier!, data: data, signature: ted);
  
  // 补全类型信息
  if (type == '*') {
    if (identifier.isUser) {
      type = DocumentType.VISA;
    } else {
      type = DocumentType.BULLETIN;
    }
  }
  doc['type'] = type;
  return doc;
}

/// 文档数据表处理器：封装文档表的增删改查操作
class _DocumentTable extends DataTableHandler<Document> {
  /// 构造方法：初始化数据库连接器和结果集提取器
  _DocumentTable() : super(EntityDatabase(), _extractDocument);

  /// 文档表名
  static const String _table = EntityDatabase.tDocument;
  /// 查询列名列表
  static const List<String> _selectColumns = ["did", "type", "data", "signature"];
  /// 插入列名列表
  static const List<String> _insertColumns = ["did", "type", "data", "signature"];

  // 加载指定实体的所有文档
  // [entity] 实体ID（用户/群组）
  // 返回文档列表
  Future<List<Document>> loadDocuments(ID entity) async {
    // 构建查询条件：实体ID匹配
    SQLConditions cond;
    cond = SQLConditions(left: 'did', comparison: '=', right: entity.toString());
    // 执行查询操作
    return await select(_table, columns: _selectColumns, conditions: cond);
  }

  // 更新文档记录
  // [doc] 新的文档对象
  // 返回操作是否成功
  Future<bool> updateDocument(Document doc) async {
    ID identifier = doc.identifier;
    String type = getDocumentType(doc);          // 获取文档类型
    String? data = doc.getString('data');        // 文档内容
    String? signature = doc.getString('signature'); // 签名
    
    // 构建更新条件：实体ID + 文档类型
    SQLConditions cond;
    cond = SQLConditions(left: 'did', comparison: '=', right: identifier.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'type', comparison: '=', right: type);
    
    // 构建更新值映射
    Map<String, dynamic> values = {
      'data': data,
      'signature': signature,
    };
    // 执行更新操作
    return await update(_table, values: values, conditions: cond) > 0;
  }

  // 插入新文档记录
  // [doc] 文档对象
  // 返回操作是否成功
  Future<bool> insertDocument(Document doc) async {
    ID identifier = doc.identifier;
    String type = getDocumentType(doc);          // 获取文档类型
    String? data = doc.getString('data');        // 文档内容
    String? signature = doc.getString('signature'); // 签名
    
    // 构建插入值列表
    List values = [
      identifier.toString(),
      type,
      data,
      signature,
    ];
    // 执行插入操作
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }

}

/// 文档数据访问任务：封装带缓存的文档读写操作
class _DocTask extends DbTask<ID, List<Document>> {
  /// 构造方法
  /// [mutexLock] 互斥锁
  /// [cachePool] 缓存池
  /// [_table] 文档表处理器
  /// [_entity] 实体ID
  /// [newDocument] 新文档（可选）
  _DocTask(super.mutexLock, super.cachePool, this._table, this._entity, {
    required Document? newDocument,
  }) : _newDocument = newDocument;

  /// 实体ID（缓存键）
  final ID _entity;

  /// 新文档（用于更新）
  final Document? _newDocument;

  /// 文档表处理器
  final _DocumentTable _table;

  /// 缓存键（实体ID）
  @override
  ID get cacheKey => _entity;

  /// 从数据库读取指定实体的所有文档
  @override
  Future<List<Document>?> readData() async {
    return await _table.loadDocuments(_entity);
  }

  /// 写入文档到数据库
  @override
  Future<bool> writeData(List<Document> documents) async {
    Document? doc = _newDocument;
    if (doc == null) {
      assert(false, 'should not happen: $_entity');
      return false;
    }
    ID identifier = doc.identifier;
    String type = getDocumentType(doc);
    bool update = false;
    Document item;
    
    // 检查旧文档列表
    for (int index = documents.length - 1; index >= 0; --index) {
      item = documents[index];
      if (item.identifier != identifier) {
        assert(false, 'document error: $identifier, $item');
        continue;
      } else if (getDocumentType(item) != type) {
        logInfo('skip document: $identifier, type=$type, $item');
        continue;
      } else if (item == doc) {
        logWarning('same document, no need to update: $identifier');
        return true;
      }
      // 找到匹配的旧文档，标记为更新
      documents[index] = doc;
      update = true;
    }
    
    if (update) {
      // 更新旧记录
      return await _table.updateDocument(doc);
    }
    // 插入新记录
    var ok = await _table.insertDocument(doc);
    if (ok) {
      documents.add(doc);
    }
    return ok;
  }

}

/// 文档缓存管理器：实现DocumentDBI接口，提供文档的缓存操作
class DocumentCache extends DataCache<ID, List<Document>> implements DocumentDBI {
  /// 构造方法：初始化缓存池（名称为'documents'）
  DocumentCache() : super('documents');

  /// 文档表处理器实例
  final _DocumentTable _table = _DocumentTable();

  /// 创建新的文档数据访问任务
  /// [entity] 实体ID
  /// [newDocument] 新文档（可选）
  /// 返回文档任务实例
  _DocTask _newTask(ID entity, {Document? newDocument}) =>
      _DocTask(mutexLock, cachePool, _table, entity, newDocument: newDocument);

  /// 获取指定实体的所有文档
  /// [entity] 实体ID
  /// 返回文档列表（空列表表示无文档）
  @override
  Future<List<Document>> getDocuments(ID entity) async {
    var task = _newTask(entity);
    var documents = await task.load();
    return documents ?? [];
  }

  /// 保存文档（带缓存和通知）
  /// [doc] 文档对象
  /// 返回操作是否成功
  @override
  Future<bool> saveDocument(Document doc) async {
    //
    //  0. 验证文档有效性
    //
    ID identifier = doc.identifier;
    if (!doc.isValid) {
      logError('document not valid: $identifier');
      return false;
    }
    //
    //  1. 加载旧文档记录
    //
    var task = _newTask(identifier);
    var documents = await task.load();
    if (documents == null) {
      documents = [];
    } else {
      // 检查时间：新文档时间不能早于旧文档
      DateTime? newTime = doc.time;
      if (newTime != null) {
        DateTime? oldTime;
        for (Document item in documents) {
          oldTime = item.time;
          if (oldTime != null && oldTime.isAfter(newTime)) {
            logWarning('ignore expired document: $doc');
            return false;
          }
        }
      }
    }
    //
    //  2. 保存新文档
    //
    task = _newTask(identifier, newDocument: doc);
    bool ok = await task.save(documents);
    if (!ok) {
      logError('failed to save document: $identifier');
      return false;
    }
    //
    //  3. 发送文档更新通知
    //
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kDocumentUpdated, this, {
      'ID': identifier,
      'document': doc,
    });
    return true;
  }

}