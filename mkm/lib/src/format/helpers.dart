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
 * 核心功能：提供TED/PNF的工厂管理接口，实现算法/格式与实现的解耦
 * 设计模式：单例模式 + 工厂模式，统一管理所有格式工厂
 */

import 'dart:typed_data';

import 'package:mkm/protocol.dart';

/// 【TED助手接口】
/// 管理TED工厂的注册、创建、解析
abstract interface class TransportableDataHelper{
  /// 注册制定算法的TED工厂
  void setTransportableDataFactory(String algorithm,TransportableDataFactory factory);

  /// 获取制定算法的TED工厂
  TransportableDataFactory? getTransportableDataFactory(String algorithm);

  /// 创建TED对象
  TransportableData createTransportableData(Uint8List data, String? algorithm);

  /// 解析任意对象为TED对象
  TransportableData? parseTransportableData(Object? ted);
}

/// 【PNF助手接口】
/// 管理PNF工厂的注册、创建、解析
abstract interface class PortableNetworkFileHelper{
  /// 注册PNF工厂
  void setPortableNetworkFileFactory(PortableNetworkFileFactory factory);

  /// 获取PNF工厂
  PortableNetworkFileFactory? getPortableNetworkFileFactory();

  /// 创建PNF对象
  PortableNetworkFile createPortableNetworkFile(TransportableData? data, String? filename,
                                                Uri? url, DecryptKey? password);

  /// 解析任意对象为PNF对象
  PortableNetworkFile? parsePortableNetworkFile(Object? pnf);
}

/// 【格式扩展管理器】
/// 单例类，统一管理TED/PNF助手实例，是格式工厂注册的核心入口
// protected：仅内部使用
class FormatExtensions {
  /// 工厂构造方法：返回单例实例
  factory FormatExtensions() => _instance;
  
  /// 静态单例实例
  static final FormatExtensions _instance = FormatExtensions._internal();
  
  /// 私有构造方法：防止外部实例化
  FormatExtensions._internal();

  /// TED助手实例（由外部注入具体实现）
  TransportableDataHelper? tedHelper;
  
  /// PNF助手实例（由外部注入具体实现）
  PortableNetworkFileHelper? pnfHelper;
}