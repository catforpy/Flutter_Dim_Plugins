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

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dim_flutter/src/ui/nav.dart';
import 'package:flutter/widgets.dart';
// import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:dim_client/ok.dart';

import '../common/platform.dart';
import 'alert.dart';

/// 权限检查器（单例）
/// 主要处理通知权限的检查和管理
class PermissionChecker {
  /// 单例工厂方法
  factory PermissionChecker() => _instance;
  /// 单例实例
  static final PermissionChecker _instance = PermissionChecker._internal();
  /// 私有构造函数
  PermissionChecker._internal();

  /// 通知权限是否已授权（缓存结果）
  bool? _isNotificationAllowed;

  /// 是否需要检查通知权限
  bool _needsNotification = false;
  /// 是否正在检查通知权限
  bool _checkingForNotification = false;

  /// 获取通知权限授权状态（只读）
  bool? get isNotificationPermissionGranted => _isNotificationAllowed;
  // bool get needsNotificationPermissions => _needsNotification; // 注释的属性

  /// 设置需要检查通知权限
  void setNeedsNotificationPermissions() {
    _needsNotification = true;
    _checkingForNotification = true;
  }
  
  /// 标记需要重新检查通知权限
  void checkAgain() {
    if (_needsNotification) {
      // _isNotificationAllowed = null; // 注释的代码：清空缓存
      _checkingForNotification = true;
    }
  }

  /// 检查通知权限
  /// [context] - 上下文
  /// 返回：是否已授权
  Future<bool> checkNotificationPermissions(BuildContext context) async {
    // 需要检查时才执行检查
    if (_checkingForNotification) {
      _checkingForNotification = false; // 重置检查状态
    } else {
      Log.info('no need to check notification permissions now');
      return _isNotificationAllowed == true; // 返回缓存结果
    }
    
    Log.info('checking notification permissions');
    var center = PermissionCenter();
    // 请求通知权限
    bool granted = await center.requestNotificationPermissions(context,
      onGranted: (context) => Log.info('notification permissions granted.'),
    );
    _isNotificationAllowed = granted; // 缓存授权状态
    return granted;
  }

  /// 检查数据库权限
  /// 返回：是否已授权
  Future<bool> checkDatabasePermissions() async => _PermissionHandler.check(
    _PermissionHandler.databasePermissions,
    onDenied: (permission) => Log.error('database permissions denied: $permission'),
  );

}

/// 权限中心（单例）
/// 统一管理各种权限的请求和处理
class PermissionCenter {
  /// 单例工厂方法
  factory PermissionCenter() => _instance;
  /// 单例实例
  static final PermissionCenter _instance = PermissionCenter._internal();
  /// 私有构造函数
  PermissionCenter._internal();

  /// 打开应用设置页面
  /// 返回：是否成功打开
  Future<bool> openSettings() async {
    PermissionChecker().checkAgain(); // 标记需要重新检查权限
    return await openAppSettings();   // 调用系统API打开设置
  }

  /// 请求数据库权限
  /// [context] - 上下文
  /// [onGranted] - 授权成功回调
  /// 返回：是否已授权
  Future<bool> requestDatabasePermissions(BuildContext context, {
    required void Function(BuildContext context) onGranted
  }) async => await _requestPermissions(
    _PermissionHandler.databasePermissions,
    i18nTranslator.translate('Grant to access external storage'), // 权限说明文字（国际化）
    context: context,
    onGranted: onGranted,
  );

  /// 请求照片读取权限
  /// 参数同requestDatabasePermissions
  Future<bool> requestPhotoReadingPermissions(BuildContext context, {
    required void Function(BuildContext context) onGranted
  }) async => await _requestPermissions(
    _PermissionHandler.photoReadingPermissions,
    i18nTranslator.translate('Grant to access photo album'),
    context: context,
    onGranted: onGranted,
  );

  /// 请求照片访问权限（读写）
  /// 参数同requestDatabasePermissions
  Future<bool> requestPhotoAccessingPermissions(BuildContext context, {
    required void Function(BuildContext context) onGranted
  }) async => await _requestPermissions(
    _PermissionHandler.photoAccessingPermissions,
    i18nTranslator.translate('Grant to access photo album'),
    context: context,
    onGranted: onGranted,
  );

  /// 请求相机权限
  /// 参数同requestDatabasePermissions
  Future<bool> requestCameraPermissions(BuildContext context, {
    required void Function(BuildContext context) onGranted
  }) async => await _requestPermissions(
    _PermissionHandler.cameraPermissions,
    i18nTranslator.translate('Grant to access camera'),
    context: context,
    onGranted: onGranted,
  );

  /// 请求麦克风权限
  /// 参数同requestDatabasePermissions
  Future<bool> requestMicrophonePermissions(BuildContext context, {
    required void Function(BuildContext context) onGranted
  }) async => await _requestPermissions(
    _PermissionHandler.microphonePermissions,
    i18nTranslator.translate('Grant to access microphone'),
    context: context,
    onGranted: onGranted,
  );

  /// 请求通知权限
  /// 参数同requestDatabasePermissions
  Future<bool> requestNotificationPermissions(BuildContext context, {
    required void Function(BuildContext context) onGranted
  }) async => await _requestPermissions(
    _PermissionHandler.notificationPermissions,
    i18nTranslator.translate('Grant to allow notifications'),
    context: context,
    onGranted: onGranted,
  );

}

/// 通用权限请求方法
/// [permissions] - 权限列表
/// [message] - 权限说明文字
/// [context] - 上下文
/// [onGranted] - 授权成功回调
/// 返回：是否已授权
Future<bool> _requestPermissions(List<Permission> permissions, String message, {
  required BuildContext context,
  required void Function(BuildContext context) onGranted
}) async {
  // 请求权限
  bool granted = await _PermissionHandler.request(
    permissions,
    // 权限被拒绝时显示确认框，引导用户到设置页面
    onDenied: (permission) => Alert.confirm(context,
      'Permission Denied', // 标题
      message,             // 说明
      okTitle: 'Settings', // 确认按钮文字（设置）
      okAction: () => PermissionCenter().openSettings(), // 打开设置页面
    ),
  );
  // 授权成功且上下文有效时执行回调
  if (granted && context.mounted) {
    onGranted(context);
  }
  return granted;
}

/// 权限处理器（内部工具类）
/// 封装权限检查和请求的底层逻辑
class _PermissionHandler {

  /// 检查权限列表是否都已授权
  /// [permissions] - 权限列表
  /// [onDenied] - 权限被拒绝回调
  /// 返回：是否全部授权
  static Future<bool> check(List<Permission> permissions, {
    required void Function(Permission permission) onDenied
  }) async {
    PermissionStatus status;
    bool isGranted;
    Log.info('check permissions: $permissions');
    
    // 遍历检查每个权限
    for (Permission item in permissions) {
      try {
        status = await item.status;    // 获取权限状态
        isGranted = status.isGranted;  // 判断是否授权
      } catch (e, st) {
        // 捕获异常，标记为未授权
        Log.error('check permission error: $e, $st');
        assert(false, 'failed to check permission: $item');
        isGranted = false;
      }
      
      if (isGranted) {
        Log.info('permission granted: $item'); // 权限已授权
        continue;
      }
      
      Log.warning('permission status: $isGranted, $item'); // 权限未授权
      onDenied(item); // 执行拒绝回调
      return false;   // 有一个未授权则返回false
    }
    return true; // 全部授权返回true
  }

  /// 请求权限列表
  /// [permissions] - 权限列表
  /// [onDenied] - 权限被拒绝回调
  /// 返回：是否全部授权
  static Future<bool> request(List<Permission> permissions, {
    required void Function(Permission permission) onDenied
  }) async {
    PermissionStatus status;
    bool isGranted;
    Log.info('request permissions: $permissions');
    
    // 遍历请求每个权限
    for (Permission item in permissions) {
      try {
        status = await item.request(); // 请求权限
        isGranted = status.isGranted;  // 判断是否授权
      } catch (e, st) {
        // 捕获异常，标记为未授权
        Log.error('request permission error: $e, $st');
        assert(false, 'failed to request permission: $item');
        isGranted = false;
      }
      
      if (isGranted) {
        Log.info('permission granted: $item'); // 权限已授权
        continue;
      }
      
      Log.warning('permission status: $isGranted, $item'); // 权限未授权
      onDenied(item); // 执行拒绝回调
      return false;   // 有一个未授权则返回false
    }
    return true; // 全部授权返回true
  }

  //
  //  各类型权限定义
  //

  /// 数据库权限
  static List<Permission> get databasePermissions => [
    /// Android: 外部存储权限
    /// iOS: 访问Documents/Downloads文件夹（隐式授权）
    // Permission.storage, // 注释的权限
  ];

  /// 照片读取权限
  static List<Permission> get photoReadingPermissions => _photoReadingPermissions;
  static final List<Permission> _photoReadingPermissions = [
    /// Android T及以上: 读取图片文件
    /// Android < T: 无
    /// iOS: 照片权限（iOS14+ 读写级别）
    if (DevicePlatform.isIOS)
    Permission.photos,
  ];

  /// 照片访问权限（读写）
  static List<Permission> get photoAccessingPermissions => _photoAccessingPermissions;
  static final List<Permission> _photoAccessingPermissions = [
    /// Android T及以上: 读取图片文件
    /// Android < T: 无
    /// iOS: 照片权限（iOS14+ 读写级别）
    if (DevicePlatform.isIOS)
    Permission.photos,

    /// Android: 无
    /// iOS: 照片添加权限（iOS14+ 读写级别）
    if (DevicePlatform.isIOS)
    Permission.photosAddOnly,

    /// Android: 外部存储权限
    /// iOS: 访问Documents/Downloads文件夹（隐式授权）
    // if (DevicePlatform.isAndroid)
    // Permission.storage, // 注释的权限
  ];

  /// 相机权限
  static List<Permission> get cameraPermissions => [
    /// Android: 相机权限
    /// iOS: 照片（相机胶卷和相机）权限
    Permission.camera,

    // Permission.storage, // 注释的权限
  ];

  /// 麦克风权限
  static List<Permission> get microphonePermissions => [
    /// Android: 麦克风权限
    /// iOS: 麦克风权限
    Permission.microphone,
  ];

  /// 通知权限
  static List<Permission> get notificationPermissions => [
    /// Android: Firebase云消息权限
    Permission.notification,
  ];

}

/// 是否已修复照片权限配置
bool _isPhotoPermissionsFixed = false;

/// 修复Android不同版本的照片权限配置
/// 返回：是否进行了修复
Future<bool> fixPhotoPermissions() async {
  if (_isPhotoPermissionsFixed) {
    return false; // 已修复，直接返回
  } else {
    _isPhotoPermissionsFixed = true; // 标记为已修复
  }
  
  if (DevicePlatform.isAndroid) {
    // 获取Android设备信息
    AndroidDeviceInfo info = await DeviceInfoPlugin().androidInfo;
    int sdkInt = info.version.sdkInt; // Android SDK版本
    Log.warning('fixing photo permissions: $sdkInt');
    
    // Android 13+ (SDK 33) 使用photos权限
    if (sdkInt > 32) {
      _PermissionHandler._photoAccessingPermissions.add(Permission.photos);
      _PermissionHandler._photoReadingPermissions.add(Permission.photos);
    } 
    // Android 12及以下 使用storage权限
    else {
      _PermissionHandler._photoAccessingPermissions.add(Permission.storage);
      _PermissionHandler._photoReadingPermissions.add(Permission.storage);
    }
    return true; // 已修复
  }
  return false; // 非Android平台，无需修复
}

/* iOS Podfile配置说明：
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',

        ## dart: PermissionGroup.calendar
        # 'PERMISSION_EVENTS=1',

        ## dart: PermissionGroup.reminders
        # 'PERMISSION_REMINDERS=1',

        ## dart: PermissionGroup.contacts
        # 'PERMISSION_CONTACTS=1',

        ## dart: PermissionGroup.camera
        'PERMISSION_CAMERA=1',

        ## dart: PermissionGroup.microphone
        'PERMISSION_MICROPHONE=1',

        ## dart: PermissionGroup.speech
        # 'PERMISSION_SPEECH_RECOGNIZER=1',

        ## dart: PermissionGroup.photos
        'PERMISSION_PHOTOS=1',
        'PERMISSION_PHOTOS_ADD_ONLY=1',

        ## dart: [PermissionGroup.location, PermissionGroup.locationAlways, PermissionGroup.locationWhenInUse]
        # 'PERMISSION_LOCATION=1',

        ## dart: PermissionGroup.notification
        # 'PERMISSION_NOTIFICATIONS=1',

        ## dart: PermissionGroup.mediaLibrary
        # 'PERMISSION_MEDIA_LIBRARY=1',

        ## dart: PermissionGroup.sensors
        # 'PERMISSION_SENSORS=1',

        ## dart: PermissionGroup.bluetooth
        # 'PERMISSION_BLUETOOTH=1',

        ## dart: PermissionGroup.appTrackingTransparency
        # 'PERMISSION_APP_TRACKING_TRANSPARENCY=1',

        ## dart: PermissionGroup.criticalAlerts
        # 'PERMISSION_CRITICAL_ALERTS=1'
      ]
    end
*/