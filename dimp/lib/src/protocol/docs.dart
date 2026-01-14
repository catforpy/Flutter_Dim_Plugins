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

import 'package:mkm/protocol.dart';

/// 个人签证（Visa）接口
/// 作用：定义用户的核心身份资料，包含加密用公钥、头像等信息，用于授权其他应用登录/加密消息
/// 说明：Visa是Document的子类，属于用户的公开资料，可通过DocumentCommand同步
abstract interface class Visa implements Document{
  /// 获取用于加密消息的公钥（其他用户用此公钥加密发给该用户的消息）
  /// @return - 加密公钥（visa。key字段）
  EncryptKey? get publicKey;
  /// 设置加密公钥
  /// @param pKey - 加密公钥
  set publicKey(EncryptKey? pKey);
  /// 获取头像URL（PNF格式）
  PortableNetworkFile? get avatar;
  /// 设置头像URL
  /// @param url - 头像URL
  set avatar(PortableNetworkFile? img);
}

/// 群组公告（Bulletin）接口
/// 作用：定义群组的核心资料，包含创始人、助理（机器人）等信息，是群组的公开配置
/// 说明：Bulletin是Document的子类，属于群组的公开资料，可通过DocumentCommand同步
abstract interface class Bulletin implements Document{
  /// 获取群组创始人ID
  /// @return 创始人用户ID
  ID? get founder;

  /// 获取群组助理（机器人）列表
  /// @return 助理ID列表
  List<ID>? get assistants;

  /// 设置群组助理列表
  /// @param bots - 助理ID列表
  set assistants(List<ID>? bots);
}