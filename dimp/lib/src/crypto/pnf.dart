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

import 'package:dimp/dimp.dart';

///  文件内容封装结构：{
///
///      data     : "...",        // 文件内容的base64编码字符串
///      filename : "photo.png",  // 文件名
///
///      URL      : "http://...", // CDN下载地址（文件上传到公共CDN前需用对称密钥加密）
///      key      : {             // 解密CDN文件内容的对称密钥
///          algorithm : "AES",   // 加密算法（如DES、AES等）
///          data      : "{BASE64_ENCODE}", // 密钥数据的base64编码
///          ...
///      }
///  }
///  设计目的：封装IM中的文件消息（图片/视频/文档等），支持本地文件+CDN文件两种传输方式，
///           同时内置加密密钥，保证文件传输的安全性
class BaseFileWrapper extends Dictionary {
  /// 构造方法：初始化文件内容字典
  BaseFileWrapper([super.dict]);

  /// 缓存：文件二进制数据（避免重复解析）
  TransportableData? _attachment;

  /// 缓存：CDN下载地址（避免重复解析）
  Uri? _remoteURL;

  /// 缓存：解密CDN文件的对称密钥（避免重复解析）
  DecryptKey? _password;

  //-------- 核心属性的getter/setter --------

  ///
  /// 获取文件二进制数据（未加密）
  /// 逻辑：优先取缓存 → 解析字典中的base64字符串 → 转为TransportableData
  /// @return 文件二进制数据（null表示无数据）
  ///
  TransportableData? get data{
    TransportableData? ted = _attachment;
    if(ted == null){
      Object? base64 = this['data'];
      _attachment = ted = TransportableData.parse(base64);
    }
    return ted;
  }

  ///
  /// 设置文件二进制数据（TransportableData类型）
  /// 逻辑：同步更新字典中的base64字段+缓存
  /// @param ted - 文件数据（null标识清空）
  /// 
  set data(TransportableData? ted){
    if(ted == null){
      remove('data');
    }else{
      this['data'] = ted.toObject();
    }
    _attachment = ted;
  }

  ///
  /// 快捷设置文件二进制数据（Uint8List类型）
  /// 适配原生二进制数据输入，自动转为TransportableData
  /// @param binary - 原生二进制数据（null/空表示清空）
  /// 
  void setDate(Uint8List? binary){
    TransportableData? ted;
    if(binary == null || binary.isEmpty){
      ted = null;
      remove('data');
    }else{
      ted = TransportableData.create(binary);
      this['data'] = ted.toObject();
    }
    _attachment = ted;
  }

  ///
  /// 获取文件名
  /// 从字典中提取“filename”字段，空值自动过滤
  /// @return 文件名（null标识无）
  /// 
  String? get filename => getString('filename');

  ///
  /// 设置文件名
  /// 同步更新字典中的"filename"字段，空值自动移除
  /// @param name - 文件名（null表示清空）
  ///
  set filename(String? name) {
    if (name == null/* || name.isEmpty*/) {
      remove('filename');
    } else {
      this['filename'] = name;
    }
  }

  ///
  /// 获取CDN下载地址
  /// 逻辑：优先取缓存 → 解析字典中的"URL"字符串 → 转为Uri
  /// @return CDN地址（null表示无）
  ///
  Uri? get url {
    Uri? remote = _remoteURL;
    if (remote == null) {
      String? locator = getString('URL');
      if (locator != null && locator.isNotEmpty) {
        _remoteURL = remote = Uri.parse(locator);
      }
    }
    return remote;
  }

  ///
  /// 设置CDN下载地址
  /// 同步更新字典中的"URL"字段 + 缓存，空值自动移除
  /// @param remote - CDN地址（null表示清空）
  ///
  set url(Uri? remote) {
    if (remote == null) {
      remove('URL');
    } else {
      this['URL'] = remote.toString();
    }
    _remoteURL = remote;
  }

  ///
  /// 获取解密CDN文件的对称密钥
  /// 逻辑：优先取缓存 → 解析字典中的"key"字段 → 转为DecryptKey
  /// @return 解密密钥（null表示无需解密/无密钥）
  ///
  DecryptKey? get password {
    DecryptKey? key = _password;
    if (key == null) {
      key = SymmetricKey.parse(this['key']);
      _password = key;
    }
    return key;
  }

  ///
  /// 设置解密CDN文件的对称密钥
  /// 同步更新字典中的"key"字段 + 缓存，空值自动移除
  /// @param key - 解密密钥（null表示清空）
  ///
  set password(DecryptKey? key) {
    setMap('key', key);
    _password = key;
  }
}