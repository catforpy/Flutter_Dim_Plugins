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

/// 基础网络文件实现类
/// 核心作用：
/// 1. 实现PortableNetworkFile接口，封装可移植网络文件的核心属性；
/// 2. 基于Dictionary（字典）实现，支持Map序列化/反序列化；
/// 3. 通过Wrapper封装属性操作，简化逻辑并保证数据一致性；
/// 核心属性：
/// - data：文件原始字节数据；
/// - filename：文件名；
/// - url：远程下载地址；
/// - password：解密密钥（加密文件）；
class BaseNetworkFile extends Dictionary implements PortableNetworkFile {
  /// 构造方法1：从现有Map初始化
  /// [dict] - 包含文件属性的Map
  BaseNetworkFile([super.dict]) {
    // 创建文件包装器，关联当前字典数据
    _wrapper = BaseFileWrapper(toMap());
  }

  /// 文件属性包装器（封装属性读写逻辑）
  late final BaseFileWrapper _wrapper;

  /// 构造方法2：从原始属性初始化
  /// [data] - 可传输数据（TED）格式的文件数据
  /// [filename] - 文件名
  /// [url] - 远程URL
  /// [password] - 解密密钥
  BaseNetworkFile.from(TransportableData? data,String? filename,
      Uri? url,DecryptKey? password){
    _wrapper = BaseFileWrapper(toMap());
    // 设置文件数据
    if(data != null){
      _wrapper.data = data;
    }  
    // 设置文件名
    if(filename != null){
      _wrapper.filename = filename;
    }    
    // 设置远程URL
    if(url != null){
      _wrapper.url = url;
    }
    // 设置解密密钥
    if(password != null){
      _wrapper.password = password;
    }
  }

  // ====================== 文件数据（data）属性 ======================

  /// 获取文件原始字节数据
  /// 补充说明：从包装器的TED数据中提取原始字节；
  @override
  Uint8List? get data => _wrapper.data?.data;

  /// 设置文件原始字节数据
  /// 补充说明：自动封装为TED格式（默认Base64）；
  @override
  set data(Uint8List? binary) => _wrapper.setDate(binary);

  // ====================== 文件名（filename）属性 ======================

  /// 获取文件名
  @override
  String? get filename => _wrapper.filename;

  /// 设置文件名
  @override
  set filename(String? name) => _wrapper.filename = name;

  // ====================== 远程URL（url）属性 ======================

  /// 获取远程下载地址
  @override
  Uri? get url => _wrapper.url;

  /// 设置远程下载地址
  @override
  set url(Uri? remote) => _wrapper.url = remote;

  // ====================== 解密密钥（password）属性 ======================

  /// 获取解密密钥
  @override
  DecryptKey? get password => _wrapper.password;

  /// 设置解密密钥
  @override
  set password(DecryptKey? key) => _wrapper.password = key;

  // ====================== 序列化方法 ======================

  /// 转为字符串（优化展示）
  /// 补充说明：
  /// 1. 仅包含URL时，直接返回URL字符串；
  /// 2. 包含其他属性时，返回JSON字符串；
  @override
  String toString(){
    String? urlString = _getURLString();
    if(urlString != null){
      // 仅包含URL，直接返回URL
      return urlString;
    }
    // 包含其他属性，返回JSON字符串
    return JSONMap.encode(toMap());
  }

  /// 转为对象（优化序列化）
  /// 补充说明：
  /// 1. 仅包含URL时，返回URL字符串；
  /// 2. 包含其他属性时，返回原始Map；
  @override
  Object toObject() {
    String? urlString = _getURLString();
    if (urlString != null) {
      // 仅包含URL，返回字符串
      return urlString;
    }
    // 包含其他属性，返回Map
    return toMap();
  }

  /// 内部方法：判断是否仅包含URL属性
  /// 补充说明：
  /// 1. 包含dataURL（data:...）直接返回；
  /// 2. 仅包含URL字段 或 URL+filename字段，返回URL；
  /// 3. 其他情况返回null；
  String? _getURLString() {
    String? urlString = getString(r'URL');
    if(urlString == null){
      return null;
    }else if(urlString.startsWith(r'data:')){
      // dataURL格式（如data:image/png;base64,...）直接返回
      return urlString;
    }
    int count = length;
    if(count == 1){
      // 仅包含URL字段，返回URL
      return urlString;
    }else if (count == 2 && containsKey(r'filename')) {
      // 包含URL+filename字段，忽略filename返回URL
      return urlString;
    } else {
      // 包含其他字段，返回null
      return null;
    }
  }
}

/// 基础网络文件工厂类
/// 核心作用：
/// 1. 实现PortableNetworkFileFactory接口，提供PNF的创建/解析能力；
/// 2. 封装BaseNetworkFile的实例化逻辑，统一创建入口；
class BaseNetworkFileFactory implements PortableNetworkFileFactory {

  /// 创建网络文件（从原始属性）
  /// [data] - 可传输数据（TED）
  /// [filename] - 文件名
  /// [url] - 远程URL
  /// [password] - 解密密钥
  /// 返回值：BaseNetworkFile实例
  @override
  PortableNetworkFile createPortableNetworkFile(TransportableData? data, String? filename,
                                                Uri? url, DecryptKey? password) {
    return BaseNetworkFile.from(data, filename, url, password);
  }

  /// 解析网络文件（从Map）
  /// 补充说明：
  /// 1. 校验核心字段（data/URL/filename至少一个非空）；
  /// 2. 校验失败时触发断言并返回null；
  /// [pnf] - 包含文件属性的Map
  /// 返回值：BaseNetworkFile实例（失败返回null）
  @override
  PortableNetworkFile? parsePortableNetworkFile(Map pnf) {
    // 校验核心字段：data/URL/filename不能同时为空
    if (pnf['data'] == null && pnf['URL'] == null && pnf['filename'] == null) {
      assert(false, 'PNF error: $pnf');
      return null;
    }
    return BaseNetworkFile(pnf);
  }
}