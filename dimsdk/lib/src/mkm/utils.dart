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

import 'dart:typed_data';

import 'package:dimsdk/dimp.dart';

/// 元数据工具类
/// 核心作用：提供去中心化身份体系中「元数据（Meta）」的合法性校验逻辑，
///          是保障ID与Meta、公钥与Meta一致性的核心工具
abstract interface class MetaUtils{
  /// 校验元数据与实体ID是否匹配
  /// 调用时机：从网络获取到新的Meta时必须调用，防止伪造身份
  /// 核心逻辑：
  /// 1. 校验ID名称与Meta的seed是否一致
  /// 2. 校验ID地址是否能通过Meta重新生成（确保地址合法性）
  /// @param identifier - 实体ID（用户/群组ID）
  /// @param meta       - 待校验的实体元数据
  /// @return 匹配返回true，不匹配返回false
  static bool matchIdentifier(ID identifier,Meta meta){
    // 前置断言：Meta必须是合法的（否则直接校验失败）
    assert(meta.isValid, '元数据不合法: $meta');
    
    // 第一步：校验ID名称与Meta的seed字段
    String? seed = meta.seed; // Meta中的种子值（对应ID名称）
    String? name = identifier.name; // ID的名称部分
    if (name == null || name.isEmpty) {
      // ID无名称时，Meta的seed也必须为空
      if (seed != null && seed.isNotEmpty) {
        return false;
      }
    } else if (name != seed) {
      // ID名称与Meta的seed不一致，直接不匹配
      return false;
    }

    // 第二步：校验ID地址的生成规则
    Address oldAddress = identifier.address; // ID原有地址
    // 根据Meta重新生成同网络的地址
    Address genAddress = Address.generate(meta, oldAddress.network);
    // 对比原有地址和生成地址是否一致
    return oldAddress == genAddress;
  }

  /// 校验公钥与元数据是否匹配
  /// 核心逻辑：
  /// 1. 优先直接对比公钥是否完全相等
  /// 2. 若不相等，通过seed+指纹验签的方式二次校验
  /// @param pKey - 待校验的公钥
  /// @param meta - 实体元数据
  /// @return 匹配返回true，不匹配返回false
  static bool matchPublicKey(VerifyKey pKey, Meta meta){
    // 前置断言：Meta必须是合法的
    assert(meta.isValid, 'meta not valid: $meta');

    // 第一步：直接对比公钥是否相等（最优先的校验方式）
    if(pKey == meta.publicKey){
      return true;
    }

    // 第二部：通过seed+指纹验签的方式校验（适配有名称的ID）
    String? seed = meta.seed;
    if(seed == null || seed.isEmpty){
      // BTC/ETH地址类型的ID无名称，无seed是直接返回不匹配
      return false;
    }
    Uint8List? fingerprint = meta.fingerprint;  //Meta中获取指纹（签名值）
    if(fingerprint == null || fingerprint.isEmpty){
      // 有seed的情况下，指纹不能为空
      return false;
    }

    // 验签逻辑：用公钥验证seed的签名是否等于指纹
    Uint8List seedData = UTF8.encode(seed); //将seed转为字节数据
    return pKey.verify(seedData, fingerprint);    //验签通过则匹配
  }
}

/// 文档工具类
/// 核心作用：封装「文档（Document）」的通用处理逻辑，包括：
///          1. 文档类型解析 2. 过期时间判断 3. 最新有效文档筛选
///          简化业务层对用户/群组资料的处理逻辑
abstract interface class DocumentUtils{

  /// 解析文档类型
  /// 适配扩展文档类型场景，通过扩展工具类获取文档的具体类型（如签证、公告等）
  /// @param document - 待解析的文档对象
  /// @return 文档类型字符串，无类型返回null
  static String? getDocumentType(Document document){
    var ext = SharedAccountExtensions();
    return ext.helper?.getDocumentType(document);
  }

  /// 判断当前时间是否早于旧时间
  /// 基础工具方法：用于文档过期判断的核心逻辑
  /// @param oldTime  - 旧时间（参考时间）
  /// @param thisTime - 当前时间（待判断时间）
  /// @return 当前时间早于旧时间返回true，否则返回false
  static bool isBefore(DateTime? oldTime,DateTime? thisTime){
    // 任意时间为空时，直接返回false
    if(oldTime == null || thisTime == null){
      return false;
    }
    return thisTime.isBefore(oldTime);
  }

  /// 判断当前文档是否过期
  /// 核心逻辑：对比两个文档的时间，当前文档时间早于旧文档则视为过期
  /// @param thisDoc - 当前待判断的文档
  /// @param oldDoc  - 旧文档（参考文档）
  /// @return 当前文档过期返回true，否则返回false
  static bool isExpired(Document thisDoc,Document oldDoc){
    // 复用isBefore方法，对比文档的时间字段
    return isBefore(oldDoc.time, thisDoc.time);
  }

  /// 筛选指定类型的最新有效文档
  /// 支持通配符*（传*或null时筛选所有类型的最新文档）
  /// 核心流程：
  /// 1. 过滤出匹配类型的文档
  /// 2. 从匹配文档中筛选出时间最新的有效文档
  /// @param documents - 文档列表
  /// @param type      - 文档类型（可选，默认*）
  /// @return 最新有效文档，无匹配返回null
  static Document? lastDocument(Iterable<Document> documents,[String? type]){
    // 处理通配符：null/* 转为空字符串，表示匹配所有类型
    if(type == null || type == '*'){
      type = '';
    }
    // 是否需要校验文档类型（类型为空时不校验）
    bool checkType = type.isNotEmpty;

    Document? lastDoc;  //存储最新文档
    String? docType;    //临时存储当前文档类型
    bool isMatched;     //类型是否匹配

    // 遍历文档列表，筛选最近有效文档
    for(Document doc in documents){
      // 第一步：类型校验
      docType = getDocumentType(doc);
      // 类型匹配规则：文档类型为空火雨目标类型一致
      isMatched = docType == null || docType.isEmpty || docType == type;
      if(!isMatched){
        // 类型不匹配，跳过当前文档
        continue;
      }

      // 第二步：时间校验（筛选最新文档）
      if(lastDoc != null && isExpired(doc, lastDoc)){
        // 当前文档时间早于已找到的最新文档，跳过
        continue;
      }

      // 第三步：更新最新文档
      lastDoc = doc;
    }
    return lastDoc;
  }

  /// 筛选最新有效签证文档
  /// 专用方法：简化Visa类型文档的筛选逻辑（无需传类型参数）
  /// 核心逻辑：遍历文档列表，只保留Visa类型且时间最新的文档
  /// @param documents - 文档列表
  /// @return 最新有效签证文档，无匹配返回null
  static Visa? lastVisa(Iterable<Document> documents){
    Visa? lastVisaDoc;
    bool isMatched;

    for(Document doc in documents){
      // 第一步：类型校验（必须是Visa类型）
      isMatched = doc is Visa;
      if (!isMatched) {
        continue;
      }

      // 第二步：时间校验（筛选最新）
      if (lastVisaDoc != null && isExpired(doc, lastVisaDoc)) {
        continue;
      }

      // 第三步：更新最新签证文档
      lastVisaDoc = doc;
    }
    return lastVisaDoc;
  }

  /// 筛选最新有效公告文档
  /// 专用方法：简化Bulletin类型文档的筛选逻辑
  /// 核心逻辑：遍历文档列表，只保留Bulletin类型且时间最新的文档
  /// @param documents - 文档列表
  /// @return 最新有效公告文档，无匹配返回null
  static Bulletin? lastBulletin(Iterable<Document> documents) {
    Bulletin? lastBulletinDoc;
    bool isMatched;

    for (Document doc in documents) {
      // 第一步：类型校验（必须是Bulletin类型）
      isMatched = doc is Bulletin;
      if (!isMatched) {
        continue;
      }

      // 第二步：时间校验（筛选最新）
      if (lastBulletinDoc != null && isExpired(doc, lastBulletinDoc)) {
        continue;
      }

      // 第三步：更新最新公告文档
      lastBulletinDoc = doc;
    }

    return lastBulletinDoc;
  }
}