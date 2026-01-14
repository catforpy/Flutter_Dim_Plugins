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

import 'dart:ui_web';

import 'package:dimp/dimp.dart';
import 'package:dimp/dkd.dart';

/// 文本消息内容接口
/// 作用：定义最基础的文本聊天消息结构，是IM的核心业务消息
/// 数据格式：{
///      type : i2s(0x01),  // 消息类型标识（0x01=文本）
///      sn   : 123,        // 消息序列号（唯一标识）
///
///      text : "..."       // 文本内容
///  }
abstract interface class TextContent implements Content{
  /// 获取文本内容
  String get text;

  //-------- 工厂方法 --------
  /// 创建文本消息
  /// @param message - 文本内容
  /// @return 文本消息实例
  static TextContent create(String message) =>
      BaseTextContent.fromText(message);
}

/// 网页消息内容接口
/// 作用：定义包含网页信息的消息结构，支持分享链接/富文本网页
/// 数据格式：{
///      type : i2s(0x20),  // 消息类型标识（0x20=网页）
///      sn   : 123,        // 消息序列号
///
///      title : "...",                // 网页标题
///      desc  : "...",                // 网页描述
///      icon  : "data:image/x-icon;base64,...", // 网页图标（Base64）
///
///      URL   : "https://github.com/moky/dimp", // 网页链接
///
///      HTML      : "...",            // 网页HTML内容
///      mime_type : "text/html",      // 内容类型
///      encoding  : "utf8",           // 编码格式
///      base      : "about:blank"     // 基础URL（解析相对路径用）
///  }
abstract interface class PageContent implements Content{
  /// 获取/设置网页标题
  String get title;
  set title(String string);

  /// 获取/设置网页图标（Base64图片）
  PortableNetworkFile? get icon;
  set icon(PortableNetworkFile? img);

  /// 获取/设置网页描述
  String? get desc;
  set desc(String? string);

  /// 获取/设置网页URL
  Uri? get url;
  set url(Uri? locator);

  /// 获取/设置网页HTML内容
  String? get html;
  set html(String? content);

  //-------- 工厂方法 --------
  /// 创建网页消息（通用）
  /// @param url   - 网页URL（可选）
  /// @param html  - HTML内容（可选）
  /// @param title - 标题（必填）
  /// @param icon  - 图标（可选）
  /// @param desc  - 描述（可选）
  /// @return 网页消息实例
  static PageContent create({Uri? url,String? html,
  required String title,PortableNetworkFile? icon,String? desc}) =>
  WebPageContent.from(url: url, html: html, title: title,
  icon: icon,desc: desc);

  /// 从URL创建网页消息（仅分享链接）
  static PageContent createFromURL(Uri url,{
    required String title,PortableNetworkFile? icon,String? desc
  }) => create(url: url,html: null,title: title,icon: icon,desc: desc);

  /// 从HTML创建网页消息（仅本地HTML）
  static PageContent createFromHTML(String html, {
    required String title, PortableNetworkFile? icon, String? desc}) =>
      create(url: null, html: html, title: title, icon: icon, desc: desc);
}

/// 名片消息内容接口
/// 作用：定义用户名片消息，用于分享联系人信息
/// 数据格式：{
///      type : i2s(0x33),  // 消息类型标识（0x33=名片）
///      sn   : 123,        // 消息序列号
///
///      did    : "{ID}",        // 联系人ID
///      name   : "{nickname}}", // 联系人昵称
///      avatar : "{URL}",       // 联系人头像（PNF格式）
///  }
abstract interface class NameCard implements Content{
  /// 获取联系人ID
  ID get identifier;

  /// 获取联系人昵称
  String get name;

  /// 获取联系人头像
  PortableNetworkFile? get avatar;

  //-------- 工厂方法 --------
  /// 创建名片消息
  /// @param identifier - 联系人ID
  /// @param name       - 昵称
  /// @param avatar     - 头像（可选）
  /// @return 名片消息实例
  static NameCard create(ID identifier, String name, PortableNetworkFile? avatar) =>
      NameCardContent.from(identifier, name, avatar);
}