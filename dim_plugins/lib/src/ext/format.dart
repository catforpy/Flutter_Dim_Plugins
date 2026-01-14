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

/// 格式通用工厂
/// 核心作用：
/// 1. 实现数据格式相关接口，管理「可传输数据(TED)/可移植网络文件(PNF)」的创建/解析；
/// 2. 提供字符串格式解析（如dataURL）、自动解码等增强能力；
/// 3. 维护不同算法的TED工厂映射，PNF工厂全局唯一；
/// 接口说明：
/// - GeneralFormatHelper：通用格式辅助（提取算法类型）；
/// - PortableNetworkFileHelper：网络文件（PNF）的创建/解析；
/// - TransportableDataHelper：可传输数据（TED）的创建/解析；
class FormatGeneralFactory implements GeneralFormatHelper,
                                      PortableNetworkFileHelper,
                                      TransportableDataHelper {

  /// TED工厂映射：key=算法类型（如base64），value=对应工厂
  final Map<String, TransportableDataFactory> _tedFactories = {};
  /// PNF工厂实例（全局唯一）
  PortableNetworkFileFactory? _pnfFactory;

  /// 拆分文本字符串（适配dataURL格式）
  /// 补充说明：
  /// 支持解析以下格式：
  /// 1. 纯文本："{TEXT}" → ["{TEXT}"]；
  /// 2. 简单编码："base64,{BASE64}" → ["{BASE64}", "base64"]；
  /// 3. DataURL："data:image/png;base64,{BASE64}" → ["{BASE64}", "base64", "image/png"]；
  /// [text] - 待拆分的文本
  /// 返回值：拆分后的数组 [数据, 算法, 内容类型]
  List<String> split(String text) {
    // "{TEXT}", or
    // "base64,{BASE64_ENCODE}", or
    // "data:image/png;base64,{BASE64_ENCODE}"
    int pos1 = text.indexOf('://');
    if (pos1 > 0) {
      // 是URL，直接返回原文本
      return [text];
    } else {
      // 跳过 'data:' 前缀
      pos1 = text.indexOf(':') + 1;
    }
    List<String> array = [];
    // 查找内容类型（如image/png）
    int pos2 = text.indexOf(';', pos1);
    if (pos2 > pos1) {
      array.add(text.substring(pos1, pos2));
      pos1 = pos2 + 1;
    }
    // 查找算法（如base64）
    pos2 = text.indexOf(',', pos1);
    if (pos2 > pos1) {
      array.insert(0, text.substring(pos1, pos2));
      pos1 = pos2 + 1;
    }
    if (pos1 == 0) {
      // 纯文本，直接插入原文本
      array.insert(0, text);
    } else {
      // 带编码的内容，插入数据部分
      array.insert(0, text.substring(pos1));
    }
    return array;
  }

  /// 解码数据（适配多类型输入）
  /// 补充说明：
  /// 1. 支持Map/Mapper/String/其他类型输入；
  /// 2. JSON字符串自动解析为Map；
  /// 3. DataURL/编码字符串自动拆分为标准Map格式；
  /// [data] - 待解码的数据
  /// [defaultKey] - 纯文本时的默认key（如data/URL）
  /// 返回值：解码后的Map（失败返回null）
  Map? decode(Object data, {required String defaultKey}) {
    if (data is Mapper) {
      // Mapper类型，转为Map
      return data.toMap();
    } else if (data is Map) {
      // 已是Map，直接返回
      return data;
    }
    // 转为字符串
    String text = data is String ? data : data.toString();
    if (text.isEmpty) {
      return null;
    } else if (text.startsWith('{') && text.endsWith('}')) {
      // JSON字符串，解析为Map
      return JSONMap.decode(text);
    }
    // 拆分文本并封装为Map
    Map info = {};
    List<String> array = split(text);
    int size = array.length;
    if (size == 1) {
      // 纯文本，使用默认key
      info[defaultKey] = array[0];
    } else {
      assert(size > 1, 'split error: $text => $array');
      info['data'] = array[0];
      info['algorithm'] = array[1];
      if (size > 2) {
        // 带内容类型的DataURL
        info['content-type'] = array[2];
        if (text.startsWith('data:')) {
          info['URL'] = text;
        }
      }
    }
    return info;
  }

  /// 提取格式算法类型（从Map中）
  /// 补充说明：
  /// - TED/PNF的algorithm字段标识其编码算法（如base64）；
  /// - 若字段不存在，返回默认值；
  /// [ted] - 格式数据原始Map
  /// [defaultValue] - 字段不存在时的默认值
  /// 返回值：算法类型字符串
  @override
  String? getFormatAlgorithm(Map ted, [String? defaultValue]) {
    return Converter.getString(ted['algorithm'], defaultValue);
  }

  // ====================== TED 可传输数据相关方法 ======================

  /// 设置TED工厂（按算法映射）
  /// [algorithm] - 算法类型（如base64）
  /// [factory] - 对应算法的TransportableData工厂
  @override
  void setTransportableDataFactory(String algorithm, TransportableDataFactory factory) {
    _tedFactories[algorithm] = factory;
  }

  /// 获取TED工厂（按算法）
  /// [algorithm] - 算法类型
  /// 返回值：对应TransportableData工厂（未找到返回null）
  @override
  TransportableDataFactory? getTransportableDataFactory(String algorithm) {
    return _tedFactories[algorithm];
  }

  /// 创建TED（基于原始字节+算法）
  /// 补充说明：
  /// - TED是封装后的可传输数据，支持不同编码算法（如base64）；
  /// - 算法默认使用EncodeAlgorithms.DEFAULT（base64）；
  /// [data] - 原始字节数据
  /// [algorithm] - 编码算法（可选）
  /// 返回值：创建的TransportableData实例
  @override
  TransportableData createTransportableData(Uint8List data, String? algorithm) {
    algorithm ??= EncodeAlgorithms.DEFAULT;
    TransportableDataFactory? factory = getTransportableDataFactory(algorithm);
    assert(factory != null, 'TED algorithm not support: $algorithm');
    return factory!.createTransportableData(data);
  }

  /// 解析TED（支持多类型输入）
  /// 补充说明：
  /// 1. 先通过decode方法解码为标准Map；
  /// 2. 提取算法类型，用对应工厂解析；
  /// 3. 未知算法时使用默认工厂（key='*'）；
  /// [ted] - 待解析的TED（任意类型）
  /// 返回值：TransportableData实例（失败返回null）
  @override
  TransportableData? parseTransportableData(Object? ted) {
    if (ted == null) {
      return null;
    } else if (ted is TransportableData) {
      return ted;
    }
    // 解码为标准Map
    Map? info = decode(ted, defaultKey: 'data');
    if (info == null) {
      // assert(false, 'TED error: $ted');
      return null;
    }
    // 提取算法类型
    String? algo = getFormatAlgorithm(info);
    // assert(algo != null, 'TED error: $ted');
    // 获取对应工厂
    var factory = algo == null ? null : getTransportableDataFactory(algo);
    if (factory == null) {
      // 未知算法，使用默认工厂
      factory = getTransportableDataFactory('*');  // unknown
      assert(factory != null, 'default TED factory not found');
    }
    return factory?.parseTransportableData(info);
  }

  // ====================== PNF 可移植网络文件相关方法 ======================

  /// 设置PNF工厂实例
  @override
  void setPortableNetworkFileFactory(PortableNetworkFileFactory factory) {
    _pnfFactory = factory;
  }

  /// 获取PNF工厂实例
  @override
  PortableNetworkFileFactory? getPortableNetworkFileFactory() {
    return _pnfFactory;
  }

  /// 创建PNF（基于TED+文件名+URL+密码）
  /// 补充说明：
  /// - PNF是封装后的网络文件，支持加密（密码）、远程URL、本地数据；
  /// - 适用于传输图片、视频等多媒体文件；
  /// [data] - TED格式的文件数据（可选）
  /// [filename] - 文件名（可选）
  /// [url] - 远程URL（可选）
  /// [password] - 解密密码（可选）
  /// 返回值：创建的PortableNetworkFile实例
  @override
  PortableNetworkFile createPortableNetworkFile(TransportableData? data, String? filename,
      Uri? url, DecryptKey? password) {
    PortableNetworkFileFactory? factory = getPortableNetworkFileFactory();
    assert(factory != null, 'PNF factory not ready');
    return factory!.createPortableNetworkFile(data, filename, url, password);
  }

  /// 解析PNF（支持多类型输入）
  /// 补充说明：
  /// 1. 先通过decode方法解码为标准Map（默认key=URL）；
  /// 2. 用PNF工厂解析，全局唯一工厂；
  /// [pnf] - 待解析的PNF（任意类型）
  /// 返回值：PortableNetworkFile实例（失败返回null）
  @override
  PortableNetworkFile? parsePortableNetworkFile(Object? pnf) {
    if (pnf == null) {
      return null;
    } else if (pnf is PortableNetworkFile) {
      return pnf;
    }
    // 解码为标准Map
    Map? info = decode(pnf, defaultKey: 'URL');
    if (info == null) {
      // assert(false, 'PNF error: $pnf');
      return null;
    }
    PortableNetworkFileFactory? factory = getPortableNetworkFileFactory();
    assert(factory != null, 'PNF factory not ready');
    return factory?.parsePortableNetworkFile(info);
  }

}