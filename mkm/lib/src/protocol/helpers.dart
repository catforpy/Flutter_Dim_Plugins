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
 * 核心功能：定义账户相关的助手接口，统一管理地址/ID/Meta/文档的工厂
 * 设计模式：单例模式 + 工厂模式，是所有账户相关工厂的注册/调用入口
 * 核心作用：解耦接口与实现，支持动态注册不同算法的工厂（如BTC/ETH地址生成）
 */

import 'package:mkm/mkm.dart';

/// 【地址助手接口】
/// 管理地址工厂的注册、解析、生成
abstract interface class AddressHelper{
  void setAddressFactory(AddressFactory factory);
  AddressFactory? getAddressFactory();
  Address? parseAddress(Object? address);
  Address generateAddress(Meta meta,int? network);
}

/// 【ID助手接口】
/// 管理ID工厂的注册、解析、创建、生成
abstract interface class IdentifierHelper{
  void setIdentifierFactory(IDFactory factory);
  IDFactory? getIdentifierFactory();
  ID? parseIdentifier(Object? identifier);
  ID createIdentifier({String? name, required Address address, String? terminal});
  ID generateIdentifier(Meta meta, int? network, {String? terminal});
}

/// 【元数据助手接口】
/// 管理Meta工厂的注册、创建、生成、解析
abstract interface class MetaHelper {
  void setMetaFactory(String type,MetaFactory factory);
  MetaFactory? getMetaFactory(String type);
  Meta createMeta(String type,VerifyKey pKey,{String? seed,TransportableData? fingerprint});
  Meta generateMeta(String type, SignKey sKey, {String? seed});
  Meta? parseMeta(Object? meta);
}

/// 【文档助手接口】
/// 管理文档工厂的注册、创建、解析
abstract interface class DocumentHelper {
  void setDocumentFactory(String docType, DocumentFactory factory);
  DocumentFactory? getDocumentFactory(String docType);
  Document createDocument(String docType, ID identifier, {String? data, TransportableData? signature});
  Document? parseDocument(Object? doc);
}

/// 【账户扩展管理器】
/// 单例类，统一管理所有账户相关助手实例，是工厂注册的核心入口
// protected：仅内部使用
class AccountExtensions {
  /// 工厂构造方法：返回单例实例
  factory AccountExtensions() => _instance;
  
  /// 静态单例实例
  static final AccountExtensions _instance = AccountExtensions._internal();
  
  /// 私有构造方法：防止外部实例化
  AccountExtensions._internal();

  /// 地址助手实例（外部注入实现）
  AddressHelper? addressHelper;
  
  /// ID助手实例（外部注入实现）
  IdentifierHelper? idHelper;
  
  /// 元数据助手实例（外部注入实现）
  MetaHelper? metaHelper;
  
  /// 文档助手实例（外部注入实现）
  DocumentHelper? docHelper;
}