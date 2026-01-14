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

import 'package:dimp/dimp.dart';
import 'package:dimp/dkd.dart';

/// 文本消息类
/// 设计目的：封装IM中最基础的文本消息，核心字段为text
class BaseTextContent extends BaseContent implements TextContent {
  /// 构造方法1：从字典初始化（解析网络传输的文本消息）
  BaseTextContent([super.dict]);

  /// 构造方法2：从文本内容初始化（创建新文本消息）
  /// @param message - 文本内容
  BaseTextContent.fromText(String message) : super.fromType(ContentType.TEXT) {
    this['text'] = message;
  }

  /// 获取文本内容（空字符串表示未设置）
  @override
  String get text => getString('text') ?? '';
}

/// 网页消息类
/// 设计目的：封装IM中的网页分享消息，包含URL/HTML、标题、图标、描述等字段，
///           适配网页链接的可视化展示
class WebPageContent extends BaseContent implements PageContent{
  /// 构造方法1：从字典初始化（解析网络传输的网页消息）
  WebPageContent([super.dict]);
  /// 缓存：网页URL（避免重复解析）
  Uri? _url;
  /// 缓存：网页图标（避免重复解析）
  PortableNetworkFile? _icon;
  /// 构造方法2：从网页信息初始化（创建新网页信息）
  /// @param url - 网页URL
  /// @param html - 网页HTML内容（可选，优先于URL）
  /// @param title = 网页标题（必填）
  /// @param icon - 网页图标（可选）
  /// @param desc - 网页描述（可选）
  WebPageContent.from({required Uri? url,required String? html,
  required String title,PortableNetworkFile? icon,String? desc, })
  : super.fromType(ContentType.PAGE){
    // URL或HTML（二选一）
    this.url = url;
    this.html = html;
    //标题、图标、描述
    this.title = title;
    this.desc = desc;
    this.icon = icon;
  }
  /// 
  /// 标题字段
  /// 
  /// 获取网页标题（空字符串表示未设置）
  @override
  String get title =>getString('title') ?? '';
  /// 设置网页标题（同步更新字典中的title字段）
  @override
  set title(String string) => this['title'] = string;
  /// 
  /// 图标字段
  /// 
  /// 获取网页图标（null表示未设置）
  @override
  PortableNetworkFile? get icon {
    PortableNetworkFile? img = _icon;
    if(img == null){
      var base64 = getString('icon');
      img = _icon = PortableNetworkFile.parse(base64);
    }
    return img;
  }
  /// 设置网页图标（同步更新字典中的icon字段）
  @override
  set icon(PortableNetworkFile? img){
    if(img == null){
      remove('icon');
    }else{
      this['icon'] = img.toObject();
    }
    _icon = img;
  }
  /// 
  /// 描述字段（关键词/简介）
  /// 
  /// 获取网页描述（null表示未设置）
  @override
  String? get desc => getString('desc');
  /// 设置网页描述（同步更新字典中的desc字段）
  @override
  set desc(String? string) => this['desc'] = string;
  /// 
  /// URL字段
  /// 
  /// 获取网页URL（null表示未设置）
  @override
  Uri? get url{
    var locator = _url;
    if(locator == null){
      var str = getString('URL');
      if(str != null){
        _url = locator = createURL(str);
      }
    }
    return locator;
  }
  /// 内部方法：将字符串转换为Uri(子类可重写，适配特殊URL)
  Uri? createURL(String str) => Uri.parse(str);
  /// 设置网页URL（同步更新字典中的URL字段）
  set url(Uri? locator){
    this['URL'] = locator?.toString();
    _url = locator;
  }


  /// 
  /// HTML字段
  /// 
  /// 获取网页HTML内容（null表示未设置）
  @override
  String? get html => getString('html');
  /// 设置网页HTML内容（同步更新字典中的html字段）
  @override
  set html(String? content) => this['html'] = content;
  
  
}


/// 名片消息类
/// 设计目的：封装IM中个人/群组名片消息，包含ID、名称、头像等核心信息
///           支持快速添加联系人/加入群组
class NameCardContent extends BaseContent implements NameCard{
  /// 构造方法1：从字典初始化（解析网络传输的名片消息）
  NameCardContent([super.dict]);
  /// 缓存：头像（避免重复解析）
  PortableNetworkFile? _image;
  /// 构造方法2：从身份信息初始化（创建新名片消息）
  /// @param identifier - 用户/群组ID
  /// @param name - 名称（昵称/群名）
  /// @param avatar - 头像（可选）
  NameCardContent.from(ID identifier,String name,PortableNetworkFile? avatar)
      : super.fromType(ContentType.NAME_CARD){
        // 填充ID
        this['did'] = identifier.toString();
        // 填充名称
        this['name'] = name;
        // 填充头像
        if(avatar != null){
          this['avatar'] = avatar.toObject();
        }
        _image = avatar;
      }
  /// 获取名片对应的ID（解析失败时触发断言）
  @override
  ID get identifier => ID.parse(this['did'])!;
  /// 获取名称（空字符串表示未设置）
  @override
  String get name => getString('name') ?? '';
  /// 获取头像（null表示未设置）
  @override
  PortableNetworkFile? get avatar{
    PortableNetworkFile? img = _image;
    if(img == null)
    {
      var url = this['avatar'];
      img = PortableNetworkFile.parse(url);
      _image = img;
    }
    return img;
  }
  
}