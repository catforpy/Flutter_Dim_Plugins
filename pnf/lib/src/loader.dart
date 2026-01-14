/* license: https://mit-license.org
 *
 *  ObjectKey : Object & Key kits
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

import 'package:mkm/crypto.dart';  // 导入加密/解密相关工具

import 'dos/paths.dart';      // 导入路径工具
import 'http/tasks.dart';     // 导入DownloadTask/DownloadInfo（下载任务接口）

import 'external.dart';       // 导入ExternalStorage（文件读写）
import 'wrapper.dart';        // 导入PNF包装器基类/通知/状态枚举

/// PNF文件下载器（实现DownloadTask接口）
/// 处理PNF文件的下载、解密、缓存逻辑，集成下载进度回调、状态管理、通知分发
abstract class PortableNetworkLoader extends PortableNetworkWrapper
    with DownloadMixin implements DownloadTask {

  /// 构造方法
  /// [pnf] - PNF文件对象（PortableNetworkFile）
  PortableNetworkLoader(super.pnf);

  /// 原始文件内容（下载并解密后的明文）
  Uint8List? _plaintext;
  /// 获取原始文件明文（对外只读）
  Uint8List? get plaintext => _plaintext;

  /// 已下载字节数（进度跟踪）
  int _count = 0;
  int get count => _count;

  /// 总下载字节数（进度跟踪）
  int _total = 0;
  int get total => _total;

  /// 下载参数缓存（避免重复创建）
  DownloadInfo? _info;

  // ------------------------------
  //  DownloadTask接口实现
  // ------------------------------

  /// 获取下载任务优先级（默认普通优先级）
  @override
  int get priority => DownloadPriority.NORMAL;

  /// 获取下载参数（URL）
  @override
  DownloadInfo? get downloadParams {
    var info = _info;
    if (info == null) {
      var url = pnf.url;
      if (url != null) {
        // 创建下载参数并缓存
        info = DownloadInfo(url);
        _info = info;
      }
    }
    return info;
  }

  /// 私有方法：解密下载的加密数据并保存到缓存
  /// [data] - 下载的加密字节数据
  /// [cachePath] - 明文缓存路径
  /// 返回值：Future<Uint8List?> - 解密后的明文（失败返回null）
  Future<Uint8List?> _decrypt(Uint8List data, String cachePath) async {
    // 1. 检查解密密钥
    DecryptKey? password = pnf.password;
    if (password == null) {
      // 无密钥 → 数据未加密，直接使用
      _plaintext = data;
    } else {
      // 有密钥 → 执行解密
      await setStatus(PortableNetworkStatus.decrypting);
      Uint8List? plaintext = password.decrypt(data, pnf);
      if (plaintext == null || plaintext.isEmpty) {
        // 解密失败 → 发送错误通知+更新状态
        await postNotification(NotificationNames.kPortableNetworkError, {
          'PNF': pnf,
          'URL': pnf.url,
          'error': 'Failed to decrypt data',
        });
        await setStatus(PortableNetworkStatus.error);
        return null;
      }
      // 解密成功 → 更新明文数据
      data = plaintext;
      _plaintext = plaintext;
    }

    // 2. 保存明文到缓存目录
    int cnt = await ExternalStorage.saveBinary(data, cachePath);
    if (cnt != data.length) {
      // 保存失败 → 断言+更新错误状态
      assert(false, 'failed to cache file: $cnt/${data.length}, $cachePath');
      await setStatus(PortableNetworkStatus.error);
      return null;
    }

    // 3. 发送成功通知+更新状态
    if (status == PortableNetworkStatus.decrypting) {
      // 发送解密成功通知
      await postNotification(NotificationNames.kPortableNetworkDecrypted, {
        'PNF': pnf,
        'URL': pnf.url,
        'data': data,
        'path': cachePath,
      });
    }
    // 发送下载成功通知
    await postNotification(NotificationNames.kPortableNetworkDownloadSuccess, {
      'PNF': pnf,
      'URL': pnf.url,
      'data': data,
      'path': cachePath,
    });
    // 更新状态为成功
    await setStatus(PortableNetworkStatus.success);
    return data;
  }

  // ------------------------------
  //  DownloadTask核心方法实现
  // ------------------------------

  /// 准备下载任务（检查缓存/临时文件，判断是否需要下载）
  /// 返回值：Future<bool> - true:需要下载，false:无需下载（缓存已存在）
  @override
  Future<bool> prepareDownload() async {
    // 0. 检查已加载的明文数据
    Uint8List? data = _plaintext;
    if (data == null) {
      // 从PNF对象/缓存加载明文
      data = await fileData;
      _plaintext = data;
    }
    if (data != null && data.isNotEmpty) {
      // 明文已存在 → 发送成功通知+更新状态，无需下载
      await postNotification(NotificationNames.kPortableNetworkDownloadSuccess, {
        'PNF': pnf,
        'URL': pnf.url,
        'data': data,
      });
      await setStatus(PortableNetworkStatus.success);
      return false;
    }

    // 1. 获取缓存文件路径（用于保存解密后的明文）
    String? cachePath = await cacheFilePath;
    if (cachePath == null) {
      // 路径获取失败 → 更新错误状态
      await setStatus(PortableNetworkStatus.error);
      assert(false, 'failed to get cache file path');
      return false;
    }

    // 2. 检查临时文件（下载/上传目录）
    String? tmpPath;
    String? down = await downloadFilePath;
    if (down != null && await Paths.exists(down)) {
      // 下载目录存在临时文件 → 使用该路径
      tmpPath = down;
    } else {
      // 检查上传目录
      String? up = await uploadFilePath;
      if (up != null && up != down && await Paths.exists(up)) {
        tmpPath = up;
      }
    }

    if (tmpPath != null) {
      // 临时文件存在 → 加载并解密
      data = await ExternalStorage.loadBinary(tmpPath);
      if (data != null && data.isNotEmpty) {
        // 加载成功 → 解密数据
        data = await _decrypt(data, cachePath);
        if (data != null && data.isNotEmpty) {
          // 解密成功 → 无需下载
          return false;
        }
      }
    }

    // 3. 检查下载URL
    Uri? url = pnf.url;
    if (url == null) {
      // 无URL → 更新错误状态
      await setStatus(PortableNetworkStatus.error);
      assert(false, 'URL not found: $pnf');
      return false;
    } else {
      // 有URL → 更新状态为等待下载，返回需要下载
      await setStatus(PortableNetworkStatus.waiting);
      return true;
    }
  }

  /// 下载进度回调（更新进度+发送通知+更新状态）
  /// [count] - 已下载字节数
  /// [total] - 总字节数
  @override
  Future<void> downloadProgress(int count, int total) async {
    // 更新进度数据
    _count = count;
    _total = total;
    // 发送进度通知
    await postNotification(NotificationNames.kPortableNetworkReceiveProgress, {
      'PNF': pnf,
      'URL': pnf.url,
      'count': count,
      'total': total,
    });
    // 更新状态为下载中
    await setStatus(PortableNetworkStatus.downloading);
  }

  /// 下载完成/失败处理（保存临时文件+解密+缓存）
  /// [data] - 下载的字节数据（null表示失败）
  @override
  Future<void> processResponse(Uint8List? data) async {
    // 0. 检查下载数据
    if (data == null || data.isEmpty) {
      // 下载失败 → 发送错误通知+更新状态
      await postNotification(NotificationNames.kPortableNetworkError, {
        'PNF': pnf,
        'URL': pnf.url,
        'error': 'Failed to download file',
      });
      await setStatus(PortableNetworkStatus.error);
      return;
    }

    // 1. 保存下载的加密数据到临时目录
    String? tmpPath = await downloadFilePath;
    if (tmpPath == null) {
      // 临时路径获取失败 → 更新错误状态
      await setStatus(PortableNetworkStatus.error);
      assert(false, 'failed to get temporary path');
      return;
    }
    int cnt = await ExternalStorage.saveBinary(data, tmpPath);
    if (cnt != data.length) {
      // 保存失败 → 断言+更新错误状态
      assert(false, 'failed to save temporary file: $cnt/${data.length}, $tmpPath');
      await setStatus(PortableNetworkStatus.error);
      return;
    }
    // 发送下载完成通知（未解密）
    await postNotification(NotificationNames.kPortableNetworkReceived, {
      'PNF': pnf,
      'URL': pnf.url,
      'data': data,
      'path': tmpPath,
    });

    // 2. 解密数据并保存到缓存
    String? cachePath = await cacheFilePath;
    if (cachePath == null) {
      // 缓存路径获取失败 → 更新错误状态
      await setStatus(PortableNetworkStatus.error);
      assert(false, 'failed to get cache file path');
      return;
    }
    await _decrypt(data, cachePath);
  }

}
