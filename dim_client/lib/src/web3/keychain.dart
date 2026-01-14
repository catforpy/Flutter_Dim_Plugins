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

import 'package:bip32/bip32.dart';  // BIP32分层确定性钱包
import 'package:bip39/bip39.dart';  // BIP39助记词

import 'package:dimsdk/dimp.dart';
import 'package:dim_plugins/mkm.dart';
import 'package:lnc/log.dart';

import '../common/dbi/account.dart';

// 参考：https://iancoleman.io/bip39/#english (BIP39助记词工具)

/// 密钥链管理类
/// 基于BIP39/BIP32标准实现助记词生成、钱包派生、密钥管理
class Keychain {
  /// 构造方法
  /// [database]：私钥数据库接口，用于存储助记词和密钥
  Keychain(this.database);

  /// 私钥数据库接口实例
  final PrivateKeyDBI database;

  /// 主账户ID（固定为may@anywhere，用于存储助记词）
  ID get master => ID.parse('may@anywhere')!;

  ///
  ///   助记词（Mnemonic）相关方法
  ///

  /// 生成BIP39助记词
  /// [strength]：熵值强度（128/160/192/224/256），默认128对应12个助记词
  /// 返回：生成的助记词字符串（空格分隔）
  String generate({int strength = 128}) => generateMnemonic(strength: strength);

  /// 从数据库获取已保存的助记词
  /// 返回：助记词字符串（null表示未找到）
  Future<String?> get mnemonic async {
    // 从主账户获取用于Visa签名的私钥（实际存储的是助记词的熵值）
    PrivateKey? puppet = await database.getPrivateKeyForVisaSignature(master);
    String? pem = puppet?.getString('data');
    Log.debug('master key data: $pem, $master');
    if (pem == null) {
      return null;
    }
    
    // 解析PEM格式的熵值数据（去除BEGIN/END标记，提取核心内容）
    List<String> rows = pem.split(RegExp(r'\r\n?|\n'));
    String entropy = rows
        .skipWhile((row) => row.startsWith('-----BEGIN'))  // 跳过BEGIN行
        .takeWhile((row) => !row.startsWith('-----END'))  // 取到END行前
        .map((row) => row.trim())  // 去除空格
        .join('');  // 拼接成完整字符串
    Log.debug('get entropy: $entropy, $master');
    assert(entropy.length == 32, 'entropy length error: [$entropy]');
    
    // 将熵值转换回助记词
    return entropyToMnemonic(entropy);
  }

  /// 保存助记词到数据库
  /// [words]：助记词字符串（空格分隔）
  /// 返回：是否保存成功
  Future<bool> saveMnemonic(String words) async {
    String entropy;
    try {
      // 将助记词转换为熵值（16进制字符串）
      entropy = mnemonicToEntropy(words);
    } on ArgumentError {
      // 助记词格式错误
      return false;
    } on StateError {
      // 熵值转换错误
      return false;
    }
    
    // 创建虚拟私钥对象存储熵值（算法标记为ECC）
    PrivateKey puppet = PrivateKey.parse({
      'algorithm': AsymmetricAlgorithms.ECC,
      'data': entropy,
    })!;
    Log.debug('save mnemonic: $words => $entropy');
    
    // 保存到主账户的Meta私钥位置（sign=1表示用于签名，decrypt=0表示不用于解密）
    return await database.savePrivateKey(puppet, PrivateKeyDBI.kMeta, master,
        sign: 1, decrypt: 0);
  }

  ///
  ///   钱包（Wallet）相关方法
  ///

  /// 获取比特币钱包（BIP32路径：m/44'/0'/0'/0/0）
  /// 返回：BIP32钱包实例（null表示失败）
  Future<BIP32?> get btcWallet async => await getWallet("m/44'/0'/0'/0/0");
  
  /// 获取以太坊钱包（BIP32路径：m/44'/60'/0'/0/0）
  /// 返回：BIP32钱包实例（null表示失败）
  Future<BIP32?> get ethWallet async => await getWallet("m/44'/60'/0'/0/0");

  /// 根据BIP32路径派生钱包
  /// [path]：BIP32派生路径（如m/44'/60'/0'/0/0）
  /// 返回：BIP32钱包实例（null表示失败）
  Future<BIP32?> getWallet(String path) async {
    // 获取助记词
    String? words = await mnemonic;
    if (words == null) {
      Log.warning('mnemonic not found');
      return null;
    }
    
    // 助记词转换为种子（seed）
    Uint8List seed = mnemonicToSeed(words);
    // 从种子派生指定路径的钱包
    BIP32 wallet = BIP32.fromSeed(seed).derivePath(path);
    assert(wallet.privateKey != null, 'failed to derive private key: $words');
    Log.debug('get wallet: $path, $words');
    return wallet;
  }

  ///
  ///   私钥（Private Key）相关方法
  ///

  /// 获取比特币私钥
  /// 返回：DIM SDK的PrivateKey实例（null表示失败）
  Future<PrivateKey?> get btcKey async => getPrivateKey(await btcWallet);
  
  /// 获取以太坊私钥
  /// 返回：DIM SDK的PrivateKey实例（null表示失败）
  Future<PrivateKey?> get ethKey async => getPrivateKey(await ethWallet);

  /// 将BIP32钱包私钥转换为DIM SDK的PrivateKey对象
  /// [wallet]：BIP32钱包实例
  /// 返回：PrivateKey实例（null表示失败）
  static PrivateKey? getPrivateKey(BIP32? wallet) {
    Uint8List? privateKey = wallet?.privateKey;
    if (privateKey == null) {
      return null;
    }
    
    // 转换为DIM SDK的私钥格式（ECC算法，数据为16进制字符串）
    return PrivateKey.parse({
      'algorithm': AsymmetricAlgorithms.ECC,
      'data': Hex.encode(privateKey),
    });
  }

  ///
  ///   钱包地址（Wallet Address）相关方法
  ///

  /// 生成比特币地址
  /// 返回：BTC地址字符串（null表示失败）
  Future<String?> get btcAddress async {
    PrivateKey? privateKey = await btcKey;
    PublicKey? publicKey = privateKey?.publicKey;
    if (publicKey == null) {
      return null;
    }
    Uint8List data = publicKey.data;
    const int network = 0x00;  // 比特币主网标识（kBTCMain）
    // 生成BTC地址
    return BTCAddress.generate(data, network).toString();
  }

  /// 生成以太坊地址
  /// 返回：ETH地址字符串（null表示失败）
  Future<String?> get ethAddress async {
    PrivateKey? privateKey = await ethKey;
    PublicKey? publicKey = privateKey?.publicKey;
    if (publicKey == null) {
      return null;
    }
    Uint8List data = publicKey.data;
    // 生成ETH地址
    return ETHAddress.generate(data).toString();
  }

}