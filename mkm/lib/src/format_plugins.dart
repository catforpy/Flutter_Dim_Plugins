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

import 'package:mkm/mkm.dart';

/// 格式通用辅助器接口
/// 补充说明：
/// 1. 整合可传输数据(TransportableData)、可移植网络文件(PortableNetworkFile)相关辅助能力；
/// 2. 提供格式算法类型的统一获取方法；
/// 3. 注：注释中被注释的接口实现表示该接口整合了这些辅助器的能力
abstract interface class GeneralFormatHelper {
  //
  //  Algorithm - 算法类型
  //

  /// 从可传输数据(TED)Map中获取格式算法类型
  /// 补充说明：
  /// - TED(TransportableData)是封装后的可传输数据（如加密数据、签名数据）；
  /// - PNF(PortableNetworkFile)是封装后的网络文件（如图片、视频）；
  /// - 该方法统一提取这类格式化数据的算法类型字段；
  /// [ted] - 格式化数据Map（TED/PNF等）
  /// [defaultValue] - 字段不存在/解析失败时返回的默认值
  String? getFormatAlgorithm(Map ted, [String? defaultValue]);
}

/// 格式扩展管理器（单例）
/// 补充说明：
/// 1. 采用单例模式，统一管理各类格式相关辅助器的实例；
/// 2. 内部通过FormatExtensions()转发读写操作，实现辅助器的全局共享；
/// 3. 同时维护一个通用格式辅助器(GeneralFormatHelper)实例，便于统一调用
class SharedFormatExtensions {
  /// 工厂构造函数（返回单例）
  factory SharedFormatExtensions() => _instance;

  /// 静态单例实例
  static final SharedFormatExtensions _instance =
      SharedFormatExtensions._internal();

  /// 私有构造函数（防止外部实例化）
  SharedFormatExtensions._internal();

  /// 可传输数据(TED)辅助器 - 读写
  /// 补充说明：封装TED数据的创建、解析、序列化/反序列化等能力
  TransportableDataHelper? get tedHelper => FormatExtensions().tedHelper;

  set tedHelper(TransportableDataHelper? helper) =>
      FormatExtensions().tedHelper = helper;

  /// 可移植网络文件(PNF)辅助器 - 读写
  /// 补充说明：封装PNF文件（如多媒体文件）的创建、解析、序列化/反序列化等能力
  PortableNetworkFileHelper? get pnfHelper => FormatExtensions().pnfHelper;

  set pnfHelper(PortableNetworkFileHelper? helper) =>
      FormatExtensions().pnfHelper = helper;

  /// 通用格式辅助器
  /// 补充说明：全局共享的GeneralFormatHelper实例，可统一处理各类格式相关通用操作
  GeneralFormatHelper? helper;
}
