/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2025 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2025 Albert Moky
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
import 'package:lnc/log.dart';

import '../common/dbi/account.dart';
import '../common/protocol/version.dart';

import 'keychain.dart';

/// DIM账户创建核心类
/// 负责生成用户账户、创建用户ID、生成密钥对和身份凭证（Visa）
class Account {
  /// 构造方法
  /// [database]：账户数据库接口，用于存储账户相关数据（密钥、元数据、凭证等）
  Account(this.database);

  /// 账户数据库接口实例
  final AccountDBI database;

  /// 默认的Meta类型（以太坊类型）
  static String type = MetaType.ETH;

  /// 创建用户账户
  /// @param name  - 用户名（昵称）
  /// @param avatar - 头像URL（可选）
  /// @return 生成的用户ID（null表示创建失败）
  Future<ID?> createUser({required String name, String? avatar}) async {
    // 1. 从密钥链生成助记词（mnemonic）
    Keychain keychain = Keychain(database);
    String mnemonic = keychain.generate();
    // 保存助记词到数据库
    bool ok = await keychain.saveMnemonic(mnemonic);
    assert(ok, 'failed to save mnemonic: $mnemonic');
    
    // 2. 从助记词生成私钥（根据Meta类型选择ETH/BTC/MKM密钥）
    PrivateKey? idKey;
    String version = type;
    if (version == MetaType.ETH || version == MetaType.ExETH) {
      // 以太坊类型密钥
      idKey = await keychain.ethKey;
    } else {
      // 比特币/自定义MKM类型密钥
      assert(version == MetaType.BTC || version == MetaType.ExBTC
          || version == MetaType.MKM, 'meta type error: $version');
      idKey = await keychain.btcKey;
    }
    Log.debug('get private key: $idKey, mnemonic: $mnemonic');
    if (idKey == null) {
      assert(false, 'failed to get private key');
      return null;
    }
    
    // 3. 使用用户名、头像和私钥生成完整用户信息
    return await generateUser(name: name, avatar: avatar, idKey: idKey);
  }

  /// 生成完整的用户账户信息
  /// @param name - 用户名（昵称）
  /// @param avatar - 头像URL（可选）
  /// @param idKey - 身份私钥（用于签名Meta和Visa）
  /// @return 生成的用户ID
  Future<ID> generateUser({required String name, String? avatar, required PrivateKey idKey}) async {
    //
    //  Step 1: 使用私钥和Meta类型生成元数据（Meta）
    //  Meta包含公钥和类型信息，是用户身份的核心标识
    //
    Meta meta = Meta.generate(MetaVersion.parseString(type), idKey);
    
    //
    //  Step 2: 使用Meta和实体类型（用户）生成用户ID
    //  ID格式：name@address (address由Meta公钥生成)
    //
    ID identifier = ID.generate(meta, EntityType.USER);
    
    //
    //  Step 3: 生成用于通信加密的RSA私钥
    //  该密钥对用于消息加密/解密，与身份私钥分离
    //
    PrivateKey msgKey = PrivateKey.generate(AsymmetricAlgorithms.RSA)!;
    
    //
    //  Step 4: 生成用户凭证（Visa）并使用身份私钥签名
    //  Visa包含用户名、头像、通信公钥等信息，是用户的公开身份凭证
    //
    Visa visa = BaseVisa.from(identifier);
    visa.name = name.trim();  // 设置用户名
    visa.avatar = PortableNetworkFile.parse(avatar);  // 设置头像
    visa.publicKey = msgKey.publicKey as EncryptKey;  // 设置通信公钥
    // 使用身份私钥签名Visa，确保凭证不可篡改
    Uint8List? sig = visa.sign(idKey);
    assert(sig != null, 'failed to sign visa: $identifier');
    
    //
    //  Step 5: 将所有关键数据保存到本地数据库
    //  （注：还需将Meta和Visa上传到DIM服务器以完成身份注册）
    //
    await database.saveMeta(meta, identifier);  // 保存Meta
    // 保存身份私钥（用于Meta签名）
    await database.savePrivateKey(idKey, PrivateKeyDBI.kMeta, identifier, decrypt: 0);
    // 保存通信私钥（用于消息解密）
    await database.savePrivateKey(msgKey, PrivateKeyDBI.kVisa, identifier, decrypt: 1);
    await database.saveDocument(visa);  // 保存Visa凭证
    
    // 返回生成的用户ID
    return identifier;
  }

}