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

///  Object Coder
///  ~~~~~~~~~~~~
///  JsON, XML, ...
///
///  1. encode object to string;
///  2. decode string to object.
/* 
 * 核心功能：封装JSON序列化/反序列化接口，支持Map/List与字符串的互转
 * 应用场景：网络接口数据传输（请求/响应体）、本地数据存储
 */

/// 【抽象接口】对象编码器
/// 定义任意类型对象<->字符串的序列化接口
abstract interface class ObjectCoder<T> {
  /// 编码：对象转字符串（如Map转JSON字符串）
  String encode(T object);

  /// 解码：字符串转对象（如JSON字符串转Map）
  T? decode(String string);
}

/// 【JSON编码封装】
/// 通用JSON序列化/反序列化，支持任意Map/List对象
class JSON {
  /// 静态方法：对象（Map/List）转JSON字符串
  static String encode(Object container){
    return coder!.encode(container);  // 委托给外部注入的实现类
  }

  /// 静态方法：JSON字符串转对象（Map/List）
  static dynamic decode(String json) {
    return coder!.decode(json);
  }

  /// JSON编码器的具体实现器（由外部插件注入，如dart:convert的jsonEncode/jsonDecode）
  static ObjectCoder<dynamic>? coder;
}

/// 【Map专用JSON编码器】
/// 专注于Map<->JSON字符串的互转，类型更精准
class MapCoder implements ObjectCoder<Map> {
  @override
  String encode(Map object){
    return JSON.encode(object);   // 复用JSON编码逻辑
  }

  @override
  Map? decode(String string) {
    return JSON.decode(string); // 复用通用JSON解码逻辑
  }
}

/// 【JSONMap工具类】
/// 提供Map专用的静态编码/解码方法，简化调用
class JSONMap {
  /// Map转JSON字符串
  static String encode(Map container) {
    return coder.encode(container);
  }

  /// JSON字符串转Map
  static Map? decode(String json) {
    return coder.decode(json);
  }

  /// 默认使用MapCoder作为实现
  static ObjectCoder<Map> coder = MapCoder();
}