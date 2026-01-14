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

import 'package:device_info_plus/device_info_plus.dart'; // 跨平台设备信息获取库
import 'package:package_info_plus/package_info_plus.dart'; // 应用包信息获取库

import '../../common/platform.dart'; // 自定义平台判断工具（Web/Android/iOS等）
import '../../widgets/permissions.dart'; // 权限修复工具（如相册权限）

/// 设备信息工具类：单例模式，统一管理跨平台设备硬件/系统信息
/// 核心功能：
/// 1. 自动识别运行平台（Web/Android/iOS等），加载对应设备信息
/// 2. 提供统一的设备信息访问入口（系统版本、设备型号、厂商等）
/// 3. 初始化时自动修复Android相册权限问题
class DeviceInfo{
  // 单例实现：工厂构造+静态私有实例，保证全局唯一
  factory DeviceInfo() => _instance;
  static final DeviceInfo _instance = DeviceInfo._internal();
  
  /// 私有构造方法：初始化设备信息加载逻辑
  DeviceInfo._internal() {
    // 创建设备信息插件实例
    DeviceInfoPlugin info = DeviceInfoPlugin();
    
    // 按平台分支加载对应设备信息（异步加载，不阻塞初始化）
    if (DevicePlatform.isWeb) {
      info.webBrowserInfo.then(_loadWeb); // Web平台
    } else if (DevicePlatform.isAndroid) {
      info.androidInfo.then(_loadAndroid); // Android平台
    } else if (DevicePlatform.isIOS) {
      info.iosInfo.then(_loadIOS); // iOS平台
    } else if (DevicePlatform.isMacOS) {
      info.macOsInfo.then(_loadMacOS); // macOS平台
    } else if (DevicePlatform.isLinux) {
      info.linuxInfo.then(_loadLinux); // Linux平台
    } else if (DevicePlatform.isWindows) {
      info.windowsInfo.then(_loadWindows); // Windows平台
    } else {
      assert(false, 'unknown platform'); // 开发期断言：未知平台（避免上线漏处理）
    }
    
    // 初始化系统语言（默认中文）
    language = DevicePlatform.localeName;
    
    // 修复Android相册权限问题（针对性兼容）
    fixPhotoPermissions();
  }

  /// Web平台设备信息加载：适配WebBrowserInfo数据结构
  /// [info] - Web浏览器信息对象
  void _loadWeb(WebBrowserInfo info) {
    // FIXME: 标记待优化：Web平台字段映射不完整，需后续完善
    systemVersion = info.appVersion ?? '';    // 浏览器应用版本
    systemModel = info.appCodeName ?? '';     // 浏览器代码名
    systemDevice = info.platform ?? '';       // Web平台标识
    deviceBrand = info.product ?? '';         // 产品名称
    deviceBoard = info.productSub ?? '';      // 产品子版本
    deviceManufacturer = info.vendor ?? '';   // 浏览器厂商
  }

  /// Android平台设备信息加载：适配AndroidDeviceInfo数据结构
  /// [info] - Android设备信息对象
  void _loadAndroid(AndroidDeviceInfo info) {
    systemVersion = info.version.release;    // Android系统版本（如14、13）
    systemModel = info.model;                // 设备型号（如Mate 60 Pro）
    systemDevice = info.device;              // 设备代号（如hammerhead）
    deviceBrand = info.brand;                // 品牌（如HUAWEI、Xiaomi）
    deviceBoard = info.board;                // 主板型号
    deviceManufacturer = info.manufacturer;  // 设备制造商
  }

  /// iOS平台设备信息加载：适配IosDeviceInfo数据结构
  /// [info] - iOS设备信息对象
  void _loadIOS(IosDeviceInfo info) {
    // FIXME: 标记待优化：device/brand/board字段映射不精准，需后续完善
    systemVersion = info.systemVersion;       // iOS系统版本（如17.0）
    systemModel = info.model;                // 设备型号（如iPhone 15）
    systemDevice = info.utsname.machine;     // 设备硬件代号（如iPhone16,1）
    deviceBrand = "Apple";                   // 固定为Apple（iOS专属）
    deviceBoard = info.utsname.machine;      // 复用硬件代号作为主板标识
    deviceManufacturer = "Apple Inc.";       // 固定制造商
  }

  /// macOS平台设备信息加载：适配MacOsDeviceInfo数据结构
  /// [info] - macOS设备信息对象
  void _loadMacOS(MacOsDeviceInfo info) {
    // FIXME: 标记待优化：device/brand/board字段映射不精准，需后续完善
    systemVersion = '${info.majorVersion}.${info.minorVersion}.${info.patchVersion}'; // 系统版本（如14.2.1）
    systemModel = info.model;                // 设备型号（如MacBook Pro）
    systemDevice = info.systemGUID ?? info.osRelease; // 设备唯一标识/系统版本
    deviceBrand = "Apple";                   // 固定为Apple
    deviceBoard = info.systemGUID ?? info.osRelease;  // 复用GUID作为主板标识
    deviceManufacturer = "Apple Inc.";       // 固定制造商
  }

  /// Linux平台设备信息加载：适配LinuxDeviceInfo数据结构
  /// [info] - Linux设备信息对象
  void _loadLinux(LinuxDeviceInfo info) {
    // FIXME: 标记待优化：多个字段映射不精准，需后续完善
    systemVersion = info.version ?? info.versionId ?? info.versionCodename ?? ''; // 系统版本（多字段兜底）
    systemModel = info.name;                 // 系统名称（如Ubuntu）
    systemDevice = info.prettyName;          // 系统友好名称
    deviceBrand = "Linux";                   // 固定品牌
    deviceBoard = info.prettyName;           // 复用友好名称作为主板标识
    deviceManufacturer = "Linux";            // 固定制造商
  }

  /// Windows平台设备信息加载：适配WindowsDeviceInfo数据结构
  /// [info] - Windows设备信息对象
  void _loadWindows(WindowsDeviceInfo info) {
    // FIXME: 标记待优化：model/device/brand/board字段映射不精准，需后续完善
    systemVersion = '${info.majorVersion}.${info.minorVersion}.${info.buildNumber}'; // 系统版本（如10.0.22621）
    systemModel = info.csdVersion;           // 系统更新版本（如Service Pack 1）
    systemDevice = info.deviceId;            // 设备唯一ID
    deviceBrand = "Windows";                 // 固定品牌
    deviceBoard = info.productName;          // 产品名称（如Windows 11 Pro）
    deviceManufacturer = info.registeredOwner; // 注册用户
  }

  // ===================== 公开属性：统一设备信息访问入口（默认值适配华为设备） =====================
  String language = "zh-CN";          // 系统语言（默认中文）
  String systemVersion = "4.0";       // 系统版本（默认4.0）
  String systemModel = "HMS";         // 设备型号（默认HMS）
  String systemDevice = "hammerhead"; // 设备代号（默认hammerhead）
  String deviceBrand = "HUAWEI";      // 设备品牌（默认华为）
  String deviceBoard = "hammerhead";  // 主板型号（默认hammerhead）
  String deviceManufacturer = "HUAWEI"; // 设备制造商（默认华为）
}

/// 应用包信息工具类：单例模式，统一管理应用版本/包名等信息
/// 核心功能：异步加载应用包信息，提供统一访问入口
class AppPackageInfo {
  // 单例实现：工厂构造+静态私有实例
  factory AppPackageInfo() => _instance;
  static final AppPackageInfo _instance = AppPackageInfo._internal();

  /// 私有构造方法：初始化应用包信息加载逻辑
  AppPackageInfo._internal() {
    // 异步加载平台包信息（不阻塞初始化）
    PackageInfo.fromPlatform().then(_load);
  }

  /// 应用包信息加载：适配PackageInfo数据结构
  /// [info] - 应用包信息对象
  void _load(PackageInfo info) {
    packageName = info.packageName;   // 应用包名（如chat.dim.tarsier）
    displayName = info.appName;       // 应用显示名称（如DIM）
    versionName = info.version;       // 版本名称（如1.0.0）
    buildNumber = info.buildNumber;   // 构建号（如10001）   
  }

  // ===================== 公开属性：应用包信息（默认值） =====================
  String packageName = "chat.dim.tarsier"; // 应用包名
  String displayName = "DIM";              // 应用显示名称
  String versionName = "1.0.0";            // 版本名称
  String buildNumber = "10001";            // 构建号
}