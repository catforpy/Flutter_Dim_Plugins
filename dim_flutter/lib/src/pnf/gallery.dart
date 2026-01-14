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
import 'package:get/get.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'package:dim_client/ok.dart';
import 'package:dim_client/pnf.dart';

import '../ui/icons.dart';
import '../ui/nav.dart';
import '../widgets/alert.dart';
import '../widgets/permissions.dart';

import 'image.dart';
import 'net_image.dart';


/// 图片画廊：管理图片预览列表和当前索引，提供预览和保存功能
class Gallery{
  Gallery(this.images, this.index);

  /// 图片视图列表
  final List<PortableImageView> images;
  /// 当前预览的图片索引
  final int index;

  /// 显示画廊页面
  /// [context] 上下文
  void show(BuildContext context) => appTool.showPage(
    context: context,
    builder: (context) => _ImagePreview(this),
  );

  /// 保存图片到相册（先申请权限）
  /// [context] 上下文
  /// [loader] 图片加载器
  static void saveImage(BuildContext context, PortableImageLoader loader) =>
      PermissionCenter().requestPhotoAccessingPermissions(context,
        onGranted: (context) => _confirmToSave(context, loader),
      );

  /// 从图片内容获取缩略图Widget
  /// [content] 图片内容Map
  /// 返回缩略图Widget（null表示无缩略图）
  static Image? getThumbnail(Map content) {
    String? small = content['thumbnail'];
    return small == null ? null : ImageUtils.getImage(small);
  }

  /// 从图片内容获取快照Widget
  /// [content] 图片内容Map
  /// 返回快照Widget（null表示无快照）
  static Image? getSnapshot(Map content) {
    String? small = content['snapshot'];
    return small == null ? null : ImageUtils.getImage(small);
  }

  /// 从图片内容获取缩略图提供者
  /// [content] 图片内容Map
  /// 返回缩略图提供者（null表示无缩略图）
  static ImageProvider? getThumbnailProvider(Map content) {
    String? small = content['thumbnail'];
    return small == null ? null : ImageUtils.getProvider(small);
  }
  /// 从图片内容获取快照提供者
  /// [content] 图片内容Map
  /// 返回快照提供者（null表示无快照）
  static ImageProvider? getSnapshotProvider(Map content) {
    String? small = content['snapshot'];
    return small == null ? null : ImageUtils.getProvider(small);
  }
}

/// 图片预览页面：基于PhotoViewGallery实现缩放预览，支持长按保存
class _ImagePreview extends StatefulWidget {
  const _ImagePreview(this.info);

  /// 画廊信息
  final Gallery info;

  @override
  State<_ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<_ImagePreview> {

  /// 页面控制器（用于图片切换）
  PageController? _controller;

  /// 获取页面控制器（懒加载）
  PageController get controller {
    PageController? ctrl = _controller;
    if(ctrl == null){
      // 初始化控制器，指定初始页面
      ctrl = PageController(initialPage: widget.info.index);
      _controller = ctrl;
    }
    return ctrl;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    // 点击空白处关闭预览
    child: Container(
      color: CupertinoColors.black,
      child: _gallery(),
    ), 
    onTap: () => appTool.closePage(context),
  );

  /// 构建图片画廊（支持缩放、切换）
  Widget _gallery() => PhotoViewGallery.builder(
    // 弹性滚动物理效果
    scrollPhysics: const BouncingScrollPhysics(),
    // 构建每个图片项
    builder: (context,index){
      var view = widget.info.images[index];
      var loader = view.loader as PortableImageLoader;
      return PhotoViewGalleryPageOptions.customChild(
        child: GestureDetector(
          child: view,
          // 长按弹出保存菜单
          onLongPress: () => Alert.actionSheet(
            context, null, 
            null, 
            Alert.action(AppIcons.saveFileIcon, 'Save to Album'), 
            () => Gallery.saveImage(context, loader),
          ),
        )
      );
    },
    // 图片数量
    itemCount: widget.info.images.length, 
    // 背景色
    backgroundDecoration: const BoxDecoration(color: CupertinoColors.black),
    // 页面控制器
    pageController: controller,
  );
}

/// 确认保存图片（弹出确认对话框）
/// [context] 上下文
/// [loader] 图片加载器
void _confirmToSave(BuildContext context,PortableImageLoader loader){
  Alert.confirm(context, i18nTranslator.translate('Confirm'),
  i18nTranslator.translate('Sure to save this image?'),
  okAction: () => _saveImage(context,loader),
  );
}

/// 执行图片保存逻辑
/// [context] 上下文
/// [loader] 图片加载器
void _saveImage(BuildContext context, PortableImageLoader loader) {
  if(loader.status == PortableNetworkStatus.success){
    //  加载成功，获取缓存文件路径
    loader.cacheFilePath.then((path){
      if(!context.mounted){
        Log.warning('context unmounted: $context');
      }  else if (path == null) {
        Alert.show(context, i18nTranslator.translate('Error'), 
          i18nTranslator.translate('Failed to get image file'));
      } else {
        // 保存文件到相册
        _saveFile(context, path);
      }
    });
  }else {
    // 加载未完成，提示无法保存
    Alert.show(context, i18nTranslator.translate('Error'), 
      i18nTranslator.translate('Cannot save this image'));
  }
}


/// 保存文件到相册（调用原生相册保存API）
/// [context] 上下文
/// [path] 文件路径
void _saveFile(BuildContext context, String path) {
  ImageGallerySaver.saveFile(path).then((result){
    Log.info('saving image: $path, result: $result');
    if(!context.mounted){
      Log.warning('context unmounted: $context');
    }else if(result != null && result['isSuccess']){
      // 保存成功提示
      Alert.show(context, i18nTranslator.translate('Success'), 
        i18nTranslator.translate('Image saved to album'));
    }else {
      // 保存失败提示
      String? error = result['error'];
      error ??= result['errorMessage'];
      error ??= 'Failed to save image to album'.tr;
      Alert.show(context, 'Error', error);
    }
  });
}