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

import 'package:dim_plugins/dim_plugins.dart';

/// Base64可传输数据实现类
/// 核心作用：
/// 1. 实现TransportableData接口，封装Base64编码的可传输数据；
/// 2. 基于Dictionary实现，支持Map序列化/反序列化；
/// 3. 支持多种字符串格式输出（纯Base64、带算法、DataURL）；
/// 核心属性：
/// - algorithm：编码算法（固定为BASE_64）；
/// - data：原始字节数据；
class Base64Data extends Dictionary implements TransportableData{
  /// 构造方法1：从现有Map初始化
  /// [dict] - 包含TED属性的Map
  Base64Data([super.dict]);

  /// 数据包装器（封装属性读写逻辑）
  late final BaseDataWrapper _wrapper = BaseDataWrapper(toMap());

  /// 构造方法2：从原始字节数据初始化
  /// [binary] - 原始字节数据
  Base64Data.fromData(Uint8List binary) {
    // 设置编码算法为BASE_64
    _wrapper.algorithm = EncodeAlgorithms.BASE_64;
    // 设置原始字节数据（自动Base64编码）
    if (binary.isNotEmpty) {
      _wrapper.data = binary;
    }
  }
  
  // ====================== 编码算法（algorithm）属性 ======================

  /// 获取编码算法（固定返回BASE_64）
  @override
  String? get algorithm => _wrapper.algorithm;

  // ====================== 原始数据（data）属性 ======================

  /// 获取原始字节数据（Base64解码后）
  @override
  Uint8List? get data => _wrapper.data;

  // ====================== 序列化方法 ======================

  /// 转为对象（返回字符串）
  @override
  Object toObject() => toString();

  /// 转为字符串（支持两种格式）
  /// 补充说明：
  /// 1. 格式0：纯Base64字符串（"{BASE64_ENCODE}"）；
  /// 2. 格式1：带算法标识（"base64,{BASE64_ENCODE}"）；
  @override
  String toString() => _wrapper.toString();

  /// 编码为DataURL格式
  /// 补充说明：格式2："data:{mimeType};base64,{BASE64_ENCODE}"；
  /// [mimeType] - 内容类型（如image/png、text/plain）
  /// 返回值：DataURL格式字符串
  String encode(String mimeType) => _wrapper.encode(mimeType);
}

/// Base64可传输数据工厂类
/// 核心作用：
/// 1. 实现TransportableDataFactory接口，提供Base64-TED的创建/解析能力；
/// 2. 封装Base64Data的实例化逻辑，统一创建入口；
class Base64DataFactory implements TransportableDataFactory {

  /// 创建Base64可传输数据（从原始字节）
  /// [data] - 原始字节数据
  /// 返回值：Base64Data实例
  @override
  TransportableData createTransportableData(Uint8List data) {
    return Base64Data.fromData(data);
  }

  /// 解析Base64可传输数据（从Map）
  /// 补充说明：
  /// 1. 校验核心字段（data不能为空）；
  /// 2. 待优化：增加算法/数据格式校验；
  /// [ted] - 包含TED属性的Map
  /// 返回值：Base64Data实例（失败返回null）
  @override
  TransportableData? parseTransportableData(Map ted) {
    // 校验核心字段：data不能为空
    if (ted['data'] == null) {
      assert(false, 'TED error: $ted');
      return null;
    }
    // TODO: 1. 校验算法是否为BASE_64
    //       2. 校验data字段是否为合法Base64字符串
    return Base64Data(ted);
  }

}