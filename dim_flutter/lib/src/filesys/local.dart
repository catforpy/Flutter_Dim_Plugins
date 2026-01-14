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

import 'package:path_provider/path_provider.dart';

import 'package:dim_client/ok.dart';
import 'package:dim_client/pnf.dart';

import '../channels/manager.dart';
import '../common/platform.dart';

/// 本地存储工具类（单例）
/// 继承FileCache并实现日志能力，提供跨平台的缓存目录管理和头像文件路径生成
class LocalStorage extends FileCache with Logging {
  /// 工厂方法：获取单例实例
  factory LocalStorage() => _instance;
  /// 静态单例实例
  static final LocalStorage _instance = LocalStorage._internal();
  /// 私有构造函数
  LocalStorage._internal();

  /// 重写：获取缓存目录路径（跨平台适配）
  @override
  Future<String> get cachesDirectory async {
    // web平台返回固定路径
    if(DevicePlatform.isWeb){
      return '/var/caches';
    }
    // iOS/Android平台通过通道获取缓存目录
    if (DevicePlatform.isIOS || DevicePlatform.isAndroid) {
      ChannelManager man = ChannelManager();
      String? path = await man.ftpChannel.cachesDirectory;
      // logInfo('[DOS] caches directory: $path');
      return path!;
    }
    // 桌面平台获取应用支持目录
    var dir = await getApplicationSupportDirectory();
    // logInfo('[DOS] caches directory: $dir');
    return dir.path;
  }

  /// 重写：获取临时目录路径（跨平台适配）
  @override
  Future<String> get temporaryDirectory async {
    // web平台返回固定路径
    if(DevicePlatform.isWeb){
      return '/tmp';
    }
    // IOS/Android平台通过通道获取临时目录
    if(DevicePlatform.isAndroid || DevicePlatform.isIOS){
      ChannelManager man = ChannelManager();
      String? path = await man.ftpChannel.temporaryDirectory;
      return path!;
    }
    // 桌面平台获取系统临时目录
    var dir = await getTemporaryDirectory();
    // logInfo('[DOS] temporary directory: $dir');
    return dir.path;
  }

  ///  生成头像图片文件的存储路径
  ///  路径格式："{caches}/avatar/{AA}/{BB}/{filename}"
  ///  其中AA为文件名前2位，BB为文件名2-4位，用于分散存储避免单目录文件过多
  ///
  /// @param filename - 图片文件名（格式：md5(data)的十六进制字符串 + 扩展名）
  /// @return 完整的头像文件路径
  Future<String> getAvatarFilePath(String filename) async {
    // 校验文件名格式（扩展名位置需大于第4位）
    if (filename.indexOf('.') < 4) {
      logError('invalid filename: $filename');
      return Paths.append(await cachesDirectory, filename);
    }
    // 提取文件名前4位用于目录分级
    String aa = filename.substring(0, 2);
    String bb = filename.substring(2, 4);
    // 拼接完整路径
    return Paths.append(await cachesDirectory, 'avatar', aa, bb, filename);
  }
}