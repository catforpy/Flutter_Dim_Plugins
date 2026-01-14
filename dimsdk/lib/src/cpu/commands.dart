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



import 'package:dimsdk/core.dart';
import 'package:dimsdk/cpu.dart';
import 'package:dimsdk/dimp.dart';
import 'package:dimsdk/mkm.dart';

/// CPU模块 - Meta命令处理器
/// 核心作用：处理MetaCommand（身份元数据命令），实现Meta的“查询-验证-存储”全流程，
/// 是DIM去中心化身份体系的核心业务处理器，严格保证Meta的合法性和安全性。
/// 核心场景：
/// 1. 查询Meta：根据ID返回本地存储的Meta，无则返回“未找到”回执；
/// 2. 提交Meta：验证Meta合法性后存储，非法则返回错误回执，合法则返回成功回执。
class MetaCommandProcessor extends BaseCommandProcessor {
  /// 构造方法：继承父类，关联实体管理和消息核心上下文
  MetaCommandProcessor(super.facebook, super.messenger);

  /// 获取数据存储接口（Archivist）
  /// 核心依赖：所有Meta的存储操作通过Archivist完成，解耦业务逻辑和数据存储层。
  // protected
  Archivist? get archivist => facebook?.archivist;

  /// 处理MetaCommand（核心入口）
  /// 核心逻辑：区分“查询Meta”和“提交Meta”两种场景，分别调用对应方法处理，
  /// 保证不同场景的逻辑分离，便于维护。
  /// @param content - 待处理的MetaCommand
  /// @param rMsg - 原始可靠消息（用于获取信封上下文）
  /// @return 处理结果（Meta响应/错误回执/成功回执）
  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async{
    // 断言校验：确保处理的是MetaCommand类型
    assert(content is MetaCommand, 'meta command error: $content');
    MetaCommand command = content as MetaCommand;
    Meta? meta = command.meta;
    ID identifier = command.identifier;

    if(meta == null){
      // 场景1： Meta为空 -> 查询指定ID的Meta
      return await _getMeta(identifier,content:command,envelope: rMsg.envelope);
    }
    // 场景2： Meta不为空 -> 接收并存储指定ID的Meta
    return await _putMeta(meta, identifier: identifier, content: command, envelope: rMsg.envelope);
  }

  /// 查询指定ID的Meta
  /// 核心逻辑：从本地获取Meta，存在则返回MetaCommand响应，不存在则返回“未找到”回执。
  /// @param identifier - 待查询的实体ID
  /// @param content - 原始MetaCommand（用于关联回执上下文）
  /// @param envelope - 原始消息信封（用于生成回执）
  /// @return 查询结果（MetaCommand响应/未找到回执）
  Future<List<Content>> _getMeta(ID identifier, {
    required MetaCommand content, required Envelope envelope
  }) async {
    // 从本地获取Meta(通过facebook实体管理)
    Meta? meta = await facebook?.getMeta(identifier);
    if (meta == null) {
      // 未找到Meta → 返回标准化错误回执
      String text = 'Meta not found.';
      return respondReceipt(text, content: content, envelope: envelope, extra: {
        'template': 'Meta not found: \${did}.',
        'replacements': {
          'did': identifier.toString(),
        },
      });
    }
    // 找到Meta → 返回包含Meta的响应
    return [
      MetaCommand.response(identifier, meta)
    ];
  }

  /// 存储指定ID的Meta
  /// 核心逻辑：先验证Meta合法性，再调用Archivist存储，根据存储结果返回对应回执。
  /// @param meta - 待存储的Meta实例
  /// @param identifier - 关联的实体ID
  /// @param content - 原始MetaCommand（用于关联回执上下文）
  /// @param envelope - 原始消息信封（用于生成回执）
  /// @return 存储结果（成功回执/错误回执）
  Future<List<Content>> _putMeta(Meta meta, {
    required ID identifier, required MetaCommand content, required Envelope envelope
  }) async {
    // 步骤1：尝试存储Meta（包含合法性校验）
    List<Content>? errors = await saveMeta(meta, identifier: identifier, content: content, envelope: envelope);
    if (errors != null) {
      // 存储失败 → 返回错误回执
      return errors;
    }
    // 步骤2：存储成功 → 返回成功回执
    String text = 'Meta received.';
    return respondReceipt(text, content: content, envelope: envelope, extra: {
      'template': 'Meta received: \${did}.',
      'replacements': {
        'did': identifier.toString(),
      },
    });
  }

  /// 验证并存储Meta（核心工具方法）
  /// 核心逻辑：先校验Meta合法性（有效且匹配ID），再调用Archivist存储，
  /// 任何步骤失败都返回对应的错误回执，成功则返回null。
  /// @param meta - 待存储的Meta实例
  /// @param identifier - 关联的实体ID
  /// @param content - 原始MetaCommand（用于关联回执上下文）
  /// @param envelope - 原始消息信封（用于生成回执）
  /// @return 错误回执列表（失败）/null（成功）
  // protected
  Future<List<Content>?> saveMeta(Meta meta, {
    required ID identifier, required MetaCommand content, required Envelope envelope
  }) async {
    // 步骤1：校验Meta合法性
    bool? ok = await checkMeta(meta, identifier: identifier);
    if (!ok) {
      // Meta非法 → 返回错误回执
      String text = 'Meta not valid.';
      return respondReceipt(text, content: content, envelope: envelope, extra: {
        'template': 'Meta not valid: \${did}.',
        'replacements': {
          'did': identifier.toString(),
        },
      });
    }
    // 步骤2：调用Archivist存储Meta
    ok = await archivist?.saveMeta(meta, identifier);
    if (ok != true) {
      // 存储失败（数据库错误等）→ 返回错误回执
      String text = 'Meta not accepted.';
      return respondReceipt(text, content: content, envelope: envelope, extra: {
        'template': 'Meta not accepted: \${did}.',
        'replacements': {
          'did': identifier.toString(),
        },
      });
    }
    // 存储成功 → 返回null（无错误）
    return null;
  }

  /// 校验Meta合法性
  /// 核心逻辑：验证Meta是否有效，且与指定ID匹配（通过MetaUtils工具类）。
  /// @param meta - 待校验的Meta实例
  /// @param identifier - 关联的实体ID
  /// @return true=合法，false=非法
  // protected
  Future<bool> checkMeta(Meta meta, {required ID identifier}) async =>
      meta.isValid && MetaUtils.matchIdentifier(identifier, meta);
}

/// CPU模块 - Document命令处理器
/// 核心作用：继承MetaCommandProcessor，处理DocumentCommand（身份文档命令），
/// 实现Document的“查询-验证-存储”全流程，存储前先确保Meta存在且有效。
/// 核心扩展：支持“最后更新时间”校验，避免返回过期文档；支持批量Document处理。
class DocumentCommandProcessor extends MetaCommandProcessor{
  /// 构造方法：继承父类，关联实体管理和消息核心上下文
  DocumentCommandProcessor(super.facebook, super.messenger);

  /// 处理DocumentCommand（核心入口）
  /// 核心逻辑：区分“查询Document”和“提交Document”两种场景，
  /// 提交前先校验Document ID与命令ID匹配，再调用对应方法处理。
  /// @param content - 待处理的DocumentCommand
  /// @param rMsg - 原始可靠消息（用于获取信封上下文）
  /// @return 处理结果（Document响应/错误回执/成功回执）
  @override
  Future<List<Content>> processContent(Content content,ReliableMessage rMsg) async {
    // 断言校验：确保处理的是DocumentCommand类型
    assert(content is DocumentCommand, 'document command error: $content');
    DocumentCommand command = content as DocumentCommand;
    ID identifier = command.identifier;
    List<Document>? documents = command.documents;

    if (documents == null) {
      // 场景1：Document为空 → 查询指定ID的Document
      return await _getDocuments(identifier, content: command, envelope: rMsg.envelope);
    }
    for(Document doc in documents){
      if(doc.identifier != identifier){
        // ID不匹配 → 返回错误回执
        return respondReceipt('Document ID not match.', content: command, envelope: rMsg.envelope, extra: {
          'template': 'Document ID not match: \${did}.',
          'replacements': {
            'did': identifier.toString(),
          },
        });
      }
    }
    // 场景2：Document不为空 → 接收并存储指定ID的Document
    return await _putDocuments(documents, identifier: identifier, content: content, envelope: rMsg.envelope);
  }

  /// 查询指定ID的Document
  /// 核心逻辑：从本地获取Document，支持“最后更新时间”校验，避免返回过期文档。
  /// @param identifier - 待查询的实体ID
  /// @param content - 原始DocumentCommand（用于关联回执上下文）
  /// @param envelope - 原始消息信封（用于生成回执）
  /// @return 查询结果（Document响应/未找到回执/未更新回执）
  Future<List<Content>> _getDocuments(ID identifier, {
    required DocumentCommand content, required Envelope envelope
  }) async {
    // 从本地获取Document列表（通过facebook实体管理）
    List<Document>? documents = await facebook?.getDocuments(identifier);
    if (documents == null || documents.isEmpty) {
      // 未找到Document → 返回错误回执
      String text = 'Document not found.';
      return respondReceipt(text, content: content, envelope: envelope, extra: {
        'template': 'Document not found: \${did}.',
        'replacements': {
          'did': identifier.toString(),
        },
      });
    }
    // 校验最后更新时间（避免返回过期文档）
    DateTime? queryTime = content.lastTime;
    if(queryTime != null){
      // 获取最新的Document
      Document? last = DocumentUtils.lastDocument(documents);
      assert(last != null, 'should not happen');
      DateTime? lastTime = last?.time;
      if (lastTime == null) {
        assert(false, 'document error: $last');
      }else if(!lastTime.isAfter(queryTime)){
        // 文档未更新 ->返回对应回执
        String text = 'Document not updated.';
        return respondReceipt(text, content: content, envelope: envelope, extra: {
          'template': 'Document not updated: \${did}, last time: \${time}.',
          'replacements': {
            'did': identifier.toString(),
            'time': lastTime.millisecondsSinceEpoch / 1000.0,
          },
        });
      }
    }
    // 找到Document → 获取关联的Meta，返回包含Document的响应
    Meta? meta = await facebook?.getMeta(identifier);
    return [
      DocumentCommand.response(identifier, meta, documents)
    ];
  }

  /// 存储指定ID的Document（批量）
  /// 核心逻辑：
  /// 1. 确保Meta存在（无则查询，有则验证）；
  /// 2. 批量验证并存储每个Document；
  /// 3. 根据存储结果返回对应回执。
  /// @param documents - 待存储的Document列表
  /// @param identifier - 关联的实体ID
  /// @param content - 原始DocumentCommand（用于关联回执上下文）
  /// @param envelope - 原始消息信封（用于生成回执）
  /// @return 存储结果（成功回执/错误回执）
  Future<List<Content>> _putDocuments(List<Document> documents, {
    required ID identifier, required DocumentCommand content, required Envelope envelope
  }) async {
    List<Content>? errors;
    Meta? meta = content.meta;

    // 步骤0：确保Meta存在且有效
    if (meta == null) {
      // 从本地获取Meta
      meta = await facebook?.getMeta(identifier);
      if (meta == null) {
        // Meta未找到 → 返回错误回执
        String text = 'Meta not found.';
        return respondReceipt(text, content: content, envelope: envelope, extra: {
          'template': 'Meta not found: \${did}.',
          'replacements': {
            'did': identifier.toString(),
          },
        });
      }
    }else{
      // Meta存在 → 验证并存储Meta
      errors = await saveMeta(meta, identifier: identifier, content: content, envelope: envelope);
      if (errors != null) {
        // Meta存储失败 → 返回错误回执
        return errors;
      }
    }
    // 步骤1：批量验证并存储Document
    errors = [];
    for (var doc in documents) {
      var array = await saveDocument(doc, meta: meta, identifier: identifier, content: content, envelope: envelope);
      if (array != null) {
        errors.addAll(array);
      }
    }
    if (errors.isNotEmpty) {
      // 部分/全部Document存储失败 → 返回错误回执
      return errors;
    }
    // 步骤2：所有Document存储成功 → 返回成功回执
    String text = 'Document received.';
    return respondReceipt(text, content: content, envelope: envelope, extra: {
      'template': 'Document received: \${did}.',
      'replacements': {
        'did': identifier.toString(),
      },
    });
  }

  /// 验证并存储单个Document
  /// 核心逻辑：先校验Document合法性（签名验证），再调用Archivist存储，
  /// 任何步骤失败都返回对应的错误回执，成功则返回null。
  /// @param doc - 待存储的Document实例
  /// @param meta - 关联的Meta（用于签名验证）
  /// @param identifier - 关联的实体ID
  /// @param content - 原始DocumentCommand（用于关联回执上下文）
  /// @param envelope - 原始消息信封（用于生成回执）
  /// @return 错误回执列表（失败）/null（成功）
  // protected
  Future<List<Content>?> saveDocument(Document doc, {
    required Meta meta, required ID identifier,
    required DocumentCommand content, required Envelope envelope
  }) async {
    // 步骤1：校验Document合法性
    bool? ok = await checkDocument(doc, meta: meta);
    if (!ok) {
      // Document非法 → 返回错误回执
      String text = 'Document not accepted.';
      return respondReceipt(text, content: content, envelope: envelope, extra: {
        'template': 'Document not accepted: \${did}.',
        'replacements': {
          'did': identifier.toString(),
        },
      });
    }
    // 步骤2：调用Archivist存储Document
    ok = await archivist?.saveDocument(doc);
    if (ok != true) {
      // 存储失败（文档过期等）→ 返回错误回执
      String text = 'Document not changed.';
      return respondReceipt(text, content: content, envelope: envelope, extra: {
        'template': 'Document not changed: \${did}.',
        'replacements': {
          'did': identifier.toString(),
        },
      });
    }
    // 存储成功 → 返回null（无错误）
    return null;
  }

  /// 校验Document合法性
  /// 核心逻辑：
  /// 1. 先检查Document自身有效性；
  /// 2. 用Meta公钥验证Document签名（用户文档用用户Meta，群组文档用群主Meta）；
  /// @param doc - 待校验的Document实例
  /// @param meta - 关联的Meta（用于签名验证）
  /// @return true=合法，false=非法
  // protected
  Future<bool> checkDocument(Document doc, {required Meta meta}) async {
    // 步骤1：检查Document自身有效性
    if (doc.isValid) {
      return true;
    }
    // 步骤2：验证Document签名
    // 注意：群组公告文档用群主Meta公钥验证，用户签证文档用用户Meta公钥验证
    return doc.verify(meta.publicKey);
    // TODO: 补充群组文档的特殊验证逻辑
  }
}