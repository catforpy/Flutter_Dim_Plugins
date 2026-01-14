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

import 'package:dimp/mkm.dart';

///
/// 用户基础身份文档（Visa）
/// ~~~~~~~~~~~~~~~~~~~~~~
/// 作用：存储用户的公开加密密钥、头像等身份信息，是去中心化身份体系中用户的核心档案
/// 注：为了安全，Visa中的加密密钥应与Meta中的签名密钥区分开
///
class BaseVisa extends BaseDocument implements Visa {
  // 构造方法1：从字典初始化（解析网络/本地存储的Visa文档）
  BaseVisa([super.dict]);

  /// 加密用公钥（缓存，避免重复解析）
  /// 用途：用于加密发给该用户的消息（端到端加密核心）
  EncryptKey? _key;

  /// 用户头像（缓存，避免重复解析）
  PortableNetworkFile? _avatar;

  /// 构造方法2：创建新的用户Visa文档
  /// @param identifier   - 用户ID
  /// @param data         - 文档内容（JSON字符串）
  /// @param signature    - 文档签名（防止篡改）
  BaseVisa.from(ID identifier, {String? data, TransportableData? signature})
    : super.from(
        identifier,
        DocumentType.VISA,
        data: data,
        signature: signature,
      );

  /// 获取加密公钥（实现visa接口）
  @override
  EncryptKey? get publicKey {
    EncryptKey? visaKey = _key;
    if (visaKey == null) {
      // 从文档属性中读取'key'字段
      Object? info = getProperty('key');
      // 解析为公钥对象，并校验是否为加密秘钥
      PublicKey? pKey = PublicKey.parse(info);
      if (pKey is EncryptKey) {
        visaKey = pKey as EncryptKey;
        _key = visaKey; // 缓存解析结果
      } else {
        assert(info == null, 'Visa加密密钥格式错误: $info');
      }
    }
    return visaKey;
  }

  /// 设置加密公钥（实现Visa接口）
  @override
  set publicKey(EncryptKey? publicKey) {
    // 将公钥转为字典并存储到文档属性
    setProperty('key', publicKey?.toMap());
    _key = publicKey; // 更新缓存
  }

  /// 获取用户头像（实现Visa接口）
  @override
  PortableNetworkFile? get avatar {
    PortableNetworkFile? img = _avatar;
    if (img == null) {
      // 从文档属性中读取'avatar'字段（URL/Base64）
      var url = getProperty('avatar');
      if (url is String && url.isEmpty) {
        // 忽略空URL
      } else {
        // 解析为可传输的图片对象
        img = PortableNetworkFile.parse(url);
        _avatar = img; // 缓存解析结果
      }
    }
    return img;
  }

  /// 设置用户头像（实现Visa接口）
  @override
  set avatar(PortableNetworkFile? avatar) {
    // 将图片转为字典并存储到文档属性
    setProperty('avatar', avatar?.toMap());
    _avatar = avatar; //更新缓存
  }
}

///
/// 群组基础身份文档（Bulletin）
/// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
/// 作用：存储群组的创建者、助理机器人等信息，是去中心化群组的核心档案
///
class BaseBulletin extends BaseDocument implements Bulletin {
  // 构造方法1：从字典初始化（解析网络/本地存储的Bulletin文档）
  BaseBulletin([super.dict]);

  /// 群组助理机器人ID列表（缓存，避免重复解析）
  /// 用途：拆分/分发群消息，减轻群主/服务器压力
  List<ID>? _bots;

  /// 构造方法2：创建新的群组Bulletin文档
  /// @param identifier   - 群组ID
  /// @param data         - 文档内容（JSON字符串）
  /// @param signature    - 文档签名（防止篡改）
  BaseBulletin.from(ID identifier, {String? data, TransportableData? signature})
    : super.from(
        identifier,
        DocumentType.BULLETIN,
        data: data,
        signature: signature,
      );

  /// 获取群组创建者ID（实现Bulletin接口）
  @override
  ID? get founder => ID.parse(getProperty('founder'));

  /// 获取群组助理机器人列表（实现Bulletin接口）
  @override
  List<ID>? get assistants {
    if (_bots == null) {
      // 优先读取'assistants'字段（列表）
      Object? bots = getProperty('assistants');
      if (bots is List) {
        _bots = ID.convert(bots); // 列表转ID对象数组
      } else {
        // 兼容旧版'assistant'字段（单个ID）
        ID? single = ID.parse(getProperty('assistant'));
        _bots = single == null ? [] : [single];
      }
    }
    return _bots;
  }

  /// 设置群组助理机器人列表（实现Bulletin接口）
  @override
  set assistants(List<ID>? bots) {
    // 存储列表形式的'assistants'，并清空旧版'single'字段
    setProperty('assistants', bots == null ? null : ID.revert(bots));
    setProperty('assistant', null);
    _bots = bots; //更新缓存
  }
}
