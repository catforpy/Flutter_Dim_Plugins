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

import 'dart:convert';
import 'dart:typed_data';

import 'package:dim_plugins/dim_plugins.dart';
import 'package:fast_base58/fast_base58.dart';

/// UTF-8 编解码器
/// 核心作用：
/// 1. 实现StringCoder接口，提供字符串 ↔ 字节数组的UTF-8编解码能力；
/// 2. 封装Dart内置utf8工具，统一编解码接口；
/// 适用场景：文本数据的标准化编解码（如消息内容、文档数据）；
class UTF8Coder implements StringCoder {
  
  /// 编码：字符串 → UTF-8字节数组
  /// [string] - 待编码的字符串
  /// 返回值：UTF-8编码后的字节数组
  @override
  Uint8List encode(String string) {
    var array = utf8.encode(string);  // 调用Dart内置UTF8编码
    return Uint8List.fromList(array); // 转为Uint8List（标准化字节类型）
  }

  /// 解码：UTF-8字节数组 → 字符串
  /// 补充说明：解码失败时返回null（捕获FormatException异常）；
  /// [data] - 待解码的UTF-8字节数组
  /// 返回值：解码后的字符串（失败返回null）
  @override
  String? decode(Uint8List data){
    try{
      return utf8.decode(data);   // 调用Dart内置UTF8编码
    }on FormatException{
      return null;      // 解码失败（如非UTF8格式）返回Null
    }
  }
}

/// JSON 编解码器
/// 核心作用：
/// 1. 实现ObjectCoder接口，提供任意对象 ↔ JSON字符串的编解码能力；
/// 2. 封装Dart内置json工具，统一编解码接口；
/// 适用场景：结构化数据的序列化/反序列化（如消息、元数据、文档）；
class JSONCoder implements ObjectCoder<dynamic> {

  /// 编码：任意对象 → JSON字符串
  /// [object] - 待编码的对象（支持Map/List/基础类型）
  /// 返回值：JSON格式字符串
  @override
  String encode(dynamic object) {
    return json.encode(object);  // 调用Dart内置JSON编码
  }

  /// 解码：JSON字符串 → 动态对象
  /// [string] - 待解码的JSON字符串
  /// 返回值：解析后的动态对象（Map/List/基础类型）
  @override
  dynamic decode(String string) {
    return json.decode(string);  // 调用Dart内置JSON解码
  }
}

/// Hex（十六进制）编解码器
/// 核心作用：
/// 1. 实现DataCoder接口，提供字节数组 ↔ 十六进制字符串的编解码能力；
/// 2. 支持奇数长度字符串的兼容处理，保证解码鲁棒性；
/// 适用场景：二进制数据的可读化展示（如密钥、哈希值、指纹）；
class HexCoder implements DataCoder {

  /// 编码：字节数组 → 十六进制字符串
  /// 补充说明：
  /// - 每个字节转为2位十六进制字符（不足补0）；
  /// - 结果为小写字符串（如0x12 → "12"，0x05 → "05"）；
  /// [data] - 待编码的字节数组
  /// 返回值：十六进制字符串
  @override
  String encode(Uint8List data){
    StringBuffer sb = StringBuffer();     // 字符串缓冲区（高效拼接）
    int item;
    for(int i = 0;i < data.lengthInBytes; ++i){
      item = data[i];
      if(item < 16){
        sb.write('0');    //不足16（0x00-0x0F）补前导0
      }
      sb.write(item.toRadixString(16));   //转为十六进制字符串
    }
    return sb.toString();
  }

  /// 解码：十六进制字符串 → 字节数组
  /// 补充说明：
  /// 1. 支持奇数长度字符串（如"123" → [0x01, 0x23]）；
  /// 2. 解析失败时返回null（如包含非十六进制字符）；
  /// [string] - 待解码的十六进制字符串
  /// 返回值：解码后的字节数组（失败返回null）
  @override
  Uint8List? decode(String string){
    Uint8List data;
    String item;
    int offset;
    //判断字符串长度是否为奇数
    bool odd = string.length & 1 == 1;
    if(odd){
      // 奇数长度：数组长度 = 长度//2 + 1
      data = Uint8List((string.length ~/ 2) + 1);
      // 处理第一个字符（单独1位）
      item = string.substring(0, 1);
      data.add(int.parse(item, radix: 16));
      offset = 1;  // 偏移量从1开始
    }else{
      // 偶数长度：数组长度 = 长度//2
      data = Uint8List(string.length ~/ 2);
      offset = 0;  // 偏移量从0开始
    }
    int? value;
    // 遍历剩余字符（每次取2位）
    for(int i = offset; i < string.length;i += 2, offset += 1){
      item = string.substring(i,i + 2);
      value = int.tryParse(item,radix: 16);   //尝试解析十六进制
      if(value == null){
        return null;    //解析失败（非十六进制字符）返回null
      }
      data[offset] = value;
    }
    return data;
  }
}

/// Base-58 编解码器
/// 核心作用：
/// 1. 实现DataCoder接口，提供字节数组 ↔ Base58字符串的编解码能力；
/// 2. 封装fast_base58库，适配DIMP协议的Base58编码规范；
/// 适用场景：短字符串编码（如地址、密钥的简洁表示，避免0/O、l/I等易混淆字符）；
class Base58Coder implements DataCoder {

  /// 编码：字节数组 → Base58字符串
  /// [data] - 待编码的字节数组
  /// 返回值：Base58编码后的字符串
  @override
  String encode(Uint8List data) {
    return Base58Encode(data);  // 调用fast_base58库编码
  }

  /// 解码：Base58字符串 → 字节数组
  /// [string] - 待解码的Base58字符串
  /// 返回值：解码后的字节数组
  @override
  Uint8List? decode(String string) {
    return Uint8List.fromList(Base58Decode(string));  // 调用fast_base58库解码
  }
}

/// Base-64 编解码器
/// 核心作用：
/// 1. 实现DataCoder接口，提供字节数组 ↔ Base64字符串的编解码能力；
/// 2. 封装Dart内置base64工具，统一编解码接口；
/// 适用场景：二进制数据的网络传输（如文件、加密数据、可传输数据TED）；
class Base64Coder implements DataCoder {

  /// 编码：字节数组 → Base64字符串
  /// [data] - 待编码的字节数组
  /// 返回值：Base64编码后的字符串
  @override
  String encode(Uint8List data) {
    return base64.encode(data);  // 调用Dart内置Base64编码
  }

  /// 解码：Base64字符串 → 字节数组
  /// [string] - 待解码的Base64字符串
  /// 返回值：解码后的字节数组
  @override
  Uint8List? decode(String string) {
    return base64.decode(string);  // 调用Dart内置Base64解码
  }
}

