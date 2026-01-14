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

/// 账户通用工厂（核心）
/// 核心作用：
/// 1. 实现 MKM 协议中所有账户相关接口，一站式管理「地址/ID/元数据/文档」的创建/解析；
/// 2. 维护不同类型的工厂实例映射（如不同算法的Meta工厂、不同类型的Document工厂）；
/// 3. 提供类型自动补全、格式校验等增强能力；
/// 接口说明：
/// - GeneralAccountHelper：通用账户辅助能力（类型提取）；
/// - AddressHelper/IdentifierHelper：地址/ID的创建/解析；
/// - MetaHelper/DocumentHelper：元数据/文档的创建/解析；
class AccountGeneralFactory implements GeneralAccountHelper,
                                       AddressHelper, IdentifierHelper,
                                       MetaHelper, DocumentHelper {
  /// 地址工厂实例（全局唯一）
  AddressFactory?                    _addressFactory;
  /// ID工厂实例（全局唯一）
  IDFactory?                         _idFactory;
  /// 元数据工厂映射：key=元数据类型，value=对应工厂
  final Map<String,MetaFactory>      _metaFactories = {};
  /// 文档工厂映射：key=文档类型，value=对应工厂
  final Map<String,DocumentFactory>  _docsFactories = {};   

  /// 提取元数据类型（从Map中）
  /// 补充说明：
  /// - 元数据(Meta)的type字段标识其算法类型（如MKM/BTCLike）；
  /// - 若字段不存在，返回默认值；
  /// [meta] - 元数据原始Map
  /// [defaultValue] - 字段不存在时的默认值
  /// 返回值：元数据类型字符串
  @override
  String? getMetaType(Map meta,[String? defaultValue]){
    return Converter.getString(meta['type'],defaultValue);
  }

  /// 提取文档类型（从Map中，支持自动补全）
  /// 补充说明：
  /// 1. 优先从doc['type']提取；
  /// 2. 无type字段时，根据did（文档所属ID）自动补全：
  ///    - 用户ID → VISA（签证文档）；
  ///    - 群组ID → BULLETIN（公告文档）；
  ///    - 其他 → PROFILE（个人资料）；
  /// [doc] - 文档原始Map
  /// [defaultValue] - 兜底默认值
  /// 返回值：文档类型字符串
  @override
  String? getDocumentType(Map doc,[String? defaultValue]){
    // 1. 有限提取doc['type']字段
    var docType = doc['type'];
    if(docType != null){
      return Converter.getString(docType,defaultValue);
    }else if(defaultValue != null){
      return defaultValue;
    }
    // 2.无type字段时，从did字段推导
    var did = ID.parse(doc['did']);
    if(did == null){
      assert(false, 'document error: $doc');
      return null;
    }else if(did.isUser){
      // 用户ID → 签证文档
      return DocumentType.VISA;
    }else if (did.isGroup) {
      // 群组ID → 公告文档
      return DocumentType.BULLETIN;
    } else {
      // 其他 → 个人资料
      return DocumentType.PROFILE;
    }
  }

  // ====================== Address 地址相关方法 ======================

  /// 设置地址工厂实例
  @override
  void setAddressFactory(AddressFactory factory) {
    _addressFactory = factory;
  }

  /// 获取地址工厂实例
  @override
  AddressFactory? getAddressFactory() {
    return _addressFactory;
  }

  /// 解析地址（支持多类型输入）
  /// 补充说明：
  /// 1. 输入可为null/Address/String/其他可转为字符串的类型；
  /// 2. 先类型校验，再通过地址工厂解析；
  /// [address] - 待解析的地址（任意类型）
  /// 返回值：Address实例（失败返回null）
  @override
  Address? parseAddress(Object? address){
    if (address == null) {
      return null;
    } else if (address is Address) {
      // 已是Address实例，直接返回
      return address;
    }
    // 转为字符串
    var str = Wrapper.getString(address);
    if (str == null) {
      assert(false, 'address error: $address');
      return null;
    }
    // 通过地址工厂解析
    AddressFactory? factory = getAddressFactory();
    assert(factory != null, 'address factory not ready');
    return factory?.parseAddress(str);
  }

  /// 生成地址（基于元数据+网络类型）
  /// 补充说明：
  /// - 地址由元数据（Meta）和网络类型（如用户/群组）计算生成；
  /// - 是去中心化ID的核心：地址 = 哈希(元数据) + 网络标识；
  /// [meta] - 元数据
  /// [network] - 网络类型（用户/群组/机器人等）
  /// 返回值：生成的Address实例
  @override
  Address generateAddress(Meta meta,int? network){
    AddressFactory? factory = getAddressFactory();
    assert(factory != null, 'address factory not ready');
    return factory!.generateAddress(meta, network);
  }

  // ====================== ID 标识符相关方法 ======================

  /// 设置ID工厂实例
  @override
  void setIdentifierFactory(IDFactory factory) {
    _idFactory = factory;
  }

  /// 获取ID工厂实例
  @override
  IDFactory? getIdentifierFactory() {
    return _idFactory;
  }

  /// 解析ID（支持多类型输入）
  /// 补充说明：
  /// - ID格式：name@address/terminal（如 alice@xxx.com/phone）；
  /// - 解析逻辑与地址类似，优先类型校验，再通过ID工厂解析；
  /// [identifier] - 待解析的ID（任意类型）
  /// 返回值：ID实例（失败返回null）
  @override
  ID? parseIdentifier(Object? identifier){
    if (identifier == null) {
      return null;
    } else if (identifier is ID) {
      return identifier;
    }
    String? str = Wrapper.getString(identifier);
    if (str == null) {
      assert(false, 'ID error: $identifier');
      return null;
    }
    IDFactory? factory = getIdentifierFactory();
    assert(factory != null, 'ID factory not ready');
    return factory?.parseIdentifier(str);
  }

  /// 创建ID（手动指定名称+地址+终端）
  /// 补充说明：
  /// - 手动创建ID，适用于已知地址的场景；
  /// - name：可选昵称，address：必选地址，terminal：可选终端（如phone/pc）；
  /// [name] - 名称（可选）
  /// [address] - 地址（必填）
  /// [terminal] - 终端（可选）
  /// 返回值：创建的ID实例
  @override
  ID createIdentifier({String? name, required Address address, String? terminal}) {
    IDFactory? factory = getIdentifierFactory();
    assert(factory != null, 'ID factory not ready');
    return factory!.createIdentifier(name: name, address: address, terminal: terminal);
  }

  /// 生成ID（基于元数据+网络类型）
  /// 补充说明：
  /// - 自动生成ID：先通过元数据生成地址，再拼接终端；
  /// - 是去中心化ID的核心生成方式；
  /// [meta] - 元数据
  /// [network] - 网络类型
  /// [terminal] - 终端（可选）
  /// 返回值：生成的ID实例
  @override
  ID generateIdentifier(Meta meta, int? network, {String? terminal}) {
    IDFactory? factory = getIdentifierFactory();
    assert(factory != null, 'ID factory not ready');
    return factory!.generateIdentifier(meta, network, terminal: terminal);
  }

  // ====================== Meta 元数据相关方法 ======================

  /// 设置元数据工厂（按类型映射）
  /// [type] - 元数据类型（如MKM/BTCLike）
  /// [factory] - 对应类型的Meta工厂
  @override
  void setMetaFactory(String type, MetaFactory factory) {
    _metaFactories[type] = factory;
  }

  /// 获取元数据工厂（按类型）
  /// [type] - 元数据类型
  /// 返回值：对应Meta工厂（未找到返回null）
  @override
  MetaFactory? getMetaFactory(String type) {
    return _metaFactories[type];
  }

  /// 创建元数据（已知公钥+类型）
  /// 补充说明：
  /// - 元数据包含公钥、类型、指纹等，是ID的核心凭证；
  /// - 不同类型的元数据由对应工厂创建；
  /// [type] - 元数据类型
  /// [pKey] - 公钥
  /// [seed] - 种子（可选）
  /// [fingerprint] - 指纹（可选）
  /// 返回值：创建的Meta实例
  @override
  Meta createMeta(String type, VerifyKey pKey, {String? seed, TransportableData? fingerprint}) {
    MetaFactory? factory = getMetaFactory(type);
    assert(factory != null, 'meta type not supported: $type');
    return factory!.createMeta(pKey, seed: seed, fingerprint: fingerprint);
  }

  /// 生成元数据（基于私钥+类型）
  /// 补充说明：
  /// - 自动生成元数据：先从私钥导出公钥，再创建元数据；
  /// - 适用于新建账户的场景；
  /// [type] - 元数据类型
  /// [sKey] - 私钥
  /// [seed] - 种子（可选）
  /// 返回值：生成的Meta实例
  @override
  Meta generateMeta(String type, SignKey sKey, {String? seed}) {
    MetaFactory? factory = getMetaFactory(type);
    assert(factory != null, 'meta type not supported: $type');
    return factory!.generateMeta(sKey, seed: seed);
  }

  /// 解析元数据（支持多类型输入）
  /// 补充说明：
  /// 1. 先提取元数据类型，再用对应工厂解析；
  /// 2. 未知类型时使用默认工厂（key='*'）；
  /// [meta] - 待解析的元数据（任意类型）
  /// 返回值：Meta实例（失败返回null）
  @override
  Meta? parseMeta(Object? meta) {
    if (meta == null) {
      return null;
    } else if (meta is Meta) {
      return meta;
    }
    Map? info = Wrapper.getMap(meta);
    if (info == null) {
      assert(false, 'meta error: $meta');
      return null;
    }
    // 提取元数据类型
    String? type = getMetaType(info);
    assert(type != null, 'meta error: $meta');
    // 获取对应工厂
    MetaFactory? factory = type == null ? null : getMetaFactory(type);
    if (factory == null) {
      // 未知类型，使用默认工厂
      factory = getMetaFactory('*');  // unknown
      assert(factory != null, 'default meta factory not found');
    }
    return factory?.parseMeta(info);
  }

  // ====================== Document 文档相关方法 ======================

  /// 设置文档工厂（按类型映射）
  /// [docType] - 文档类型（如VISA/PROFILE）
  /// [factory] - 对应类型的Document工厂
  @override
  void setDocumentFactory(String docType, DocumentFactory factory) {
    _docsFactories[docType] = factory;
  }

  /// 获取文档工厂（按类型）
  /// [docType] - 文档类型
  /// 返回值：对应Document工厂（未找到返回null）
  @override
  DocumentFactory? getDocumentFactory(String docType) {
    return _docsFactories[docType];
  }

  /// 创建文档（已知类型+ID）
  /// 补充说明：
  /// - 文档是ID的扩展信息，需关联具体的ID；
  /// - 包含数据、签名等字段，可验证真实性；
  /// [docType] - 文档类型
  /// [identifier] - 所属ID
  /// [data] - 文档数据（可选）
  /// [signature] - 签名（可选）
  /// 返回值：创建的Document实例
  @override
  Document createDocument(String docType, ID identifier, {String? data, TransportableData? signature}) {
    DocumentFactory? factory = getDocumentFactory(docType);
    assert(factory != null, 'document type not supported: $docType');
    return factory!.createDocument(identifier, data: data, signature: signature);
  }

  /// 解析文档（支持多类型输入）
  /// 补充说明：
  /// 1. 先提取/推导文档类型，再用对应工厂解析；
  /// 2. 未知类型时使用默认工厂（key='*'）；
  /// [doc] - 待解析的文档（任意类型）
  /// 返回值：Document实例（失败返回null）
  @override
  Document? parseDocument(Object? doc) {
    if (doc == null) {
      return null;
    } else if (doc is Document) {
      return doc;
    }
    Map? info = Wrapper.getMap(doc);
    if (info == null) {
      assert(false, 'document error: $doc');
      return null;
    }
    // 提取/推导文档类型
    String? type = getDocumentType(info);
    //assert(type != null, 'document error: $doc');
    // 获取对应工厂
    DocumentFactory? factory = type == null ? null : getDocumentFactory(type);
    if (factory == null) {
      // 未知类型，使用默认工厂
      factory = getDocumentFactory('*');  // unknown
      assert(factory != null, 'default document factory not found');
    }
    return factory?.parseDocument(info);
  }

}