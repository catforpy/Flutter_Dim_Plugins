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

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';

import 'package:dim_client/ok.dart';

import '../pnf/image.dart';
import '../ui/icons.dart';

import 'alert.dart';
import 'permissions.dart';

/// 图片选择回调类型
/// [path] - 图片文件路径
typedef OnImagePicked = void Function(String path);
/// 图片读取回调类型
/// [path] - 图片文件路径
/// [data] - 图片二进制数据
typedef OnImageRead = void Function(String path, Uint8List data);

/// 打开图片选择器（相机/相册）
/// [context] - 上下文
/// [onPicked] - 图片选择回调（可选）
/// [onRead] - 图片读取回调（必填）
void openImagePicker(BuildContext context, {OnImagePicked? onPicked, required OnImageRead onRead}) =>
    // 显示底部操作菜单
    Alert.actionSheet(context, null, null,
      // 相机选项
      Alert.action(AppIcons.cameraIcon, 'Camera'),
          () => PermissionCenter().requestCameraPermissions(context,
            // 相机权限授权成功后打开相机
            onGranted: (context) => _openImagePicker(context, true, onPicked, onRead),
          ),
      // 相册选项
      Alert.action(AppIcons.albumIcon, 'Album'),
          () => PermissionCenter().requestPhotoReadingPermissions(context,
            // 相册权限授权成功后打开相册
            onGranted: (context) => _openImagePicker(context, false, onPicked, onRead),
          ),
    );

/// 实际打开图片选择器的内部方法
/// [context] - 上下文
/// [camera] - true:相机，false:相册
/// [onPicked] - 图片选择回调
/// [onRead] - 图片读取回调
void _openImagePicker(BuildContext context, bool camera, OnImagePicked? onPicked, OnImageRead onRead) =>
    // 调用ImagePicker选择图片
    ImagePicker().pickImage(source: camera ? ImageSource.camera : ImageSource.gallery).then((file) {
      if (file == null) {
        Log.error('failed to get image file'); // 未选择图片
        return;
      }
      String path = file.path; // 图片文件路径
      // 读取图片二进制数据
      file.readAsBytes().then((data) {
        if (!context.mounted) {
          Log.warning('context unmounted: $context'); // 上下文已销毁
          return;
        }
        Log.debug('image file length: ${data.length}, path: $path'); // 调试日志
        // 创建图片预览组件
        Image body = ImageUtils.memoryImage(data);
        // 显示图片预览确认框
        Alert.confirm(context, 'Pick Image', body,
          // 确认选择图片
          okAction: () {
            if (onPicked != null) {
              onPicked(path); // 执行选择回调
            }
            onRead(path, data); // 执行读取回调
          },
        );
      }).onError((error, stackTrace) {
        // 读取图片失败
        if (context.mounted) {
          Alert.show(context, 'Image File Error', '$error');
        }
      });
    }).onError((error, stackTrace) {
      // 选择图片失败
      if (context.mounted) {
        String title = camera ? 'Camera Error' : 'Gallery Error';
        Alert.show(context, title, '$error');
      }
    });

/// 调整图片大小（压缩大图片）
/// [jpeg] - 原始图片二进制数据
/// [size] - 目标尺寸（宽高）
/// [onSank] - 压缩完成回调（返回压缩后的图片数据）
void adjustImage(Uint8List jpeg, int size, void Function(Uint8List small) onSank) {
  int fileSize = jpeg.length;       // 原始文件大小
  int maxFileSize = size * size;    // 最大文件大小阈值
  
  // 文件大小未超过阈值，无需压缩
  if (fileSize <= maxFileSize) {
    Log.info('no need to resize: $fileSize <= $maxFileSize');
    onSank(jpeg); // 直接返回原始数据
  } 
  // 文件过大，需要压缩
  else {
    // 计算压缩比例
    double ratio = sqrt(maxFileSize / fileSize);
    Log.info('resize image with ratio: $ratio, $fileSize > $maxFileSize');
    
    // 解析图片获取尺寸信息
    _resolveImage(jpeg, (ui.Image image) async {
      // 计算压缩后的尺寸
      double width = image.width * ratio;
      double height = image.height * ratio;
      
      // 压缩图片
      Uint8List? small = await ImageUtils.compress(jpeg,
        minWidth: width.toInt(),
        minHeight: height.toInt(),
      );
      
      // 计算压缩阈值：
      // - 小于2MB：压缩后至少为原大小的75%
      // - 大于等于2MB：至少减小512KB
      int borderline = fileSize < _lintel  // 2 MB
          ? fileSize - (fileSize >> 2)     // size * 0.75
          : fileSize - _threshold;         // size - 0.5 MB
      
      Log.info('resized: ${image.width} * ${image.height} => $width * $height,'
          ' $fileSize => ${small?.length} bytes');
      
      // 压缩有效：返回压缩后的数据
      if (small != null && small.length < borderline) {
        onSank(small);
      } 
      // 压缩无效：返回原始数据
      else {
        Log.warning('unworthy compression: $fileSize -> ${small?.length}, borderline: $borderline');
        onSank(jpeg);
      }
    });
  }
}

/// 常量定义
const int _lintel = 1 << 21;    // 2MB (1024*1024*2)
const int _threshold = 1 << 19; // 512KB (1024*512)

/// 解析图片数据获取尺寸信息
/// [jpeg] - 图片二进制数据
/// [onResolved] - 解析完成回调（返回ui.Image对象）
void _resolveImage(Uint8List jpeg, void Function(ui.Image image) onResolved) =>
    // 创建内存图片提供器并解析
    ImageUtils.memoryImageProvider(jpeg).resolve(const ImageConfiguration()).addListener(
        // 图片解析完成回调
        ImageStreamListener((info, _) => onResolved(info.image))
    );