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

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:dim_client/sdk.dart';
import 'package:dim_client/ok.dart';

import '../ui/icons.dart';


/// 图片工具类：提供图片Widget创建、提供者获取、压缩等功能
abstract class ImageUtils {

  /// 从字符串创建图片Widget（支持网络URL或Base64数据）
  /// [small] 图片地址/Base64字符串
  /// [width/height] 图片尺寸
  /// [fit] 填充模式
  /// 返回图片Widget（null表示创建失败）
  static Image? getImage(String small, {double? width, double? height, BoxFit? fit}){
    assert(small.isNotEmpty, 'image info empty');
    if(small.contains('://')){
      // 网络URL
      return networkImage(small, width: width, height: height, fit: fit);
    }else{
      // Base64数据
      var ted = TransportableData.parse(small);
      Uint8List? bytes = ted?.data;
      if (bytes != null && bytes.isNotEmpty) {
        return memoryImage(bytes, width: width, height: height, fit: fit);
      }
    }
    assert(false, 'thumbnail error: $small');
    return null;
  }

  /// 从字符串创建图片提供者（支持网络URL或Base64数据）
  /// [small] 图片地址/Base64字符串
  /// 返回图片提供者（null表示创建失败）
  static ImageProvider? getProvider(String small) {
    assert(small.isNotEmpty, 'image info empty');
    if(small.contains('://')){
      // 网络URL
      return networkImageProvider(small);
    }else {
      // Base64数据
      var ted = TransportableData.parse(small);
      Uint8List? bytes = ted?.data;
      if (bytes != null && bytes.isNotEmpty) {
        return memoryImageProvider(bytes);
      }
    }
    assert(false, 'thumbnail error: $small');
    return null;
  }

  //
  //  Image Widget 创建
  //

  /// 创建通用图片Widget（带错误处理）
  /// [img] 图片提供者
  /// [width/height] 图片尺寸
  /// [fit] 填充模式
  /// 返回图片Widget
  static Image image(ImageProvider img, {
    double? width, double? height, BoxFit? fit,
  }) => Image(image: img, width: width, height: height, fit: fit,
    errorBuilder: (ctx, e, st) => _noImage(width: width, height: height),
  );

  /// 创建网络图片Widget（带错误处理）
  /// [src] 网络URL
  /// [width/height] 图片尺寸
  /// [fit] 填充模式
  /// 返回图片Widget
  static Image networkImage(String src, {
    double? width, double? height, BoxFit? fit,
  }) => Image.network(src, width: width, height: height, fit: fit,
    errorBuilder: (ctx, e, st) => _noImage(width: width, height: height),
  );

  /// 创建内存图片Widget（带错误处理）
  /// [bytes] 图片字节数据
  /// [width/height] 图片尺寸
  /// [fit] 填充模式
  /// 返回图片Widget
  static Image memoryImage(Uint8List bytes, {
    double? width, double? height, BoxFit? fit,
  }) => Image.memory(bytes, width: width, height: height, fit: fit,
    errorBuilder: (ctx, e, st) => _noImage(width: width, height: height),
  );

  /// 创建本地文件图片Widget（带错误处理）
  /// [path] 文件路径
  /// [width/height] 图片尺寸
  /// [fit] 填充模式
  /// 返回图片Widget
  static Image fileImage(String path, {
    double? width, double? height, BoxFit? fit,
  }) => Image.file(File(path), width: width, height: height, fit: fit,
    errorBuilder: (ctx, e, st) => _noImage(width: width, height: height),
  );

  //
  //  ImageProvider 创建
  //

  /// 创建网络图片提供者
  /// [src] 网络URL
  /// 返回图片提供者
  static ImageProvider networkImageProvider(String src) =>
      NetworkImage(src);

  /// 创建内存图片提供者
  /// [bytes] 图片字节数据
  /// 返回图片提供者
  static ImageProvider memoryImageProvider(Uint8List bytes) =>
      MemoryImage(bytes);

  /// 创建本地文件图片提供者
  /// [path] 文件路径
  /// 返回图片提供者
  static ImageProvider fileImageProvider(String path) =>
      FileImage(File(path));

  //
  //  图片压缩
  //

  /// 压缩图片为缩略图（128*128，低质量）
  /// [jpeg] JPEG图片字节数据
  /// 返回压缩后的字节数据（null表示压缩失败）
  static Future<Uint8List?> compressThumbnail(Uint8List jpeg) async =>
      await compress(jpeg, minHeight: 128, minWidth: 128, quality: 20,);

  /// 通用图片压缩方法
  /// [image] 图片字节数据
  /// [minWidth/minHeight] 最小尺寸
  /// [quality] 压缩质量（0-100）
  /// 返回压缩后的字节数据（null表示压缩失败）
  static Future<Uint8List?> compress(Uint8List image,
      {required int minWidth, required int minHeight, int quality = 95}) async {
    try{
      return await FlutterImageCompress.compressWithList(image,
        minWidth: minWidth, minHeight: minHeight, quality: quality,);
    }catch (e, st) {
      Log.error('[JPEG] failed to compress image: $minWidth x $minHeight, q: $quality, $e, $st');
      return null;
    }
  }
}

/// 图片加载失败时显示的占位Widget
/// [width/height] 占位尺寸
/// 返回错误占位Widget
Widget _noImage({double? width, double? height}) {
  Log.error('no image: $width, $height');
  if (width == null && height == null) {
    return const Icon(AppIcons.noImageIcon, color: CupertinoColors.systemRed,);
  }
  return Stack(
    alignment: AlignmentDirectional.center,
    children: [
      SizedBox(width: width, height: height,),
      const Icon(AppIcons.noImageIcon, color: CupertinoColors.systemRed,),
    ],
  );
}