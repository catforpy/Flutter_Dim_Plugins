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

// 忽略“常量标识符应使用大写”的lint警告
// ignore_for_file: constant_identifier_names


/// 非对称密钥算法常量
/// 作用：定义DIMP协议支持的非对称加密/签名算法，是加密模块的“算法标识”
abstract interface class AsymmetricAlgorithms{
  /// RSA算法（默认参数："RSA/ECB/PKCS1Padding" 加密，"SHA256withRSA" 签名）
  static const RSA = 'RSA';
  /// 椭圆曲线加密算法
  static const ECC = 'ECC';
}

/// 对称密钥算法常量
/// 作用：定义DIMP协议支持的对称加密算法，用于消息内容的加密
abstract interface class SymmetricAlgorithms{
  /// AES算法（默认参数："AES/CBC/PKCS7Padding"）
  static const AES = 'AES';
  /// DES算法
  static const DES = 'DES';

  /// 广播消息专用的“明文算法”
  /// 说明：广播消息无需加密，此算法标识用于跳过加解密逻辑
  static const PLAIN = 'PLAIN';
}

/// 数据编码算法常量
/// 作用：定义DIMP协议支持的二进制数据编码方式，用于秘钥/签名/加密内容的序列化
abstract interface class EncodeAlgorithms{
  /// 默认编码方式（base64）
  static const DEFAULT = 'base64';

  /// Base64编码（最常用）
  static const BASE_64 = 'base64';
  /// Base58编码（区块链常用，无特殊字符）
  static const BASE_58 = 'base58';
  /// 十六进制编码
  static const HEX     = 'hex';
}