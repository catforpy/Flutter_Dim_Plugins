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

import 'package:mkm/protocol.dart';  // 导入ID/SymmetricKey等加密相关类型

import 'crypto/enigma.dart';  // 导入Enigma（加密/签名工具）
import 'dos/paths.dart';      // 导入路径工具
import 'http/client.dart';    // 导入HTTPClient（URL解析）

import 'cache.dart';          // 导入FileCache（缓存路径）
import 'external.dart';       // 导入ExternalStorage（文件读写）
import 'helper.dart';         // 导入URLHelper（哈希文件名）

// ------------------------------
//  通知名称常量
// ------------------------------

/// PNF文件传输相关通知名称
/// 用于状态变更、进度、成功/失败等事件的分发
abstract class NotificationNames {
  /// 状态变更通知
  static const String kPortableNetworkStatusChanged   = 'PNF_OnStatusChanged';
  /// 上传进度通知
  static const String kPortableNetworkSendProgress    = 'PNF_OnSendProgress';
  /// 下载进度通知
  static const String kPortableNetworkReceiveProgress = 'PNF_OnReceiveProgress';
  /// 加密完成通知
  static const String kPortableNetworkEncrypted       = 'PNF_OnEncrypted';
  /// 下载完成（未解密）通知
  static const String kPortableNetworkReceived        = 'PNF_OnReceived';
  /// 解密完成通知
  static const String kPortableNetworkDecrypted       = 'PNF_OnDecrypted';
  /// 上传成功通知
  static const String kPortableNetworkUploadSuccess   = 'PNF_OnUploadSuccess';
  /// 下载成功通知
  static const String kPortableNetworkDownloadSuccess = 'PNF_OnDownloadSuccess';
  /// 错误通知（加密/解密/上传/下载失败）
  static const String kPortableNetworkError           = 'PNF_OnError';
}

// ------------------------------
//  PNF状态枚举
// ------------------------------

/// PNF文件传输状态枚举
/// 覆盖上传/下载全生命周期，不同阶段对应不同状态
enum PortableNetworkStatus {
  //                Upload | Download
  //              ---------|---------
  init,         //    0    |    0    - 初始状态
  encrypting,   //    1    |         - 上传中：加密文件
  waiting,      //    2    |    1    - 等待上传/下载
  uploading,    //    3    |         - 上传中：发送数据
  downloading,  //         |    2    - 下载中：接收数据
  decrypting,   //         |    3    - 下载中：解密数据
  success,      //    4    |    4    - 上传/下载成功
  error,        //    -    |    -    - 过程出错
}

// ------------------------------
//  工具方法
// ------------------------------

/// 私有工具方法：获取对象的运行时类型名称（用于调试）
String _runtimeType(Object object, String className) {
  assert(() {
    className = object.runtimeType.toString();
    return true;
  }());
  return className;
}

// ------------------------------
//  PNF核心包装器（抽象类）
// ------------------------------

/// PNF文件包装器基类
/// 封装PNF对象的通用能力：状态管理、路径生成、通知分发、文件缓存
abstract class PortableNetworkWrapper {
  /// 构造方法
  /// [pnf] - PNF文件对象（PortableNetworkFile）
  PortableNetworkWrapper(this.pnf);

  /// 被包装的PNF文件对象
  final PortableNetworkFile pnf;

  /// 获取运行时类型名称（用于toString）
  String get className => _runtimeType(this, 'PortableNetworkWrapper');

  /// 字符串描述（便于调试）
  @override
  String toString() {
    String clazz = className;
    Uri? url = pnf.url;
    if (url != null) {
      return '<$clazz URL="$url" />';
    }
    String? filename = pnf.filename;
    Uint8List? data = pnf.data;
    return '<$clazz filename="$filename" length="${data?.length}" />';
  }

  // ------------------------------
  //  状态管理
  // ------------------------------

  /// PNF传输状态（初始为init）
  PortableNetworkStatus _status = PortableNetworkStatus.init;
  /// 获取当前状态（对外只读）
  PortableNetworkStatus get status => _status;
  /// 设置状态并发送状态变更通知
  /// [current] - 新状态
  Future<void> setStatus(PortableNetworkStatus current) async {
    PortableNetworkStatus previous = _status;
    _status = current;
    // 状态变更时发送通知
    if (previous != current) {
      await postNotification(NotificationNames.kPortableNetworkStatusChanged, {
        'PNF': pnf,
        'URL': pnf.url,
        'previous': previous,
        'current': current,
      });
    }
  }

  // ------------------------------
  //  路径生成（通用）
  // ------------------------------

  /// 获取缓存文件路径（"{caches}/files/{AA}/{BB}/{filename}"）
  /// 返回值：Future<String?> - 完整路径（null表示文件名错误）
  Future<String?> get cacheFilePath async {
    String? name = filename;
    if (name == null) {
      assert(false, 'PNF error: $pnf');
      return null;
    }
    // 校验文件名是否为哈希格式（确保是加密后的文件名）
    assert(URLHelper.isFilenameEncoded(name), 'filename error: $name, $pnf');
    // 调用FileCache生成分层缓存路径
    return await fileCache.getCacheFilePath(name);
  }

  /// 获取文件名（由子类实现：下载/上传逻辑不同）
  String? get filename;

  /// 获取文件数据（由子类实现：下载/上传逻辑不同）
  Future<Uint8List?> get fileData;

  /// 获取文件缓存管理器（由子类实现）
  FileCache get fileCache;

  // ------------------------------
  //  通知分发
  // ------------------------------

  /// 发送通知（由子类实现具体的通知分发逻辑）
  /// [name] - 通知名称（NotificationNames常量）
  /// [info] - 附加信息（可选）
  Future<void> postNotification(String name, [Map? info]);

}

// ------------------------------
//  下载相关混入（DownloadMixin）
// ------------------------------

/// 下载相关能力混入（给PortableNetworkWrapper添加下载能力）
/// 实现下载场景下的文件名、文件数据、临时路径生成逻辑
mixin DownloadMixin on PortableNetworkWrapper {

  /// 获取下载场景的文件名（优先使用PNF的filename，无则从URL生成）
  @override
  String? get filename {
    Uri? url = pnf.url;
    String? name = pnf.filename;
    if (name != null || url == null) {
      return name;
    }
    // 从URL生成哈希文件名
    return URLHelper.filenameFromURL(url, null);
  }

  /// 获取下载场景的文件数据（优先从PNF获取，无则从缓存加载）
  @override
  Future<Uint8List?> get fileData async {
    Uint8List? data = pnf.data;
    if (data == null || data.isEmpty) {
      // PNF无数据 → 从缓存路径加载
      String? path = await cacheFilePath;
      if (path != null && await Paths.exists(path)) {
        data = await ExternalStorage.loadBinary(path);
      }
    }
    return data;
  }

  /// 获取加密后的文件名（用于临时路径生成）
  /// 返回值：String? - 哈希后的文件名（null表示URL为空）
  String? get encryptedFilename {
    String? name = pnf.filename;
    // 从URL生成哈希文件名
    Uri? url = pnf.url;
    if (url == null) {
      assert(false, 'PNF error: $pnf');
      return null;
    }
    return URLHelper.filenameFromURL(url, name);
  }

  /// 获取上传临时路径（"{tmp}/upload/{filename}"）
  /// 返回值：Future<String?> - 完整路径（null表示文件名错误）
  Future<String?> get uploadFilePath async {
    String? name = encryptedFilename;
    if (name == null || name.isEmpty) {
      assert(false, 'PNF error: $pnf');
      return null;
    }
    return await fileCache.getUploadFilePath(name);
  }

  /// 获取下载临时路径（"{tmp}/download/{filename}"）
  /// 返回值：Future<String?> - 完整路径（null表示文件名错误）
  Future<String?> get downloadFilePath async {
    String? name = encryptedFilename;
    if (name == null || name.isEmpty) {
      assert(false, 'PNF error: $pnf');
      return null;
    }
    return await fileCache.getDownloadFilePath(name);
  }

}

// ------------------------------
//  上传相关混入（UploadMixin）
// ------------------------------

/// 上传相关能力混入（给PortableNetworkWrapper添加上传能力）
/// 实现上传场景下的文件名、文件数据、加密、上传URL构建逻辑
mixin UploadMixin on PortableNetworkWrapper {

  /// 获取加密机（用于构建带签名的上传URL，由子类实现）
  Enigma get enigma;

  /// 获取上传场景的文件名（直接使用PNF的filename）
  @override
  String? get filename => pnf.filename;

  /// 获取上传场景的文件数据（优先从PNF获取，无则从缓存加载，有则保存到缓存）
  @override
  Future<Uint8List?> get fileData async {
    String? path = await cacheFilePath;
    Uint8List? data = pnf.data;
    if (data == null || data.isEmpty) {
      // PNF无数据 → 从缓存路径加载
      if (path != null && await Paths.exists(path)) {
        data = await ExternalStorage.loadBinary(path);
      }
    } else if (path == null) {
      // 缓存路径为空 → 断言
      assert(false, 'failed to get file path: $pnf');
    } else {
      // PNF有数据 → 保存到缓存并清理PNF中的数据（节省内存）
      int cnt = await ExternalStorage.saveBinary(data, path);
      if (cnt == data.length) {
        pnf.data = null;
      } else {
        assert(false, 'failed to save data: $path');
      }
    }
    return data;
  }

  /// 获取加密后的文件名（从enigma中提取）
  /// 返回值：String? - 加密后的哈希文件名
  String? get encryptedFilename {
    Map? extra = pnf['enigma'];
    return extra?['filename'];
  }

  /// 获取上传临时路径（"{tmp}/upload/{filename}"）
  /// 返回值：Future<String?> - 完整路径（null表示文件名错误）
  Future<String?> get uploadFilePath async {
    String? name = encryptedFilename;
    if (name == null || name.isEmpty) {
      // assert(false, 'PNF error: $pnf');
      return null;
    }
    return await fileCache.getUploadFilePath(name);
  }

  /// 构建上传临时路径（封装FileCache的方法）
  /// [filename] - 加密后的文件名
  /// 返回值：Future<String> - 完整路径
  Future<String> buildUploadFilePath(String filename) async =>
      await fileCache.getUploadFilePath(filename);

  /// 从加密数据生成哈希文件名（调用URLHelper）
  /// [data] - 加密后的字节数据
  /// [name] - 原始文件名（用于提取扩展名）
  /// 返回值：String - 哈希后的文件名
  String buildFilename(Uint8List data, String name) =>
      URLHelper.filenameFromData(data, name);

  /// 构建带签名的上传URL（使用Enigma生成）
  /// [data] - 加密后的字节数据
  /// 返回值：Uri? - 上传API地址（null表示参数错误）
  Uri? buildUploadURL(Uint8List data) {
    // 0. 检查enigma缓存
    Map? extra = pnf['enigma'];
    if (extra == null) {
      return null;
    }
    String? url = extra['URL'];
    if (url != null) {
      // 已缓存上传URL → 直接解析返回
      return HTTPClient.parseURL(url);
    }

    // 1. 提取enigma中的上传信息
    String? api = extra['API'];       // 上传API基础地址
    ID? sender = ID.parse(extra['sender']);  // 发送者ID
    if (api == null || sender == null) {
      assert(false, 'upload info error: $pnf');
      return null;
    } else if (api.isEmpty || data.isEmpty) {
      assert(false, 'upload info error: $pnf');
      return null;
    }

    // 2. 获取加密机的密钥和前缀
    var pair = enigma.fetch(api);
    String? prefix = pair?.first;    // Enigma前缀
    Uint8List? secret = pair?.second;// 签名密钥
    if (prefix == null || secret == null) {
      assert(false, 'failed to fetch enigma: $api, $enigma');
      return null;
    } else if (prefix.isEmpty || secret.isEmpty) {
      assert(false, 'enigma error: $api, $enigma');
      return null;
    }

    // 3. 构建带签名的上传URL
    url = enigma.build(api,
      sender, data: data, secret: secret, enigma: prefix,
    );
    Uri? remote = HTTPClient.parseURL(url);
    if (remote != null) {
      // 缓存生成的URL到enigma中
      extra['URL'] = url;
    }
    return remote;
  }

  /// 获取/生成加密密钥（AES）
  /// 返回值：SymmetricKey - 对称加密密钥
  SymmetricKey get password {
    dynamic pwd = pnf.password;
    if (pwd is SymmetricKey) {
      // PNF已有密钥 → 复用
      return pwd;
    }
    // 无密钥 → 生成新的AES密钥并设置到PNF
    pwd = SymmetricKey.generate('AES');  // SymmetricAlgorithms.AES
    pnf.password = pwd;
    return pwd;
  }

}