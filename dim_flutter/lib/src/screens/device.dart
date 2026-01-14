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

import 'package:dim_client/ok.dart';
import 'package:dim_client/ws.dart';


/// 可投屏设备抽象接口：定义投屏设备的核心属性和操作
abstract class ScreenDevice with Logging {

  /// 重写toString，便于日志打印和调试
  @override
  String toString() {
    String clazz = className;
    return '<$clazz uuid="$uuid" type="$deviceType" name="$friendlyName" />';
  }

  //
  //  设备属性
  //
  /// 获取设备类型（如tv、speaker等）
  String get deviceType;
  /// 获取设备友好名称（如客厅电视）
  String get friendlyName;
  /// 获取设备唯一标识
  String get uuid;

  //
  //  设备操作
  //
  /// 检查设备是否在线
  Future<bool> alive();
  /// 投屏播放指定URL的内容
  Future<void> castURL(Uri url);
}

/// 可投屏设备扫描器抽象接口：定义设备扫描的核心方法
abstract class ScreenDiscoverer {

  /// 扫描可用的投屏设备
  /// 返回扫描到的设备列表
  Future<Iterable<ScreenDevice>> discover();

}

/// 投屏设备管理器（单例）：管理投屏设备的扫描、缓存和在线状态
/// 继承自Runner，支持定时扫描设备
class ScreenManager extends Runner with Logging {
  /// 单例工厂方法
  factory ScreenManager() => _instance;
  /// 单例实例
  static final ScreenManager _instance = ScreenManager._internal();
  /// 私有构造方法：初始化扫描间隔为慢速（INTERVAL_SLOW），并启动扫描
  ScreenManager._internal() : super(Runner.INTERVAL_SLOW) {
    /*await */run();
  }

  /// 所有扫描到的设备缓存：key=设备uuid，value=投屏设备对象
  final Map<String,ScreenDevice> _allDevices = {};
  /// 在线设备集合: 进包含当前在线的投屏设备
  final Set<ScreenDevice> _aliveDevices = {};

  /// 设备扫描器结合：支持注册多个扫描器
  final Set<ScreenDiscoverer> _scanners = {};
  /// 标记是否需要重新扫描（脏标记）
  bool _dirty = false;
  /// 标记是否正在扫描设备
  bool _scanning = false;

  /// 添加设备扫描器
  /// [delegate] 扫描器实例
  void addDiscoverer(ScreenDiscoverer delegate) => _dirty = _scanners.add(delegate);
  /// 移除设备扫描器
  /// [delegate] 扫描器实例
  void removeDiscoverer(ScreenDiscoverer delegate) => _scanners.remove(delegate);

  /// 获取当前是否正在扫描设备
  bool get scanning => _scanning || _dirty;

  /// 获取缓存的在线投屏设备列表
  Iterable<ScreenDevice> get devices => _aliveDevices;

  /// 获取在线投屏设备列表（支持强制刷新）
  /// [forceRefresh] 是否强制刷新设备列表
  /// 返回在线设备列表
  Future<Iterable<ScreenDevice>> getDevices(bool forceRefresh) async {
    if (forceRefresh) {
      // 强制刷新，标记为脏数据
      _dirty = true;
    }
    if (_scanners.isEmpty) {
      // 未注册扫描器，断言报错
      assert(false, 'scanner not set yet');
    } else {
      // 等待扫描完成（最多等待约64秒）
      int count = 128;
      while (count > 0) {
        await Runner.sleep(const Duration(milliseconds: 512));
        if (_scanning) {
          count += 1;
        } else {
          break;
        }
      }
    }
    return _aliveDevices;
  }

  /// Runner核心处理方法：执行设备扫描逻辑
  /// 返回是否继续扫描（true=继续，false=停止）
  @override
  Future<bool> process() async {
    // 复制扫描器列表，避免并发修改
    List<ScreenDiscoverer> discoverers = _scanners.toList();
    if (discoverers.isEmpty) {
      // 无扫描器，停止扫描
      return _scanning = false;
    } else if (_dirty) {
      // 有脏标记，重置标记并准备扫描
      _dirty = false;
    } else {
      // 无需扫描，停止
      return _scanning = false;
    }
    // 标记为正在扫描
    _scanning = true;
    try {
      // 执行扫描，获取在线设备候选列表
      var candidates = await _scan(discoverers);
      // 清空并更新在线设备列表
      _aliveDevices.clear();
      _aliveDevices.addAll(candidates);
    } catch (e, st) {
      // 扫描异常，记录错误日志
      logError('failed to scan screens: $e, $st');
    }
    // 扫描完成，重置标记
    _scanning = false;
    return true;
  }

  /// 执行设备扫描逻辑
  /// [discoverers] 扫描器列表
  /// 返回在线设备候选列表
  Future<Iterable<ScreenDevice>> _scan(Iterable<ScreenDiscoverer> discoverers) async {
    Iterable<ScreenDevice> screens;
    //
    //  1. 发现新设备
    //
    for (ScreenDiscoverer scanner in discoverers) {
      // 调用每个扫描器的发现方法
      screens = await scanner.discover();
      // 将新发现的设备加入缓存
      for (ScreenDevice tv in screens) {
        _allDevices[tv.uuid] = tv;
      }
    }
    //
    //  2. 检查设备在线状态
    //
    Set<ScreenDevice> candidates = {};
    // 获取所有缓存的设备
    screens = _allDevices.values;
    for (ScreenDevice tv in screens) {
      if (await tv.alive()) {
        // 设备在线，加入候选列表
        logInfo('got alive screen device: $tv');
        candidates.add(tv);
      } else {
        // 设备离线，记录警告日志并从在线列表移除
        logWarning('screen device not alive: $tv');
        _aliveDevices.remove(tv.uuid);
      }
    }
    return candidates;
  }
}