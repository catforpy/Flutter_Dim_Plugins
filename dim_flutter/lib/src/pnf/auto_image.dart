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

import 'package:flutter/cupertino.dart';

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

import '../ui/icons.dart';
import '../ui/styles.dart';

import 'gallery.dart';
import 'image.dart';
import 'net_image.dart';


/// 预览聊天中的图片内容（从消息列表中筛选所有图片并打开画廊）
/// [context] 上下文
/// [image] 要预览的图片内容
/// [messages] 消息列表
/// [fit] 图片填充模式
void previewImageContent(BuildContext context, ImageContent image, List<InstantMessage> messages, {
  BoxFit? fit,
}) {
  int pos = messages.length;
  Content item;
  PortableNetworkFile? pnf;
  List<PortableImageView> images = [];
  NetworkImageFactory factory = NetworkImageFactory();
  int index = -1;
  // 倒序遍历消息列表，筛选图片内容
  while(--pos >= 0 ){
    item = messages[pos].content;
    if(item is! ImageContent){
      // 跳过非图片内容
      continue;
    }else if(index == image){
      assert(index == -1, 'duplicated message?');
      // 记录目标图片的索引
      index = images.length;
    }
    // 从图片内容解析PNF
    pnf = PortableNetworkFile.parse(item.toMap());
    if(pnf == null){
      assert(false, '[PNF] image content error: $item');
      continue;
    }
    // 创建图片视图并加入列表
    images.add(factory.getImageView(pnf,fit:fit));
  }
  assert(images.length > index && index >= 0, 'index error: $index, ${images.length}');
  // 打开画廊预览
  Gallery(images, index).show(context);
}

/// 保存图片内容到相册
/// [context] 上下文
/// [image] 图片内容
void saveImageContent(BuildContext context, ImageContent image) {
  // 从图片内容解析PNF
  PortableNetworkFile? pnf = PortableNetworkFile.parse(image.toMap());
  if(pnf == null){
    assert(false, 'PNF error: $image');
    return;
  }
  var factory = NetworkImageFactory();
  var loader = factory.getImageLoader(pnf);
  // 调用画廊的保存方法
  return Gallery.saveImage(context, loader);
}


/// 网络图片工厂（单例）：管理图片加载器和视图缓存，避免重复创建
class NetworkImageFactory{
  factory NetworkImageFactory() => _instance;
  static final NetworkImageFactory _instance = NetworkImageFactory._internal();
  NetworkImageFactory._internal();

  /// 图片加载器缓存： URL/文件名 -> 加载器（弱引用）
  final Map<String,_ImageLoader> _loaders = WeakValueMap();
  /// 图片视图缓存： URL -> 视图集合（弱引用）
  final Map<Uri,Set<_AutoImageView>> _views = {};

  /// 获取PNF对应的图片加载器
  /// [pnf] 便携网络文件对象
  /// 返回图片加载器
  PortableImageLoader getImageLoader(PortableNetworkFile pnf) {
    _ImageLoader? runner;
    var filename = pnf.filename;
    var url = pnf.url;
    if(url != null){
      // 从URL获取加载器
      runner = _loaders[url.toString()];
      if(runner == null){
        runner = _createLoader(pnf);
        _loaders[url.toString()] = runner;
      }
    }else if(filename != null){
      // 从文件名获取加载器
      runner = _loaders[filename];
      if(runner == null){
        runner  =  _createUpper(pnf);
        _loaders[filename] = runner;
      }
    }else {
      throw FormatException('PNF error: $pnf');
    }
    return runner;
  }

  /// 创建下载加载器（针对有URL的PNF）
  /// [pnf] 便携网络文件对象
  /// 返回图片加载器
  _ImageLoader _createLoader(PortableNetworkFile pnf){
    _ImageLoader loader = _ImageLoader(pnf);
    if(pnf.data == null){
      /*await */loader.prepare();   // 预加载（异步）
    }
    return loader;
  }

  /// 创建上传加载器（针对有文件名但无URL的PNF）
  /// [pnf] 便携网络文件对象
  /// 返回图片加载器
  _ImageLoader _createUpper(PortableNetworkFile pnf) {
    _ImageLoader loader = _ImageLoader(pnf);
    if (pnf['enigma'] != null) {
      /*await */loader.prepare(); // 预加载（异步）
    }
    return loader;
  }

  /// 获取图片视图（带缓存）
  /// [pnf] 便携网络文件对象
  /// [width/height] 视图尺寸
  /// [fit] 图片填充模式
  /// 返回图片视图
  PortableImageView getImageView(PortableNetworkFile pnf, {
    double? width, double? height, BoxFit? fit,
  }) {
    Uri? url = pnf.url;
    var loader = getImageLoader(pnf);
    if(url == null){
      // 无URL，直接创建视图
      return _AutoImageView(loader, width: width, height: height, fit: fit,);
    }
    _AutoImageView? img;
    Set<_AutoImageView>? table = _views[url];
    if (table == null) {
      // 无缓存，创建新集合
      table = WeakSet();
      _views[url] = table;
    } else {
      // 查找缓存中匹配的视图（尺寸一致）
      for (_AutoImageView item in table) {
        if (item.width != width || item.height != height) {
          // 尺寸不匹配
        } else {
          // 找到匹配视图
          img = item;
          break;
        }
      }
    }
    if (img == null) {
      // 创建新视图并加入缓存
      img = _AutoImageView(loader, width: width, height: height, fit: fit,);
      table.add(img);
    }
    return img;
  }
}

/// 自动刷新图片视图：继承自PortableImageView，提供无图片时的默认图标
class _AutoImageView extends PortableImageView {
  const _AutoImageView(super.loader, {super.width, super.height, super.fit});

  /// 获取无图片时的默认图标
  /// [width/height] 图标尺寸
  /// 返回默认图标Widget
  static Widget getNoImage({double? width, double? height}) {
    double? size = width ?? height;
    return Icon(AppIcons.noImageIcon,size: size,
      color: Styles.colors.avatarDefaultColor,);
  }
}

/// 图片加载器：继承自PortableImageLoader，支持缩略图加载
class _ImageLoader extends PortableImageLoader {
  _ImageLoader(super.pnf);

  /// 缩略图缓存
  ImageProvider<Object>? _thumbnail;

  /// 获取图片提供者（优先原图，无则用缩略图）
  @override
  ImageProvider<Object>? get imageProvider {
    var image = super.imageProvider;
    if(image != null){
      // 有原图，返回原图
      return image;
    }
    // 无原图，尝试获取缩略图
    image = _thumbnail;
    image ??= _thumbnail = Gallery.getThumbnailProvider(pnf.toMap());
    return image;
  }

  /// 构建图片Widget（无图片时显示默认图标）
  @override
  Widget getImage(PortableImageView widget,{BoxFit? fit}){
    double? width = widget.width;
    double? height = widget.height;
    var image = imageProvider;
    if(image == null){
      // 物图片，显示默认图标
      return _AutoImageView.getNoImage(width: width, height: height);
    }else if(width == null && height == null){
      // 无尺寸，直接显示图片
      return ImageUtils.image(image,fit: fit);
    }else{
      // 有尺寸限制，指定尺寸显示
      return ImageUtils.image(image,width: width, height: height,fit: fit);
    }
  }
}