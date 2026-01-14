/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
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

import 'dart:typed_data'; // 提供Uint8List等字节数据类型

import 'package:dim_flutter/src/widgets/browser_deps.dart';
import 'package:dim_flutter/src/widgets/browser_service.dart';
import 'package:flutter/cupertino.dart'; // Flutter Cupertino风格组件

import 'package:dim_client/ok.dart'; // DIM客户端基础库
import 'package:dim_client/sdk.dart'; // DIM客户端SDK

import '../widgets/browser.dart'; // 浏览器组件


/// HTML URI处理工具类 - 封装URI解析、HTML/图片数据编码解码、网页展示等功能
abstract class HtmlUri{
  /// 空白URI常量 (about:blank)
  static final Uri blank = parseUri('about:blank')!;

  /// 解析URL字符串为Uri对象
  /// [urlString] 待解析的URL字符串
  /// 返回：Uri对象（解析失败返回null）
  static Uri? parseUri(String? urlString) {
    if (urlString == null) {
      return null;
    } else if (urlString.contains('://')) {
      // 支持标准URL格式（http://、https://等）
    } else if (urlString.startsWith('data:')) {
      // 支持data URI格式（data:text/html;charset=UTF-8;base64,）
    } else if (urlString.startsWith('about:')) {
      // 支持about URI格式（about:blank）
    } else {
      // 不支持的URL格式，记录错误日志
      Log.error('URL error: $urlString');
      return null;
    }
    try {
      // 解析URL字符串
      return Uri.parse(urlString);
    } on FormatException catch (e) {
      // 解析格式错误，记录错误日志
      Log.error('URL error: $e, $urlString');
      return null;
    }
  }

  /// 从PageContent中获取URI字符串
  /// 优先获取HTML字段（base64编码为data URI），否则获取URL字段
  static String getUriString(PageContent content) {
    // 检查HTML字段
    String? html = content.getString('HTML');
    if(html != null){
      // assert(html.isNotEmpty, 'page content error: $content');
      // 将HTML内容base64编码并转换为data URI
      String base64 = Base64.encode(UTF8.encode(html));
      return 'data:text/html;charset=UTF-8;base64,$base64';
    }
    // 检查URL字段
    String? url = content.getString('URL');
    if (url == null || url.isEmpty || url == 'about:blank') {
      // URL为空或空白页，使用空的data URI
      url = 'data:text/html,';
      // content['URL'] = url;
    }
    return url;
  }

  /// 从data URI中提取HTML字符串
  /// [url] data URI对象（必须以data:text/html开头）
  /// 返回：解码后的HTML字符串（非data URI返回null）
  static String? getHtmlString(Uri url) {
    String urlString = url.toString();
    if(!urlString.startsWith('data:text/html')){
      // 不是HTML的data URI，返回null
      return null;
    }
    // 查找base64编码部分的起始位置
    int pos = urlString.indexOf(',');
    if(pos < 0){
      // 格式错误，记录错误日志
      Log.error('web page url error: $url');
      return '';
    }
    // 提取base64编码内容并解码
    String base64 = urlString.substring(pos + 1);
    return UTF8.decode(Base64.decode(base64)!);
  }

  /// 将data URI中的HTML字符串设置到PageContent中
  /// [url] data URI对象 [content] 页面内容对象
  /// 返回：是否设置成功
  static bool setHtmlString(Uri url, PageContent content) {
    // 从URL中提取HTML字符串
    String? html = getHtmlString(url);
    if (html == null) {
      return false;
    }
    // 更新PageContent中的URL和HTML字段
    content['URL'] = url.toString();
    content['HTML'] = html;
    return true;
  }

  /// 显示网页内容
  /// [context] 上下文 [content] 页面内容 [onWebShare] 分享回调
  static void showWebPage(BuildContext context,
      {required PageContent content, OnWebShare? onWebShare, BrowserDeps deps = getxBrowserDeps}){
    // 获取URL字符串
    String url = getUriString(content);
    // 打开浏览器展示网页
    // Browser.open(context,url,onWebShare: onWebShare);
    Browser.openStatic(context, url,onWebShare: onWebShare,deps: deps);
  }

  /// 将图片字节数据编码为data URI
  /// [img] 图片字节数据 [mimeType] 图片MIME类型（默认image/png）
  /// 返回：图片的data URI
  static Uri encodeImageData(Uint8List img, {String mimeType = 'image/png'}) {
    var ted = Base64Data.fromData(img);
    var url = ted.encode(mimeType);
    return Uri.parse(url);
  }
}

/// 域名服务器工具类 - 提供域名和IP地址验证
abstract class DomainNameServer {

  /// 域名正则表达式
  /// 匹配规则：xxx.xxx.xxx（支持多级域名，最后一级至少2个字母）
  static final _domain = RegExp(r'^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$');

  /// IP地址正则表达式
  /// 匹配规则：xxx.xxx.xxx.xxx（初步匹配，后续验证数值范围）
  static final _address = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

  /// 验证是否为合法域名
  static bool isDomainName(String text) => _domain.hasMatch(text);

  /// 验证是否为合法IPv4地址
  static bool isIPAddress(String text) {
    // 初步正则匹配
    if(!_address.hasMatch(text)){
      return false;
    }
    // 分割IP段
    var array = text.split('.');
    if(array.length != 4){
      // 必须是4个分段
      return false;
    }
    // 验证每个分段的数值范围（0-255）
    for(var item in array){
      var num = int.tryParse(item);
      if(num == null || num < 0 || num > 255){
        return false;
      }
    }
    return true;
  }
}