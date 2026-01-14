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

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'dim_flutter_method_channel.dart';

/// DimFlutter插件的平台接口抽象类
/// 继承自PluginPlatformInterface，用于实现多平台（Android/iOS/Web）适配
abstract class DimFlutterPlatform extends PlatformInterface {
  /// 构造函数：初始化平台接口，传入唯一标识token
  DimFlutterPlatform() : super(token: _token);

  /// 平台接口的唯一标识token（用于验证实例类型）
  static final Object _token = Object();

  /// 默认的平台接口实例（MethodChannel实现，适配Android/iOS）
  static DimFlutterPlatform _instance = MethodChannelDimFlutter();

  /// 获取默认的平台接口实例
  /// 默认使用MethodChannelDimFlutter（Android/iOS）
  static DimFlutterPlatform get instance => _instance;

  /// 设置自定义的平台接口实例
  /// 平台特定实现需要注册自己的实现类（如Web端实现）
  static set instance(DimFlutterPlatform instance) {
    // 验证实例的token是否匹配，确保类型正确
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// 获取平台版本信息的抽象方法
  /// 子类需要实现此方法以返回对应平台的版本信息
  Future<String?> getPlatformVersion() {
    // 未实现时抛出异常
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}