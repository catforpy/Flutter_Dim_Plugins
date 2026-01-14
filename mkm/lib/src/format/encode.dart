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

/* 
 * 核心功能：定义“可传输编码数据”（TED）接口，统一二进制数据的网络传输格式
 * 设计目标：解决不同编码格式（Base64/Base58/Hex）的统一解析/生成问题
 * MKM框架：Ming-Ke-Ming 去中心化身份认证框架的核心数据传输规范
 */

import 'dart:typed_data';

import 'package:mkm/mkm.dart';
import 'package:mkm/type.dart';

/// 【核心接口】可传输编码数据（TED）
/// 定义二进制数据的标准化传输格式，支持4种常见形式：
///  0. 纯Base64字符串："{BASE64_ENCODE}"
///  1. 带算法标识的字符串："base64,{BASE64_ENCODE}"
///  2. 带媒体类型的字符串："data:image/png;base64,{BASE64_ENCODE}"
///  3. 结构化Map：{ algorithm:"base64", data:"...", ... }
abstract interface class TransportableData implements Mapper{
  /// 预定义编码算法常量（注释示例，实际由实现类定义）
  // static const DEFAULT = 'base64';
  // static const BASE_64 = 'base64';
  // static const BASE_58 = 'base58';
  // static const HEX     = 'hex';

  /// 获取编码算法名称(如"base64"/"base58"/"hex")
  String? get algorithm;

  /// 获取编码数据
  Uint8List? get data;

  /// 转换为字符串表示(适配不同传输场景)
  @override
  String toString();

  /// 转换为可序列化对象(String/Map),用于JSON传输
  Object toObject();

  // -------------------------- 便捷方法 --------------------------
  /// 快速编码：二进制数据转TED对象，再转可传输对象（String/Map）
  static Object encode(Uint8List data){
    TransportableData ted = create(data);
    return ted.toObject();
  }

  /// 快速解码：可传输对象（String/Map）转TED对象，再转二进制数据
  static Uint8List? decode(Object encoded){
    TransportableData? ted = parse(encoded);
    return ted?.data;
  }

  // -------------------------- 工厂方法 --------------------------
  /// 创建TED对象
  /// [data]：原始二进制数据
  /// [algorithm]：编码算法（默认base64）
  static TransportableData create(Uint8List data,{String? algorithm}){
    var ext = FormatExtensions();   //获取格式扩展单例
    return ext.tedHelper!.createTransportableData(data,algorithm);
  }

  /// 解析任意对象为TED对象（支持String/Map）
  static TransportableData? parse(Object? ted){
    var ext = FormatExtensions();
    return ext.tedHelper!.parseTransportableData(ted);
  }

  /// 获取指定算法的TED工厂
  static TransportableDataFactory? getFactory(String algorithm){
    var ext = FormatExtensions();
    return ext.tedHelper!.getTransportableDataFactory(algorithm);
  }

  /// 注册指定算法的TED工厂
  static void setFactory(String algorithm, TransportableDataFactory factory){
    var ext = FormatExtensions();
    ext.tedHelper!.setTransportableDataFactory(algorithm, factory);
  }
}

/// 【TED工厂接口】
/// 定义TED对象的创建/解析规范，不同编码算法需实现此接口
abstract interface class TransportableDataFactory {
  /// 创建TED对象
  TransportableData createTransportableData(Uint8List data);

  /// 解析Map对象为TED对象
  TransportableData? parseTransportableData(Map ted);
}