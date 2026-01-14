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

import 'package:dim_plugins/dim_plugins.dart';

/// 通用文档工厂类
/// 核心作用：
/// 1. 实现DocumentFactory接口，提供身份文档的创建/解析能力；
/// 2. 支持多类型文档（VISA/公告/个人资料）的自动识别和创建；
/// 3. 处理文档类型的自动适配（根据ID类型推导）；
class GeneralDocumentFactory implements DocumentFactory{
  /// 构造方法：指定文档类型
  /// [type] - 文档类型
  GeneralDocumentFactory(this.type);

  /// 文档类型
  final String type;

  /// 推导文档类型（根据传入类型和ID）
  /// [docType] - 传入的文档类型（可能为通配符*）
  /// [identifier] - 身份ID
  /// 返回值：实际文档类型
  // protected
  String getType(String docType, ID identifier) {
    assert(docType.isNotEmpty, 'document type empty');
    if(docType != '*'){
      // 非通配符，直接使用
      return docType;
    }else if(identifier.isGroup){
      // 群组ID → 公告文档（BULLETIN）
      return DocumentType.BULLETIN;
    }else if(identifier.isUser){
      // 用户ID → 签证文档（VISA）
      return DocumentType.VISA;
    }else{
      // 其他 → 个人资料文档（PROFILE）
      return DocumentType.PROFILE;
    }
  }

  /// 创建文档对象
  /// [identifier] - 文档所属ID
  /// [data] - 文档内容数据
  /// [signature] - 文档签名
  /// 返回值：创建的文档对象
  @override
  Document createDocument(ID identifier, {String? data, TransportableData? signature}){
    // 推导实际文档类型
    String docType = getType(type, identifier);
    if(data == null || data.isEmpty){
      // 无数据：创建空文档
      assert(signature == null, 'document error: $identifier, data: $data, signature: $signature');
      switch(docType){
        case DocumentType.VISA:
          return BaseVisa.from(identifier);
        case DocumentType.BULLETIN:
          return BaseBulletin.from(identifier);
        default:
          return BaseDocument.from(identifier, docType);
      }
    }else{
      // 有数据，创建但数据和签名的文档
      assert(signature != null, 'document error: $identifier, data: $data, signature: $signature');
      switch(docType){
        case DocumentType.VISA:
          return BaseVisa.from(identifier, data: data, signature: signature);
        case DocumentType.BULLETIN:
          return BaseBulletin.from(identifier, data: data, signature: signature);
        default:
          return BaseDocument.from(identifier, docType, data: data, signature: signature);
      }
    }
  }

  /// 解析Map为文档对象
  /// [doc] - 包含文档属性的Map
  /// 返回值：文档对象（解析失败返回null）
  @override
  Document? parseDocument(Map doc) {
    // 解析文档所属ID
    ID? identifier = ID.parse(doc['did']);
    if(identifier == null){
      // ID为空，解析失败
      assert(false, 'document ID not found: $doc');
      return null;
    }else if(doc['data'] == null || doc['signature'] == null){
      // 数据/签名为空，解析失败
      assert(false, 'document error: $doc');
      return null;
    }
    // 获取文档类型
    var ext = SharedAccountExtensions();
    // 通用账户辅助器helper
    String? docType = ext.helper!.getDocumentType(doc,null); 
    docType ??= getType('*', identifier);
    // 根据文档类型创建对应实例
    switch (docType) {
      case DocumentType.VISA:
        return BaseVisa(doc);
      case DocumentType.BULLETIN:
        return BaseBulletin(doc);
      default:
        return BaseDocument(doc);
    }
  }
}