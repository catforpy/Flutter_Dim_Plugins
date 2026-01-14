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

import 'dart:typed_data';

import 'package:dim_flutter/src/ui/nav.dart';
import 'package:flutter/cupertino.dart';

import 'package:dim_client/pnf.dart';

import '../ui/icons.dart';

import 'image.dart';
import 'loader.dart';
import 'net_base.dart';


/// 便携网络图片视图：用于展示PNF类型的图片内容，支持进度显示
class PortableImageView extends PortableNetworkView {
  /// 构造方法
  /// [loader] 图片加载器
  /// [width/height] 视图尺寸
  /// [fit] 图片填充模式
  /// [key] Widget标识
  const PortableImageView(super.loader, {this.width, this.height, this.fit, super.key});

  /// 视图宽度
  final double? width;
  /// 视图高度
  final double? height;
  /// 图片填充模式
  final BoxFit? fit;

  @override
  State<StatefulWidget> createState() => _PortableImageState();
}

/// 便携网络图片视图状态类：处理图片展示和进度指示器逻辑
class _PortableImageState extends PortableNetworkState<PortableImageView>{
  @override
  Widget build(BuildContext context) {
    // 将通用加载器强转为图片加载器
    var loader = widget.loader as PortableImageLoader;
    // 获取进度提示器（根据文件传输状态）
    Widget? indicator = loader.getProgress(widget);
    if (indicator == null) {
      // 无进度指示器，直接显示图片
      return loader.getImage(widget, fit: widget.fit);
    }
    // 有进度指示器，叠加显示在图片上方
    return Stack(
      alignment: AlignmentDirectional.center,
      // fit: StackFit.passthrough,
      children: [
        // 底层显示图片
        loader.getImage(widget, fit: widget.fit),
        // 上层显示进度指示器
        indicator,
      ],
    );
  }
}


/// 便携网络图片加载器抽象类：继承自文件加载器，扩展图片相关功能
abstract class PortableImageLoader extends PortableFileLoader {
  /// 构造方法
  /// [pnf] 便携网络文件对象
  PortableImageLoader(super.pnf);

  /// 图片提供者缓存（避免重复创建）
  ImageProvider<Object>? _provider;

  /// 获取图片提供者：优先从缓存获取，无则从铭文数据创建
  ImageProvider<Object>? get imageProvider{
    var image = _provider;
    if(image == null){
      // 检查文件明文数据
      Uint8List? bytes = plaintext;
      if(bytes != null && bytes.isNotEmpty){
        // 从内存数据创建图片提供者并缓存
        image = _provider = ImageUtils.memoryImageProvider(bytes);
      }
    }
    return image;
  } 

  /// 抽象方法：构建图片展示Widget（由子类实现）
  /// [widget] 图片视图
  /// [fit] 图片填充模式
  /// 返回图片Widget
  Widget getImage(PortableImageView widget, {BoxFit? fit});

  /// 获取进度指示器Widget：根据文件传输状态返回对应的进度提示
  /// [widget] 图片视图
  /// 返回进度指示器（null表示无进度需要显示）
  Widget? getProgress(PortableImageView widget) {
    String text; // 进度文本
    IconData? icon; // 进度图标
    Color color = CupertinoColors.white; // 进度颜色（默认白色）
    // 获取当前文件传输状态
    PortableNetworkStatus pns = status;
    // 根据状态确定进度文本和图标
    if (pns == PortableNetworkStatus.success) {
      // 传输成功，无进度指示器
      return null;
    } else if (pns == PortableNetworkStatus.init) {
      // 初始状态：等待中
      text = i18nTranslator.translate('Waiting');
    } else if (pns == PortableNetworkStatus.waiting) {
      // 等待状态：等待中
      text = i18nTranslator.translate('Waiting');
    } else if (pns == PortableNetworkStatus.encrypting) {
      // 加密中状态
      double size = total.toDouble();
      if (size > 0) {
        // 显示加密进度百分比
        double value = count * 100.0 / size;
        text = '${value.toStringAsFixed(1)}%';
      } else {
        // 无总大小，显示"加密中"文本
        text = i18nTranslator.translate('Encrypting');
        icon = AppIcons.encryptingIcon;
      }
    } else if (pns == PortableNetworkStatus.uploading) {
      // 上传中状态：显示上传进度百分比
      double size = total.toDouble();
      double value = size > 0 ? count * 100.0 / size : 0.0;
      text = '${value.toStringAsFixed(1)}%';
    } else if (pns == PortableNetworkStatus.downloading) {
      // 下载中状态
      double size = total.toDouble();
      double value = size > 0 ? count * 100.0 / size : 0.0;
      if (value < 100.0) {
        // 下载进度未完成，显示百分比
        text = '${value.toStringAsFixed(1)}%';
      } else {
        // 下载完成，解密中
        text = i18nTranslator.translate('Decrypting');
        icon = AppIcons.decryptingIcon;
      }
    } else if (pns == PortableNetworkStatus.decrypting) {
      // 解密中状态
      text = i18nTranslator.translate('Decrypting');
      icon = AppIcons.decryptingIcon;
    } else if (pns == PortableNetworkStatus.error) {
      // 错误状态：显示错误文本和图标，颜色改为红色
      text = i18nTranslator.translate('Error');
      icon = AppIcons.decryptErrorIcon;
      color = CupertinoColors.systemRed;
    } else {
      // 未知状态，断言报错
      assert(false, 'status error: $pns');
      return null;
    }
    // 检查视图尺寸，确定进度指示器样式
    double? width = widget.width;
    double? height = widget.height;
    if (width == null || height == null) {
      // 无尺寸限制，使用默认样式
    } else if (width < 64 || height < 64) {
      // 小尺寸视图，显示小型指示器
      double size = width < height ? width : height;
      return _indicator(icon, color, size);
    }
    // 大尺寸视图，显示带文本的托盘式指示器
    return _tray(text, icon, color);
  }

  /// 创建小型进度指示器（圆形，仅显示图标/加载动画）
  /// [icon] 图标
  /// [color] 颜色
  /// [size] 尺寸
  /// 返回指示器Widget
  Widget _indicator(IconData? icon, Color color, double size) => Container(
    color: CupertinoColors.secondaryLabel,
    width: size,
    height: size,
    child: icon == null
        ? CupertinoActivityIndicator(color: color, radius: size/4,) // 加载动画
        : Icon(icon, color: color, size: size/2,), // 状态图标
  );

  /// 创建托盘式进度指示器（方形，带文本和图标/加载动画）
  /// [text] 进度文本
  /// [icon] 图标
  /// [color] 颜色
  /// 返回指示器Widget
  Widget _tray(String text, IconData? icon, Color color) => ClipRRect(
    borderRadius: const BorderRadius.all(
      Radius.elliptical(8, 8),
    ),
    child: Container(
      color: CupertinoColors.secondaryLabel,
      width: 64,
      height: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 加载动画/状态图标
          icon == null
              ? CupertinoActivityIndicator(color: color)
              : Icon(icon, color: color),
          // 进度文本
          Text(text,
            style: TextStyle(color: color, fontSize: 10,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    ),
  );
}