
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


import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dim_flutter_platform_interface.dart';

/// DimFlutter插件的MethodChannel实现类
/// 用于Flutter与原生平台（Android/iOS）通过MethodChannel进行通信
class MethodChannelDimFlutter extends DimFlutterPlatform {
  /// 用于与原生平台交互的MethodChannel （通道名称：dim_flutter）
  /// @visibleForTesting 标记：仅用于测试目的可见
  @visibleForTesting
  final methodChannel = const MethodChannel('dim_flutter');

  /// 获取平台版本信息（实现父类抽象方法）
  /// 返回：原生平台返回的版本字符串（如Android版本/iOS版本）
  @override
  Future<String?> getPlatformVersion() async {
    // 调用原生平台的"getPlatformVersion"方法
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}