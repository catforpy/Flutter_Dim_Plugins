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

import 'package:castscreen/castscreen.dart';

import 'package:dim_client/ok.dart';

import 'device.dart';


/// 投屏设备发现器（单例）：基于castscreen库实现局域网内投屏设备的发现
/// 实现ScreenDiscoverer抽象接口，提供设备扫描能力
class CastScreenDiscoverer with Logging implements ScreenDiscoverer {
  /// 单例工厂方法
  factory CastScreenDiscoverer() => _instance;
  /// 单例实例
  static final CastScreenDiscoverer _instance = CastScreenDiscoverer._internal();
  /// 私有构造方法
  CastScreenDiscoverer._internal();

  /// 发现局域网内的投屏设备
  /// 重试逻辑：初始超时2秒，未发现设备则翻倍超时时间（最大8秒）
  /// 返回投屏设备列表（ScreenDevice类型）
  @override
  Future<Iterable<ScreenDevice>> discover() async {
    logInfo('discovering devices ...');
    List<Device> devices = [];
    int seconds = 2;
    // 未发现设备且超时时间小于10秒时，继续重试
    while (devices.isEmpty && seconds < 10) {
      seconds <<= 1; // 超时时间翻倍（2→4→8）
      logInfo('discover duration: $seconds seconds');
      // 调用castscreen库的设备发现接口
      devices = await CastScreen.discoverDevice(timeout: Duration(seconds: seconds));
    }
    logInfo('discovered devices: $devices');
    // 将castscreen的Device转换为统一的ScreenDevice
    return screens(devices);
  }

  /// 将castscreen的Device列表转换为ScreenDevice列表
  /// [devices] castscreen库的设备列表
  /// 返回统一的投屏设备列表
  static Iterable<ScreenDevice> screens(Iterable<Device> devices) =>
      devices.map<ScreenDevice>((tv) => _CastScreenDevice(tv));
  
  /// 将单个castscreen的Device转换为ScreenDevice
  /// [tv] castscreen库的设备对象
  /// 返回统一的投屏设备对象
  static ScreenDevice screen(Device tv) => _CastScreenDevice(tv);
}

/// 具体的投屏设备实现类：适配castscreen库的Device，实现ScreenDevice接口
class _CastScreenDevice extends ScreenDevice with Logging {
  /// 构造方法
  /// [_tv] castscreen库的原生设备对象
  _CastScreenDevice(this._tv);

  /// castscreen库的原生设备对象
  final Device _tv;

  /// 获取设备类型（如"tv"、"speaker"等）
  @override
  String get deviceType => _tv.spec.deviceType;

  /// 获取设备友好名称（如"客厅电视"）
  @override
  String get friendlyName => _tv.spec.friendlyName;

  /// 获取设备唯一标识
  @override
  String get uuid => _tv.spec.uuid;

  /// 检查设备是否在线
  /// 返回设备在线状态（true=在线，false=离线）
  @override
  Future<bool> alive() async => await _tv.alive();

  /// 投屏播放指定URL的内容
  /// [url] 要播放的媒体URL
  /// 返回投屏操作是否成功（仅表示设备在线，不代表播放成功）
  @override
  Future<bool> castURL(Uri url) async {
    // 先检查设备是否在线
    bool isAlive = await alive();
    if (isAlive) {
      // 设备在线，尝试设置播放URL
      logInfo('device "$friendlyName" ($deviceType) is alive, try to play URL: $url');
      _tv.setAVTransportURI(SetAVTransportURIInput(url.toString()));
    } else {
      // 设备离线，记录错误日志
      logError('device "$friendlyName" ($deviceType) is not alive, cannot play URL: $url');
    }
    return isAlive;
  }

  /// 重写toString，便于日志打印和调试
  @override
  String toString() {
    String clazz = className;
    return '<$clazz uuid="$uuid" type="$deviceType" name="$friendlyName">\n\t${_tv.client}\n</$clazz>';
  }

}