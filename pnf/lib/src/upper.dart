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

import 'package:dio/dio.dart';  // 导入FormData/MultipartFile（上传表单）

import 'package:mkm/format.dart';  // 导入JSON编解码工具

import 'dos/paths.dart';      // 导入路径工具
import 'http/client.dart';    // 导入HTTPClient（表单构建）
import 'http/tasks.dart';     // 导入UploadTask/UploadInfo（上传任务接口）

import 'external.dart';       // 导入ExternalStorage（文件读写）
import 'wrapper.dart';        // 导入PNF包装器基类/通知/状态枚举

/// PNF文件上传器（实现UploadTask接口）
/// 处理PNF文件的加密、表单构建、上传逻辑，集成上传进度回调、状态管理、通知分发
abstract class PortableNetworkUpper extends PortableNetworkWrapper
    with UploadMixin implements UploadTask {

  /// 构造方法
  /// [pnf] - PNF文件对象（PortableNetworkFile）
  PortableNetworkUpper(super.pnf);

  /// 原始文件明文（未加密）
  Uint8List? _plaintext;
  /// 加密后的文件数据（待上传）
  Uint8List? _ciphertext;

  /// 已上传字节数（进度跟踪）
  int _count = 0;
  int get count => _count;

  /// 总上传字节数（进度跟踪）
  int _total = 0;
  int get total => _total;
  // int get total => _ciphertext?.length ?? 0;

  /// 上传API地址缓存（避免重复构建）
  Uri? _uploadAPI;
  /// 上传参数缓存（避免重复创建）
  UploadInfo? _info;

  // ------------------------------
  //  UploadTask接口实现
  // ------------------------------

  /// 获取上传参数（URL+表单数据）
  @override
  UploadInfo? get uploadParams {
    var info = _info;
    if (info == null) {
      var form = formData;    // 构建上传表单
      var url = uploadURL;    // 获取上传API地址
      if (url != null && form != null) {
        // 创建上传参数并缓存
        info = UploadInfo(url, form);
        _info = info;
      }
    }
    return info;
  }

  /// 获取上传API地址（从enigma构建，带签名）
  /// 返回值：Uri? - 上传目标URL（null表示构建失败）
  Uri? get uploadURL {
    Uri? url = _uploadAPI;
    if (url == null) {
      Uint8List? data = _ciphertext;
      if (data != null) {
        // 从加密数据构建上传URL并缓存
        url = buildUploadURL(data);
        _uploadAPI = url;
      }
    }
    return url;
  }

  /// 构建上传表单数据（包含加密文件）
  /// 返回值：FormData? - 上传表单（null表示参数不全）
  FormData? get formData {
    String? filename = encryptedFilename;  // 加密后的文件名
    Uint8List? data = _ciphertext;         // 加密后的文件数据
    if (filename == null || filename.isEmpty) {
      return null;
    } else if (data == null || data.isEmpty) {
      return null;
    }
    // 构建MultipartFile并封装为FormData
    var file = HTTPClient.buildMultipartFile(filename, data);
    return HTTPClient.buildFormData('file', file);
  }

  /// 获取原始文件明文（从PNF/缓存加载）
  /// 返回值：Future<Uint8List?> - 明文数据（null表示加载失败）
  Future<Uint8List?> get plaintext async {
    Uint8List? data = _plaintext;
    if (data == null) {
      // 从PNF对象/缓存加载明文
      data = await fileData;
      _plaintext = data;
    }
    return data;
  }

  /// 获取加密后的文件数据（从临时目录加载）
  /// 返回值：Future<Uint8List?> - 加密数据（null表示加载失败）
  Future<Uint8List?> get encryptedData async {
    Uint8List? data = _ciphertext;
    if (data == null) {
      // 从上传临时目录加载加密数据
      String? path = await uploadFilePath;
      if (path != null && await Paths.exists(path)) {
        data = await ExternalStorage.loadBinary(path);
        _ciphertext = data;
      }
    }
    return data;
  }

  // ------------------------------
  //  UploadTask核心方法实现
  // ------------------------------

  /// 准备上传任务（检查已上传状态/加密数据，判断是否需要上传）
  /// 返回值：Future<bool> - true:需要上传，false:无需上传（已上传/参数错误）
  @override
  Future<bool> prepareUpload() async {
    // 0. 检查是否已上传（PNF包含下载URL）
    Map? extra = pnf['enigma'];       // 上传加密信息
    Uri? downloadURL = pnf.url;       // 下载URL（上传成功后赋值）
    if (downloadURL != null) {
      // 已上传 → 清理PNF中的临时数据（data/enigma）
      Uint8List? data = pnf.data;
      if (data != null) {
        pnf.data = null;
      }
      if (extra != null) {
        pnf.remove('enigma');
      }
      assert(data == null, 'file content error: $pnf');
      // 发送上传成功通知+更新状态
      await postNotification(NotificationNames.kPortableNetworkUploadSuccess, {
        'PNF': pnf,
        'URL': downloadURL,
        'data': data,
        'extra': extra,
      });
      await setStatus(PortableNetworkStatus.success);
      return false;
    } else if (extra == null) {
      // 无enigma信息 → 无法加密，发送错误通知
      await postNotification(NotificationNames.kPortableNetworkError, {
        'PNF': pnf,
        'URL': downloadURL,
        'error': 'Cannot encrypt data',
      });
      await setStatus(PortableNetworkStatus.error);
      return false;
    }

    // 1. 检查已加密的数据
    String? filename = encryptedFilename;    // 加密后的文件名
    Uint8List? data = await encryptedData;   // 加密后的文件数据
    if (filename != null && data != null) {
      assert(filename.isNotEmpty && data.isNotEmpty, 'file data error: $filename, $data');
      // 已加密 → 更新状态为等待上传，返回需要上传
      await setStatus(PortableNetworkStatus.waiting);
      return true;
    }
    assert(filename == null && data == null, 'file data error: $filename, $data');

    // 2. 加密原始文件数据
    filename = pnf.filename;    // 原始文件名
    data = await plaintext;     // 原始文件明文
    if (filename == null || filename.isEmpty || data == null || data.isEmpty) {
      // 原始文件获取失败 → 更新错误状态
      await setStatus(PortableNetworkStatus.error);
      assert(false, 'failed to get file: $filename');
      return false;
    }
    // 更新状态为加密中
    await setStatus(PortableNetworkStatus.encrypting);
    // 执行加密（使用PNF的密钥）
    Uint8List ciphertext = password.encrypt(data, pnf.toMap());

    // 3. 保存加密数据到临时目录
    // 生成加密后的哈希文件名
    filename = buildFilename(ciphertext, filename);
    // 获取上传临时路径
    String path = await buildUploadFilePath(filename);
    // 保存加密数据
    int cnt = await ExternalStorage.saveBinary(ciphertext, path);
    if (cnt != ciphertext.length) {
      // 保存失败 → 断言+更新错误状态
      assert(false, 'failed to cache upload file: $cnt/${ciphertext.length}, $path');
      await setStatus(PortableNetworkStatus.error);
      return false;
    }

    // 加密完成 → 更新缓存+enigma信息+发送通知
    _ciphertext = ciphertext;
    extra['filename'] = filename;  // 更新enigma中的加密文件名
    // 发送加密成功通知
    await postNotification(NotificationNames.kPortableNetworkEncrypted, {
      'PNF': pnf,
      'path': path,
      'data': ciphertext,
    });
    // 更新状态为等待上传，返回需要上传
    await setStatus(PortableNetworkStatus.waiting);
    return true;
  }

  /// 上传进度回调（更新进度+发送通知+更新状态）
  /// [count] - 已上传字节数
  /// [total] - 总字节数
  @override
  Future<void> uploadProgress(int count, int total) async {
    // 更新进度数据
    _count = count;
    _total = total;
    // 发送上传进度通知
    await postNotification(NotificationNames.kPortableNetworkSendProgress, {
      'PNF': pnf,
      'count': count,
      'total': total,
    });
    // 更新状态为上传中
    await setStatus(PortableNetworkStatus.uploading);
  }

  /// 上传完成/失败处理（解析响应+更新PNF+发送通知）
  /// [response] - 服务器响应字符串（null表示失败）
  @override
  Future<void> processResponse(String? response) async {
    // 0. 检查响应数据
    if (response == null || response.isEmpty) {
      // 响应为空 → 发送错误通知+更新状态
      await postNotification(NotificationNames.kPortableNetworkError, {
        'PNF': pnf,
        'error': 'Upload response error',
      });
      await setStatus(PortableNetworkStatus.error);
      return;
    }

    // 1. 解析服务器响应（JSON格式）
    Map? info;
    try {
      info = JSONMap.decode(response);
    } catch (e, st) {
      // 解析失败 → 打印日志
      print('[HTTP] Response error: $e, $uploadURL -> $response, $st');
      return;
    }
    // 校验响应状态码（200表示成功）
    int? code = info?['code'];
    assert(code == 200, 'response error: $uploadURL -> $response');

    // 2. 提取下载URL（上传成功后服务器返回的可下载地址）
    String? url = info?['url'] ?? info?['URL'];
    Uri? downloadURL = HTTPClient.parseURL(url);
    if (downloadURL == null) {
      // URL解析失败 → 发送错误通知+更新状态
      await postNotification(NotificationNames.kPortableNetworkError, {
        'PNF': pnf,
        'response': response,
        'error': 'Failed to parse response',
      });
      await setStatus(PortableNetworkStatus.error);
      return;
    }

    // 3. 上传成功 → 更新PNF+发送通知+更新状态
    pnf.url = downloadURL;  // 设置下载URL
    Map? extra = pnf['enigma'];  // 清理临时加密信息
    Uint8List? data = pnf.data;
    if (data != null) {
      pnf.data = null;  // 清理原始数据
    }
    if (extra != null) {
      pnf.remove('enigma');  // 清理加密信息
    }
    // 发送上传成功通知
    await postNotification(NotificationNames.kPortableNetworkUploadSuccess, {
      'PNF': pnf,
      'URL': downloadURL,
      'data': data,
      'extra': extra,
    });
    // 更新状态为成功
    await setStatus(PortableNetworkStatus.success);
  }

}