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


import 'dart:math';
import 'dart:typed_data';

import 'package:dim_plugins/dim_plugins.dart';
import 'package:encrypt/encrypt.dart';

/// AES密钥类，继承自DIMP协议的基础对称密钥类
/// keyInfo数据格式：
/// {
///     algorithm: "AES",  // 算法标识
///     keySize  : 32,     // 密钥长度（可选，默认32字节）
///     data     : "{BASE64_ENCODE}}" // Base64编码的密钥数据
/// }
class AESKey extends BaseSymmetricKey {
  // 构造方法：初始化AES密钥
  // 核心逻辑：如果传入的dict没有data字段，自动生成新密钥；有则懒加载
  AESKey([super.dict]) {
    // 检查密钥数据是否存在
    if (containsKey('data')) {
      // 有data字段，懒加载（用到时再解析）
      _keyData = null;
    } else {
      // 无data字段，生成新的随机密钥
      _keyData = generateKeyData();
    }
  }

  // AES加密模式+填充方式常量（CBC+PKCS7）
  static const String AES_CBC_PKCS7 = "AES/CBC/PKCS7Padding";

  // 缓存解析后的密钥数据（懒加载用）
  TransportableData? _keyData;

  // 【密钥生成核心方法】生成随机AES密钥数据（protected，内部调用）
  TransportableData generateKeyData() {
    // 1. 获取密钥长度（默认32字节）
    int keySize = getKeySize();
    // 2. 生成指定长度的随机字节（核心：随机密钥生成）
    var pwd = _randomData(keySize);
    // 3. 封装为TransportableData（DIMP协议的可传输数据类型，自带Base64编码）
    var ted = TransportableData.create(pwd);

    // 4. 把生成的密钥数据存入当前对象的data字段（Base64格式）
    this['data'] = ted.toObject();

    return ted;
  }

  // 获取密钥长度（优先从dict取，默认32字节）
  int getKeySize() {
    return getInt('keySize') ?? 32;
  }

  // 获取AES块大小（IV长度，默认16字节）
  int getBlockSize() {
    return getInt('blockSize') ?? 16;
  }

  // 重写父类方法：获取原始密钥字节数据（核心属性）
  @override
  Uint8List get data {
    var ted = _keyData;
    if (ted == null) {
      // 懒加载：从data字段取出Base64字符串
      var base64 = this['data'];
      assert(base64 != null, '密钥数据不存在: $this');
      // 解析Base64为TransportableData
      ted = _keyData = TransportableData.parse(base64);
      assert(ted != null, '密钥数据解析失败: $base64');
    }
    // 返回原始字节数据
    return ted!.data!;
  }

  // 转换为encrypt库需要的Key对象（内部用）
  Key getCipherKey() => Key(data);

  /// 从参数中解析IV（初始化向量）
  /// 兼容IV/iv大小写，以及老版本存储在密钥对象中的情况
  IV? getInitVector(Map? params) {
    String? base64;
    if (params == null) {
      assert(false, '解析AES IV必须传入参数');
    } else {
      // 优先从params取IV/iv
      base64 = params['IV'];
      base64 ??= params['iv'];
    }
    if (base64 == null) {
      // 兼容老版本：从密钥对象本身取IV/iv
      base64 = getString('iv');
      base64 ??= getString('IV');
    }
    // 解析IV的Base64数据
    var ted = TransportableData.parse(base64);
    Uint8List? ivData = ted?.data;
    if (ivData == null || ivData.isEmpty) {
      assert(base64 == null, 'IV数据解析失败: $base64');
      return null;
    }
    return IV(ivData);
  }

  // 生成全0的IV（解密时如果没传IV用）
  IV zeroInitVector() {
    int blockSize = getBlockSize();
    Uint8List ivData = Uint8List(blockSize); // 全0字节
    return IV(ivData);
  }

  // 生成随机IV，并存入extra参数（加密时用）
  IV newInitVector(Map? extra) {
    // 1. 生成16字节随机IV
    int blockSize = getBlockSize();
    Uint8List ivData = _randomData(blockSize);
    // 2. 存入extra参数（供解密方读取）
    if (extra == null) {
      assert(false, '生成AES IV必须传入extra参数存储');
    } else {
      var ted = TransportableData.create(ivData);
      extra['IV'] = ted.toObject(); // Base64编码后存储
    }
    return IV(ivData);
  }

  // 重写父类方法：加密数据
  @override
  Uint8List encrypt(Uint8List plaintext, [Map? extra]) {
    // 1. 获取/生成IV
    IV? iv = getInitVector(extra);
    iv ??= newInitVector(extra); // 没有则生成随机IV
    // 2. 获取加密密钥
    Key key = getCipherKey();
    // 3. CBC模式加密
    Encrypter cipher = Encrypter(AES(key, mode: AESMode.cbc));
    return cipher.encryptBytes(plaintext, iv: iv).bytes;
  }

  // 重写父类方法：解密数据
  @override
  Uint8List? decrypt(Uint8List ciphertext, [Map? params]) {
    // 1. 获取IV（没有则用全0IV）
    IV? iv = getInitVector(params);
    iv ??= zeroInitVector();
    // 2. 获取解密密钥
    Key key = getCipherKey();
    // 3. 解密（捕获异常，避免崩溃）
    try {
      Encrypter cipher = Encrypter(AES(key, mode: AESMode.cbc));
      List<int> result = cipher.decryptBytes(Encrypted(ciphertext), iv: iv);
      return Uint8List.fromList(result);
    } catch (e, st) {
      print('AES解密失败: $e, IV=${params?["IV"]}');
      print('AES解密失败堆栈: $st');
      return null;
    }
  }

}

// 生成指定长度的随机字节（密钥/IV生成的核心工具方法）
Uint8List _randomData(int size) {
  Uint8List data = Uint8List(size);
  Random r = Random(); // 随机数生成器
  for (int i = 0; i < size; ++i) {
    data[i] = r.nextInt(256); // 0-255随机字节
  }
  return data;
}

/// AES密钥工厂类（实现DIMP的SymmetricKeyFactory接口）
/// 作用：统一生成/解析AES密钥
class AESKeyFactory implements SymmetricKeyFactory {

  // 【工厂方法：生成新AES密钥】对外暴露的密钥生成入口
  @override
  SymmetricKey generateSymmetricKey() {
    // 构造空的密钥dict（仅指定算法），AESKey构造方法会自动生成密钥
    Map key = {'algorithm': SymmetricAlgorithms.AES};
    return AESKey(key);
  }

  // 解析已有的AES密钥（从dict恢复）
  @override
  SymmetricKey? parseSymmetricKey(Map key) {
    // 校验data字段必须存在
    if (key['data'] == null) {
      assert(false, 'AES密钥数据错误: $key');
      return null;
    }
    return AESKey(key);
  }

}

/* 
 * 【AES密钥生成逻辑核心位置总结】
 * 1. 自动生成：AESKey构造方法 → 调用generateKeyData() → 调用_randomData(32)生成32字节随机密钥
 * 2. 工厂生成：AESKeyFactory.generateSymmetricKey() → 新建AESKey对象 → 触发自动生成
 * 3. 随机数来源：_randomData()方法（Random()生成0-255字节）
 */