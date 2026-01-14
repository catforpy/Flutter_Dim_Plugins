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

import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import 'package:dim_client/sdk.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/ok.dart' as lnc;

import '../common/constants.dart';

import 'loader.dart';

/// 便携网络文件加载器工厂（单例）：管理加载器缓存，避免重复创建
class PortableNetworkFactory {
  factory PortableNetworkFactory() => _instance;
  static final PortableNetworkFactory _instance =
      PortableNetworkFactory._internal();
  PortableNetworkFactory._internal();

  /// 加载器缓存：URL/文件名 -> 加载器（弱引用）
  final Map<String, PortableFileLoader> _loaders = WeakValueMap();

  /// 获取PNF对应的加载器
  /// [pnf] 便携网络文件对象
  /// 返回加载器
  PortableFileLoader getLoader(PortableNetworkFile pnf) {
    PortableFileLoader? runner;
    var filename = pnf.filename;
    var url = pnf.url;
    if (url != null) {
      // 从URL获取加载器
      runner = _loaders[url.toString()];
      if (runner == null) {
        runner = _createLoader(pnf);
        _loaders[url.toString()] = runner;
      }
    } else if (filename != null) {
      // 从文件名获取加载器
      runner = _loaders[filename];
      if (runner == null) {
        runner = _createUpper(pnf);
        _loaders[filename] = runner;
      }
    } else {
      throw FormatException('PNF error: $pnf');
    }
    return runner;
  }

  /// 创建下载加载器（针对有URL的PNF）
  /// [pnf] 便携网络文件对象
  /// 返回加载器
  PortableFileLoader _createLoader(PortableNetworkFile pnf) {
    PortableFileLoader loader = PortableFileLoader(pnf);
    if (pnf.data == null) {
      /*await */
      loader.prepare(); // 预加载（异步）
    }
    return loader;
  }

  /// 创建上传加载器（针对有文件名但无URL的PNF）
  /// [pnf] 便携网络文件对象
  /// 返回加载器
  PortableFileLoader _createUpper(PortableNetworkFile pnf) {
    PortableFileLoader loader = PortableFileLoader(pnf);
    if (pnf['enigma'] != null) {
      /*await */
      loader.prepare(); // 预加载（异步）
    }
    return loader;
  }
}

/// 便携网络文件视图基类：所有PNF视图的父类，持有加载器
abstract class PortableNetworkView<T> extends StatefulWidget {
  const PortableNetworkView(this.loader, {super.key});

  /// 文件加载器
  final PortableFileLoader loader;

  /// 获取PNF对象（优先下载任务，其次上传任务）
  PortableNetworkFile? get pnf {
    var task = loader.downloadTask;
    if (task != null) {
      return task.pnf;
    } else {
      return loader.uploadTask?.pnf;
    }
  }
}

/// 便携网络文件视图状态基类：监听PNF相关通知，自动刷新UI
abstract class PortableNetworkState<T extends PortableNetworkView>
    extends State<T>
    with Logging
    implements lnc.Observer {
  PortableNetworkState() {
    // 注册PNF相关通知监听
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kPortableNetworkStatusChanged);
    nc.addObserver(this, NotificationNames.kPortableNetworkEncrypted);
    nc.addObserver(this, NotificationNames.kPortableNetworkSendProgress);
    nc.addObserver(this, NotificationNames.kPortableNetworkReceiveProgress);
    nc.addObserver(this, NotificationNames.kPortableNetworkReceived);
    nc.addObserver(this, NotificationNames.kPortableNetworkDecrypted);
    nc.addObserver(this, NotificationNames.kPortableNetworkDownloadSuccess);
    nc.addObserver(this, NotificationNames.kPortableNetworkError);
  }

  @override
  void dispose() {
    // 移除通知监听，避免内存泄漏
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kPortableNetworkError);
    nc.removeObserver(this, NotificationNames.kPortableNetworkDownloadSuccess);
    nc.removeObserver(this, NotificationNames.kPortableNetworkDecrypted);
    nc.removeObserver(this, NotificationNames.kPortableNetworkReceived);
    nc.removeObserver(this, NotificationNames.kPortableNetworkReceiveProgress);
    nc.removeObserver(this, NotificationNames.kPortableNetworkSendProgress);
    nc.removeObserver(this, NotificationNames.kPortableNetworkEncrypted);
    nc.removeObserver(this, NotificationNames.kPortableNetworkStatusChanged);
    super.dispose();
  }

  /// 接收PNF相关通知，处理状态变化并刷新UI
  /// 核心逻辑：
  /// 1. 解析通知的基础信息（名称、携带参数、PNF对象）；
  /// 2. 校验通知是否属于当前视图的PNF（避免处理其他文件的通知）；
  /// 3. 根据不同通知类型处理业务逻辑、打印日志；
  /// 4. 触发UI刷新，保证视图与文件状态同步。
  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    // 1. 解析通知核心信息
    // 通知名称：标识当前通知的类型（如下载进度、加密完成、错误等）
    String name = notification.name;
    // 通知携带的业务参数：Map类型，存储不同通知类型对应的具体数据
    Map? userInfo = notification.userInfo;
    // 从参数中提取PNF对象：当前通知关联的便携网络文件
    PortableNetworkFile? pnf = userInfo?['PNF'];
    // 提取PNF的文件名：用于匹配当前视图的文件、日志打印
    String? filename = pnf?.filename;
    // 提取PNF的序列号（sn=serial number）：唯一标识一个PNF文件，用于精准匹配
    int? sn = pnf?['sn'];
    // 提取PNF的网络地址：用于匹配当前视图的文件、日志打印
    Uri? url = userInfo?['URL'];

    // 2. 校验通知是否匹配当前视图的PNF（核心：避免处理其他文件的通知）
    bool isMatched = false;
    if (notification.sender == widget.loader) {
      // 匹配条件1：通知发送者是当前视图持有的加载器（最优先匹配）
      isMatched = true;
    } else if (sn != null && sn == widget.pnf?['sn']) {
      // 匹配条件2：通知关联PNF的序列号 = 当前视图PNF的序列号（唯一标识匹配）
      isMatched = true;
    } else if (url != null && url == widget.pnf?.url) {
      // 匹配条件3：通知关联PNF的URL = 当前视图PNF的URL（下载场景匹配）
      isMatched = true;
    } else if (filename != null && filename == widget.pnf?.filename) {
      // 匹配条件4：通知关联PNF的文件名 = 当前视图PNF的文件名（上传场景匹配）
      isMatched = true;
    }

    // 2.1 若通知不匹配，直接忽略（避免处理无关通知导致UI错误刷新）
    if (!isMatched) {
      return;
    }
    // 3. 根据不同通知类型处理业务逻辑
    else if (name == NotificationNames.kPortableNetworkStatusChanged) {
      // 通知类型：PNF文件状态变更（如：未开始→下载中、上传中→成功）
      // previous：状态变更前的旧状态（如"idle"、"downloading"）
      var previous = userInfo?['previous'];
      // current：状态变更后的新状态（如"downloading"、"success"）
      var current = userInfo?['current'];
      // 打印状态变更日志，便于调试追踪文件状态流转
      logDebug('[PNF] onStatusChanged: $previous -> $current, $url');
    } else if (name == NotificationNames.kPortableNetworkEncrypted) {
      // 通知类型：PNF文件加密完成（上传前的加密操作）
      // data：加密后的文件二进制数据（Uint8List类型）
      Uint8List? data = userInfo?['data'];
      // path：加密后文件的本地存储路径（临时文件路径）
      String? path = userInfo?['path'];
      // 打印加密结果日志，包含数据长度、存储路径、文件URL
      logInfo(
        '[PNF] onEncrypted: ${data?.length} bytes into file "$path", $url',
      );
    } else if (name == NotificationNames.kPortableNetworkSendProgress) {
      // 通知类型：PNF文件上传进度更新
      // count：已上传的字节数（当前进度）
      int? count = userInfo?['count'];
      // total：文件总字节数（总进度）
      int? total = userInfo?['total'];
      // 打印上传进度日志，格式：已上传/总大小，关联文件名
      logInfo('[PNF] onSendProgress: $count/$total, $filename');
    } else if (name == NotificationNames.kPortableNetworkUploadSuccess) {
      // 通知类型：PNF文件上传成功
      // data：最终上传的文件二进制数据（可选，用于校验）
      Uint8List? data = userInfo?['data'];
      // 打印上传成功日志，包含数据长度、文件URL
      logInfo('[PNF] onSuccess: ${data?.length} bytes, $url');
    } else if (name == NotificationNames.kPortableNetworkReceiveProgress) {
      // 通知类型：PNF文件下载进度更新
      // count：已下载的字节数（当前进度）
      int? count = userInfo?['count'];
      // total：文件总字节数（总进度）
      int? total = userInfo?['total'];
      // 打印下载进度日志，格式：已下载/总大小，关联文件URL
      logDebug('[PNF] onReceiveProgress: $count/$total, ${pnf?.url}');
    } else if (name == NotificationNames.kPortableNetworkReceived) {
      // 通知类型：PNF文件下载完成（未解密）
      // data：下载后的加密文件二进制数据
      Uint8List? data = userInfo?['data'];
      // tmpPath：下载后临时文件的本地存储路径（解密前的临时文件）
      String? tmpPath = userInfo?['path'];
      // 打印下载完成日志，包含数据长度、临时文件路径
      logInfo('[PNF] onReceived: ${data?.length} bytes into file "$tmpPath"');
    } else if (name == NotificationNames.kPortableNetworkDecrypted) {
      // 通知类型：PNF文件解密完成（下载后解密）
      // data：解密后的原始文件二进制数据（可直接使用）
      Uint8List? data = userInfo?['data'];
      // path：解密后文件的本地存储路径（最终可用的文件路径）
      String? path = userInfo?['path'];
      // 打印解密结果日志，包含数据长度、存储路径、文件URL
      logInfo(
        '[PNF] onDecrypted: ${data?.length} bytes into file "$path", $url',
      );
    } else if (name == NotificationNames.kPortableNetworkDownloadSuccess) {
      // 通知类型：PNF文件下载+解密全流程成功
      // data：最终可用的文件二进制数据（解密后）
      Uint8List? data = userInfo?['data'];
      // 打印下载成功日志，包含数据长度、文件URL
      logDebug('[PNF] onSuccess: ${data?.length} bytes, $url');
    } else if (name == NotificationNames.kPortableNetworkError) {
      // 通知类型：PNF操作出错（下载/上传/加密/解密失败）
      // error：错误描述信息（字符串类型，说明失败原因）
      String? error = userInfo?['error'];
      // 打印错误日志，包含错误信息、文件URL、当前视图实例（便于定位问题）
      logError('[PNF] onError: $error, $url, $this');
    } else {
      // 异常分支：收到未定义的通知类型，触发断言（开发阶段发现未知通知）
      assert(false, 'LNC name error: $name');
    }

    // 4. 刷新UI（核心操作）
    // mounted：判断当前State是否还关联到Widget树（避免已销毁的State刷新UI）
    if (mounted) {
      // 触发State刷新，更新视图显示（如进度条、文件预览、状态提示等）
      setState(() {});
    }
  }
}
