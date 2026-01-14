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

import 'package:dimp/dimp.dart';
import 'package:dimp/dkd.dart';
import 'package:dimp/mkm.dart';
import 'package:dimp/msg.dart';

///  安全消息（加密）
///  ~~~~~~~~~~~~~~
///  作用：即时消息加密后的中间格式，包含加密内容+加密密钥，未签名
///  说明：是明文消息到可靠消息的过渡形态，仅用于本地加密处理
///
///  数据格式：{
///      //-- 信封
///      sender   : "moki@xxx",
///      receiver : "hulk@yyy",
///      time     : 123,
///      //-- 加密内容和密钥
///      data     : "...",  // base64(对称加密(明文内容))
///      key      : "...",  // base64(非对称加密(对称密钥))
///      keys     : {
///          "ID1": "key1", // 多接收者时的密钥列表
///      }
///  }
class EncryptedMessage extends BaseMessage implements SecureMessage {
  // 构造方法：从字典初始化（解析本地的安全消息）
  EncryptedMessage([super.dict]);

  /// 加密内容的二进制数据（缓存）
  Uint8List? _data;
  /// 加密后的对称密钥（缓存）
  TransportableData? _encKey;
  /// 多接收者的密钥列表（缓存）
  Map? _encKeys;  // String => String

  // 获取加密内容的二进制数据（懒加载+区分广播/单播）
  @override
  Uint8List get data {
    Uint8List? binary = _data;
    if (binary == null) {
      Object? text = this['data'];
      if (text == null) {
        assert(false, '安全消息加密内容为空: ${toMap()}');
      } else if (!BaseMessage.isBroadcast(this)) {
        // 单播消息：内容是对称加密后的base64字符串，需解码
        binary = TransportableData.decode(text);
      } else if (text is String) {
        // 广播消息：内容不加密，仅JSON序列化，直接转二进制
        binary = UTF8.encode(text);  // JSON字符串转二进制
      } else {
        assert(false, '加密内容格式错误: $text');
      }
      _data = binary;
    }
    return binary!;
  }

  // 获取加密后的对称密钥（优先单密钥，兼容多密钥）
  @override
  Uint8List? get encryptedKey {
    TransportableData? ted = _encKey;
    if (ted == null) {
      var base64 = this['key'];
      if (base64 == null) {
        // 单密钥不存在时，从多密钥列表中找接收者对应的密钥
        Map? keys = encryptedKeys;
        if (keys != null) {
          base64 = keys[receiver.toString()];
        }
      }
      _encKey = ted = TransportableData.parse(base64);
    }
    return ted?.data;
  }

  // 获取多接收者的密钥列表（懒加载）
  @override
  Map? get encryptedKeys {
    if (_encKeys == null) {
      var keys = this['keys'];
      if (keys is Map) {
        _encKeys = keys;
      } else {
        assert(keys == null, '多接收者密钥列表格式错误: $keys');
      }
    }
    return _encKeys;
  }
}