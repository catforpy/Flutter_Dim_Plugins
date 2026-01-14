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

import 'package:dimp/dimp.dart';  // DIM核心协议库

import 'crypto/aes.dart';         // AES加密实现
import 'crypto/digest.dart';      // 哈希算法实现
import 'crypto/ecc.dart';         // ECC加密实现
import 'crypto/plain.dart';       // 明文密钥实现
import 'crypto/rsa.dart';         // RSA加密实现
import 'format/coders.dart';      // 编码解码实现
import 'format/pnf.dart';         // PNF实现
import 'format/ted.dart';         // TED实现

import 'mkm/address.dart';        // 地址实现
import 'mkm/identifier.dart';     // ID实现
import 'mkm/meta.dart';           // 元数据实现
import 'mkm/document.dart';       // 文档实现


/// 插件加载器
/// 核心作用：
/// 1. 注册所有底层插件（编码/哈希/加密/账号相关）；
/// 2. 初始化各类算法实现（Base58/Base64/SHA256/ECC/RSA等）；
/// 3. 绑定账号相关工厂（地址/ID/元数据/文档）；
/// 设计特点：按功能模块拆分注册方法，便于维护和扩展；
class PluginLoader {

  /// 加载所有插件（入口方法）
  void load() {
    /// 注册所有插件
    // 1. 注册编码解码器（Base58/Base64/JSON等）
    registerCoders();
    // 2. 注册哈希算法（SHA256/KECCAK256/RIPEMD160）
    registerDigesters();

    // 3. 注册对称密钥工厂（AES/明文）
    registerSymmetricKeyFactories();
    // 4. 注册非对称密钥工厂（RSA/ECC）
    registerAsymmetricKeyFactories();

    // 5. 注册账号相关工厂（地址/ID/元数据/文档）
    registerEntityFactories();
  }

  // ==================== 编码解码器注册 ====================
  // protected
  void registerCoders() {
    /// 数据编解码器
    // 基础编码（Base58/Base64/HEX）
    registerBase58Coder();
    registerBase64Coder();
    registerHexCoder();

    // 字符编码（UTF8）、数据序列化（JSON）
    registerUTF8Coder();
    registerJSONCoder();

    // 格式工厂（PNF/TED）
    registerPNFFactory();
    registerTEDFactory();
  }

  /// 注册Base58编解码器
  // protected
  void registerBase58Coder() {
    /// Base58编码（BTC地址使用）
    Base58.coder = Base58Coder();
  }

  /// 注册Base64编解码器
  // protected
  void registerBase64Coder() {
    /// Base64编码（TED数据传输使用）
    Base64.coder = Base64Coder();
  }

  /// 注册HEX编解码器
  // protected
  void registerHexCoder() {
    /// HEX编码（ETH地址/密钥使用）
    Hex.coder = HexCoder();
  }

  /// 注册UTF8编解码器
  // protected
  void registerUTF8Coder() {
    /// UTF8字符编码（字符串转字节）
    UTF8.coder = UTF8Coder();
  }

  /// 注册JSON编解码器
  // protected
  void registerJSONCoder() {
    /// JSON序列化/反序列化（消息/内容传输）
    JSON.coder = JSONCoder();
  }

  /// 注册PNF工厂
  // protected
  void registerPNFFactory() {
    /// PNF（可移植网络文件）工厂注册
    PortableNetworkFile.setFactory(BaseNetworkFileFactory());
  }

  /// 注册TED工厂
  // protected
  void registerTEDFactory() {
    /// TED（可传输数据）工厂注册
    var tedFactory = Base64DataFactory();
    // 注册BASE64类型的TED工厂
    TransportableData.setFactory(EncodeAlgorithms.BASE_64, tedFactory);
    // TransportableData.setFactory(EncodeAlgorithms.DEFAULT, tedFactory);
    // 注册通配符（默认）TED工厂
    TransportableData.setFactory('*', tedFactory);
  }

  // ==================== 哈希算法注册 ====================
  /// 消息哈希算法注册
  // protected
  void registerDigesters() {
    // SHA256（通用哈希）
    registerSHA256Digester();
    // KECCAK256（ETH地址使用）
    registerKECCAK256Digester();
    // RIPEMD160（BTC地址使用）
    registerRIPEMD160Digester();
  }

  /// 注册SHA256哈希器
  // protected
  void registerSHA256Digester() {
    /// SHA256哈希算法
    SHA256.digester = SHA256Digester();
  }

  /// 注册KECCAK256哈希器
  // protected
  void registerKECCAK256Digester() {
    /// Keccak256哈希算法（ETH专用）
    KECCAK256.digester = KECCAK256Digester();
  }

  /// 注册RIPEMD160哈希器
  // protected
  void registerRIPEMD160Digester() {
    /// RIPEMD160哈希算法（BTC专用）
    RIPEMD160.digester = RIPEMD160Digester();
  }

  // ==================== 对称密钥工厂注册 ====================
  /// 对称密钥解析器注册
  // protected
  void registerSymmetricKeyFactories() {
    // AES（对称加密）
    registerAESKeyFactory();
    // 明文（无加密）
    registerPlainKeyFactory();
  }

  /// 注册AES密钥工厂
  // protected
  void registerAESKeyFactory() {
    /// AES对称加密
    var aes = AESKeyFactory();
    // 注册AES算法工厂
    SymmetricKey.setFactory(SymmetricAlgorithms.AES, aes);
    // 注册AES/CBC/PKCS7模式工厂
    SymmetricKey.setFactory(AESKey.AES_CBC_PKCS7, aes);
    // SymmetricKey.setFactory('AES/CBC/PKCS7Padding', aes);
  }

  /// 注册明文密钥工厂
  // protected
  void registerPlainKeyFactory() {
    /// 明文密钥（无加密）
    SymmetricKey.setFactory(SymmetricAlgorithms.PLAIN, PlainKeyFactory());
  }

  // ==================== 非对称密钥工厂注册 ====================
  /// 非对称密钥解析器注册
  // protected
  void registerAsymmetricKeyFactories() {
    // RSA（非对称加密）
    registerRSAKeyFactories();
    // ECC（椭圆曲线加密）
    registerECCKeyFactories();
  }

  /// 注册RSA密钥工厂
  // protected
  void registerRSAKeyFactories() {
    /// RSA非对称加密
    // RSA公钥工厂
    var rsaPub = RSAPublicKeyFactory();
    PublicKey.setFactory(AsymmetricAlgorithms.RSA, rsaPub);
    PublicKey.setFactory('SHA256withRSA', rsaPub);
    PublicKey.setFactory('RSA/ECB/PKCS1Padding', rsaPub);

    // RSA私钥工厂
    var rsaPri = RSAPrivateKeyFactory();
    PrivateKey.setFactory(AsymmetricAlgorithms.RSA, rsaPri);
    PrivateKey.setFactory('SHA256withRSA', rsaPri);
    PrivateKey.setFactory('RSA/ECB/PKCS1Padding', rsaPri);
  }

  /// 注册ECC密钥工厂
  // protected
  void registerECCKeyFactories() {
    /// ECC椭圆曲线加密
    // ECC公钥工厂
    var eccPub = ECCPublicKeyFactory();
    PublicKey.setFactory(AsymmetricAlgorithms.ECC, eccPub);
    PublicKey.setFactory('SHA256withECDSA', eccPub);

    // ECC私钥工厂
    var eccPri = ECCPrivateKeyFactory();
    PrivateKey.setFactory(AsymmetricAlgorithms.ECC, eccPri);
    PrivateKey.setFactory('SHA256withECDSA', eccPri);
  }

  // ==================== 账号相关工厂注册 ====================
  /// ID/地址/元数据/文档解析器注册
  // protected
  void registerEntityFactories() {
    // ID工厂
    registerIDFactory();
    // 地址工厂
    registerAddressFactory();
    // 元数据工厂
    registerMetaFactories();
    // 文档工厂
    registerDocumentFactories();
  }

  /// 注册ID工厂
  // protected
  void registerIDFactory() {
    ID.setFactory(IdentifierFactory());
  }

  /// 注册地址工厂
  // protected
  void registerAddressFactory() {
    Address.setFactory(BaseAddressFactory());
  }

  /// 注册元数据工厂
  // protected
  void registerMetaFactories() {
    // MKM类型元数据
    setMetaFactory(MetaType.MKM, 'mkm');
    // BTC类型元数据
    setMetaFactory(MetaType.BTC, 'btc');
    // ETH类型元数据
    setMetaFactory(MetaType.ETH, 'eth');
  }

  /// 注册元数据工厂（工具方法）
  /// [type] - 元数据类型（如MetaType.MKM）
  /// [alias] - 类型别名（如'mkm'）
  /// [factory] - 元数据工厂（可选，默认创建BaseMetaFactory）
  // protected
  void setMetaFactory(String type, String alias, {MetaFactory? factory}) {
    factory ??= BaseMetaFactory(type);
    Meta.setFactory(type, factory);
    Meta.setFactory(alias, factory);
  }

  /// 注册文档工厂
  // protected
  void registerDocumentFactories() {
    // 通用文档（通配符）
    setDocumentFactory('*');
    // 签证文档
    setDocumentFactory(DocumentType.VISA);
    // 个人资料文档
    setDocumentFactory(DocumentType.PROFILE);
    // 公告文档
    setDocumentFactory(DocumentType.BULLETIN);
  }

  /// 注册文档工厂（工具方法）
  /// [type] - 文档类型（如DocumentType.VISA）
  /// [factory] - 文档工厂（可选，默认创建GeneralDocumentFactory）
  // protected
  void setDocumentFactory(String type, {DocumentFactory? factory}) {
    factory ??= GeneralDocumentFactory(type);
    Document.setFactory(type, factory);
  }
}