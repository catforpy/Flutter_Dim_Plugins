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
 * 核心功能：定义“可传输网络文件”（PNF）接口，统一文件的传输/存储格式
 * 应用场景：IM中的图片/文件传输、用户头像上传、附件发送等
 * 核心设计：支持本地数据/远程URL/加密传输三种模式
 */

import 'dart:typed_data';

import 'package:mkm/mkm.dart';
import 'package:mkm/type.dart';

/// 【核心接口】可传输网络文件（PNF）
/// 定义文件的标准化传输格式，支持4种形式：
///  0. 纯URL字符串："{URL}"
///  1. 纯Base64字符串："base64,{BASE64_ENCODE}"
///  2. 带媒体类型的Base64："data:image/png;base64,{BASE64_ENCODE}"
///  3. 结构化Map：{ data:"...", filename:"avatar.png", URL:"http://...", key:{...} }
abstract interface class PortableNetworkFile implements Mapper {
  /// 文件原始二进制数据（大文件建议用URL，不直接存此属性）
  Uint8List? get data;
  set data(Uint8List? fileData);

  /// 文件名（如"avatar.png"）
  String? get filename;
  set filename(String? name);

  /// 文件下载URL（大文件上传到CDN后，存此URL）
  Uri? get url;
  set url(Uri? location);

  /// 文件解密密钥（CDN上的文件若加密，需此密钥解密）
  DecryptKey? get password;
  set password(DecryptKey? key);

  /// 转换为字符串表示（适配不同传输场景）
  @override
  String toString();

  /// 转换为可序列化对象（String/Map），用于JSON传输
  Object toObject();

  // -------------------------- 便捷方法 --------------------------
  /// 从远程URL创建PNF(大文件场景)
  static PortableNetworkFile createFromURL(Uri url, DecryptKey? password) {
    return create(null, null, url, password);
  }

  /// 从本地文件数据创建PNF(小文件/图片场景)
  static PortableNetworkFile createFromData(
    TransportableData data,
    String? fileName,
  ) {
    return create(data, fileName, null, null);
  }

  /// 通用创建方法
  static PortableNetworkFile create(
    TransportableData? data,
    String? fileName,
    Uri? url,
    DecryptKey? password,
  ) {
    var ext = FormatExtensions();
    return ext.pnfHelper!.createPortableNetworkFile(
      data,
      fileName,
      url,
      password,
    );
  }

  /// 解析任意对象为PNF对象(支持String/Map)
  static PortableNetworkFile? parse(Object? pnf) {
    var ext = FormatExtensions();
    return ext.pnfHelper!.parsePortableNetworkFile(pnf);
  }

  /// 获取PNF工厂
  static PortableNetworkFileFactory? getFactory() {
    var ext = FormatExtensions();
    return ext.pnfHelper!.getPortableNetworkFileFactory();
  }

  /// 注册PNF工厂
  static void setFactory(PortableNetworkFileFactory factory) {
    var ext = FormatExtensions();
    ext.pnfHelper!.setPortableNetworkFileFactory(factory);
  }
}

/// 【PNF工厂接口】
/// 定义PNF对象的创建/解析规范
abstract interface class PortableNetworkFileFactory {
  /// 创建PNF对象
  PortableNetworkFile createPortableNetworkFile(
    TransportableData? data,
    String? filename,
    Uri? url,
    DecryptKey? password,
  );

  /// 解析Map对象为PNF对象
  PortableNetworkFile? parsePortableNetworkFile(Map pnf);
}
