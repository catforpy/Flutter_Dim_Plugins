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

import 'package:dimp/dkd.dart';
import 'package:dimp/mkm.dart';
import 'package:dimp/msg.dart';

///  可靠消息（加密+签名）
///  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
///  作用：网络传输的最终消息格式，在安全消息基础上增加发送者签名，防篡改+防冒充
///  说明：这是实际在网络中传输的消息，接收方需先验签再解密
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
///      },
///      //-- 数字签名（防篡改/冒充）
///      signature: "..."   // base64(发送者私钥签名(加密内容))
///  }
class NetworkMessage extends EncryptedMessage implements ReliableMessage{
  // 构造方法：从字典初始化（解析网络接收的可靠消息）
  NetworkMessage([super.dict]);

  /// 数字签名（缓存，避免重复解析）
  TransportableData? _signature;

  // 获取数字签名的二进制数据（懒加载+非空校验）
  @override
  Uint8List get signature {
    TransportableData? ted = _signature;
    if (ted == null) {
      Object? base64 = this['signature'];
      assert(base64 != null, '可靠消息签名不能为空: $this');
      _signature = ted = TransportableData.parse(base64);
      assert(ted != null, '消息签名解析失败: $base64');
    }
    return ted!.data!;
  }
}