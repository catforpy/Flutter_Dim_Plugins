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

import 'package:mkm/src/protocol/helpers.dart';

/// 账户通用辅助器接口
/// 补充说明：
/// 1. 整合地址(Address)、标识符(Identifier)、元数据(Meta)、文档(Document)相关辅助能力；
/// 2. 提供元数据/文档类型的统一获取方法；
/// 3. 注：注释中被注释的接口实现（AddressHelper/IdentifierHelper等）表示该接口
///    实际整合了这些辅助器的能力，便于统一管理
abstract interface class GeneralAccountHelper{
  //
  //  Algorithm Version - 算法版本
  //

  /// 从元数据Map中获取类型（算法版本）
  /// 补充说明：
  /// - 元数据(Meta)是用户/群组的核心标识数据，包含算法类型、公钥等；
  /// - 该方法用于统一提取Meta中的类型字段，适配不同格式的Meta结构；
  /// [meta] - 元数据Map
  /// [defaultValue] - 字段不存在/解析失败时返回的默认值
  String? getMetaType(Map meta, [String? defaultValue]);

  /// 从文档Map中获取类型（算法版本）
  /// 补充说明：
  /// - 文档(Document)是用户/群组的扩展信息（如头像、昵称、公钥列表等）；
  /// - 不同类型的Document（profile/keys/contact等）通过该字段区分；
  /// [doc] - 文档Map
  /// [defaultValue] - 字段不存在/解析失败时返回的默认值
  String? getDocumentType(Map doc,[String? defaultValue]);
}

/// 账户扩展管理器（单例）
/// 补充说明：
/// 1. 采用单例模式，统一管理各类账户相关辅助器的实例；
/// 2. 内部通过AccountExtensions()转发读写操作，实现辅助器的全局共享；
/// 3. 同时维护一个通用辅助器(GeneralAccountHelper)实例，便于统一调用
class SharedAccountExtensions {
  /// 工厂构造函数（返回单例）
  factory SharedAccountExtensions() => _instance;
  
  /// 静态单例实例
  static final SharedAccountExtensions _instance = SharedAccountExtensions._internal();
  
  /// 私有构造函数（防止外部实例化）
  SharedAccountExtensions._internal();

  /// 地址辅助器 - 读写
  /// 补充说明：封装Address相关的创建、解析、验证等能力
  AddressHelper? get addressHelper => AccountExtensions().addressHelper;

  set addressHelper(AddressHelper? helper) => AccountExtensions().addressHelper = helper;

  /// 标识符(ID)辅助器 - 读写
  /// 补充说明：封装Identifier（用户/群组ID）的创建、解析、验证等能力
  IdentifierHelper? get idHelper => AccountExtensions().idHelper;

  set idHelper(IdentifierHelper? helper) => AccountExtensions().idHelper = helper;

  /// 元数据(Meta)辅助器 - 读写
  /// 补充说明：封装Meta的创建、解析、验证、签名验证等能力
  MetaHelper? get metaHelper => AccountExtensions().metaHelper;

  set MetaHelper (MetaHelper? helper) => AccountExtensions().metaHelper = helper;

  /// 文档(Document)辅助器 - 读写
  /// 补充说明：封装Document的创建、解析、验证、签名验证等能力
  DocumentHelper? get docHelper => AccountExtensions().docHelper;

  set docHelper (DocumentHelper? helper) => AccountExtensions().docHelper = helper;

  /// 通用账户辅助器
  /// 补充说明：全局共享的GeneralAccountHelper实例，可统一处理各类账户相关通用操作
  GeneralAccountHelper? helper;
}