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

/* 
 * 核心功能：定义实体（用户/群组）的文档接口（TAI），存储可变信息（如昵称、公钥、头像）
 * 设计背景：TAI（The Additional Information）补充信息，与Meta（固定信息）对应
 * 核心特性：支持签名/验签，保证信息的真实性和完整性
 */

import 'dart:typed_data';

import 'package:mkm/mkm.dart';
import 'package:mkm/type.dart';

/// 【基础接口】补充信息（TAI）
/// 存储实体的可变信息，支持签名/验签，保证信息未被篡改
abstract interface class TAI {
  /// 检查文档是否有效（签名是否匹配）
  bool get isValid;

  /// 用Meta中的公钥验证文档的签名
  /// [metaKey]：Meta中的公钥（验证签名的核心）
  /// 返回：true=签名有效，false=签名无效
  bool verify(VerifyKey metaKey);

  /// 用私钥对文档数据签名（生成signature字段）
  /// [sKey]：匹配Meta公钥的私钥
  /// 返回：签名数据（二进制），失败返回null
  Uint8List? sign(SignKey sKey);

  //-------- 文档属性操作 --------
  /// 获取文档的所有属性（如name/avatar/email等）
  /// 返回：属性Map，无效时返回null
  Map? get properties;

  /// 获取指定名称的属性值
  dynamic getProperty(String name);

  /// 设置属性值（会重置data和signature，需要重新签名）
  void setProperty(String name, Object? value);
}

/// 【核心接口】实体文档（用户/群组档案）
/// 继承TAI（签名验签）+ Mapper（Map互转），是TAI的具体实现，分不同类型：
/// - visa：用户签证（存储用户公钥、昵称等）
/// - bulletin：群组公告（存储群组创始人、成员等）
abstract interface class Document implements TAI, Mapper {
  /// 获取文档所属的实体ID（用户/群组ID）
  ID get identifier;

  /// 获取文档的签名时间（创建/更新时间）
  DateTime? get time;

  /// 获取实体名称（用户昵称/群组名）
  String? get name;
  set name(String? value);

  // -------------------------- 便捷方法 --------------------------
  /// 将Iterable（如List）转换为Document列表
  static List<Document> convert(Iterable array) {
    List<Document> documents = [];
    Document? doc;
    for (var item in array) {
      doc = parse(item);
      if (doc == null) continue;
      documents.add(doc);
    }
    return documents;
  }

  /// 将Document列表转换为Map列表（序列化）
  static List<Map> revert(Iterable<Document> documents) {
    List<Map> array = [];
    for (Document doc in documents) {
      array.add(doc.toMap());
    }
    return array;
  }

  // -------------------------- 工厂方法 --------------------------
  /// 创建文档（从存储加载/新建空文档）
  /// [type]：文档类型（visa/bulletin）
  /// [identifier]：所属实体ID
  /// [data]：文档数据（JSON字符串）
  /// [signature]：文档签名（TED格式）
  static Document create(String type, ID identifier, {String? data, TransportableData? signature}) {
    var ext = AccountExtensions();
    return ext.docHelper!.createDocument(type, identifier, data: data, signature: signature);
  }

  /// 解析任意对象为文档（支持字符串/Map）
  static Document? parse(Object? doc) {
    var ext = AccountExtensions();
    return ext.docHelper!.parseDocument(doc);
  }

  /// 获取指定类型的文档工厂
  static DocumentFactory? getFactory(String type) {
    var ext = AccountExtensions();
    return ext.docHelper!.getDocumentFactory(type);
  }
  
  /// 注册指定类型的文档工厂
  static void setFactory(String type, DocumentFactory factory) {
    var ext = AccountExtensions();
    ext.docHelper!.setDocumentFactory(type, factory);
  }
}

/// 【文档工厂接口】
/// 定义文档的创建/解析规范，不同类型（visa/bulletin）需实现此接口
abstract interface class DocumentFactory {
  /// 创建文档（从存储加载/新建）
  Document createDocument(ID identifier, {String? data, TransportableData? signature});

  /// 解析Map为文档对象
  Document? parseDocument(Map doc);
}