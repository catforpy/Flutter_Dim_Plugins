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

import 'package:dimp/dkd.dart';
import 'package:dimp/mkm.dart';
import 'package:dimp/src/crypto/pnf.dart';

///
/// 通用文件消息类（继承消息内容基类）
/// 封装所有文件类型消息的通用逻辑（数据、文件名、URL、解密密钥），
/// 依赖BaseFileWrapper处理文件字段的解析/序列化
///
class BaseFileContent extends BaseContent implements FileContent {
  /// 构造方法1：从字典初始化（解析网络传输的文件消息）
  BaseFileContent([super.dict]) {
    _wrapper = BaseFileWrapper(toMap());
  }

  /// 初始化内部的BaseFilewrapper,复用文件字段处理逻辑
  late final BaseFileWrapper _wrapper;

  /// 内部文件包装器（复用文件字段的解析/序列化逻辑）
  /// 构造方法2：从文件信息初始化（创建新文件消息）
  /// @param msgType - 消息类型（如ContentType.IMAGE,默认ContentType.FILE）
  /// @param data - 文件二进制数据（可选）
  /// @param filename - 文件名（可选）
  /// @param url - CDN下载地址（可选）
  /// @param password - 解密密钥（可选，CDN文件必填）
  BaseFileContent.from(
    String? msgType,
    TransportableData? data,
    String? filename,
    Uri? url,
    DecryptKey? password,
  ) : super.fromType(msgType ?? ContentType.FILE) {
    _wrapper = BaseFileWrapper(toMap());
    // 填充文件数据
    if (data != null) {
      _wrapper.data = data;
    }
    // 填充文件名
    if (filename != null) {
      _wrapper.filename = filename;
    }
    // 填充CDN地址
    if (url != null) {
      _wrapper.url = url;
    }
    // 填充解密密钥
    if (password != null) {
      _wrapper.password = password;
    }
  }

  /// 获取文件二进制数据（null表示无数据）
  @override
  Uint8List? get data => _wrapper.data?.data;

  /// 设置文件二进制数据（同步更新到包装器）
  @override
  set data(Uint8List? binary) => _wrapper.setDate(binary);

  /// 获取文件名（null表示未设置）
  @override
  String? get filename => _wrapper.filename;

  /// 设置文件名（同步更新到包装器）
  @override
  set filename(String? name) => _wrapper.filename = name;

  /// 获取CDN下载地址（null表示未设置）
  @override
  Uri? get url => _wrapper.url;

  /// 设置CDN下载地址（同步更新到包装器）
  @override
  set url(Uri? remote) => _wrapper.url = remote;

  /// 获取解密密钥（null表示无需解密）
  @override
  DecryptKey? get password => _wrapper.password;

  /// 设置解密密钥（同步更新到包装器）
  @override
  set password(DecryptKey? key) => _wrapper.password = key;
}

///
/// 图片消息类（继承通用文件消息）
/// 扩展缩略图字段，适配图片消息的可视化展示
///
class ImageFileContent extends BaseFileContent implements ImageContent {
  /// 构造方法1：从字典初始化（解析网络传输的图片消息）
  ImageFileContent([super.dict]);

  /// 缓存：缩略图（避免重复解析）
  PortableNetworkFile? _thumbnail;

  /// 构造方法2：从图片信息初始化（创建新图片消息）
  /// @param data - 图片二进制数据（可选）
  /// @param filename - 文件名（可选）
  /// @param url - CDN下载地址（可选）
  /// @param password - 解密密钥（可选，CDN文件必填）
  ImageFileContent.from(
    TransportableData? data,
    String? filename,
    Uri? url,
    DecryptKey? password,
  ) : super.from(ContentType.IMAGE, data, filename, url, password);

  /// 获取缩略图（null表示未设置）
  @override
  PortableNetworkFile? get thumbnail {
    PortableNetworkFile? img = _thumbnail;
    if (img == null) {
      var base64 = getString('thumbnail');
      img = _thumbnail = PortableNetworkFile.parse(base64);
    }
    return img;
  }

  /// 设置缩略图（同步更新字典中的thumbnail字段）
  @override
  set thumbnail(PortableNetworkFile? img) {
    if (img == null) {
      remove('thumbnail');
    } else {
      this['thumbnail'] = img.toObject();
    }
    _thumbnail = img;
  }
}

///
/// 音频消息类（继承通用文件消息）
/// 扩展文本字段（语音转文字），适配语音消息的文字展示
///
class AudioFileContent extends BaseFileContent implements AudioContent {
  /// 构造方法1：从字典初始化（解析网络传输的音频消息）
  AudioFileContent([super.dict]);

  /// 构造方法2：从音频信息初始化（创建新音频消息）
  /// @param data - 音频二进制数据（可选）
  /// @param filename - 文件名（可选）
  /// @param url - CDN下载地址（可选）
  /// @param password - 解密密钥（可选，CDN文件必填）
  AudioFileContent.from(
    TransportableData? data,
    String? filename,
    Uri? url,
    DecryptKey? password,
  ) : super.from(ContentType.AUDIO, data, filename, url, password);

  /// 获取语音转文字内容（null表示未转写）
  @override
  String? get text => getString('text');

  /// 设置语音转文字内容（同步更新字典中的text字段）
  @override
  set text(String? asr) => this['text'] = asr;
}

///
/// 视频消息类（继承通用文件消息）
/// 扩展快照字段（视频封面图），适配视频消息的可视化展示
///
class VideoFileContent extends BaseFileContent implements VideoContent {
  /// 构造方法1：从字典初始化（解析网络传输的视频消息）
  VideoFileContent([super.dict]);

  /// 缓存：视频快照（封面图，避免重复解析）
  PortableNetworkFile? _snapshot;

  /// 构造方法2：从视频信息初始化（创建新视频消息）
  /// @param data - 视频二进制数据（可选）
  /// @param filename - 文件名（可选）
  /// @param url - CDN下载地址（可选）
  /// @param password - 解密密钥（可选，CDN文件必填）
  VideoFileContent.from(
    TransportableData? data,
    String? filename,
    Uri? url,
    DecryptKey? password,
  ) : super.from(ContentType.VIDEO, data, filename, url, password);

  /// 获取视频快照（封面图，null表示未设置）
  @override
  PortableNetworkFile? get snapshot {
    PortableNetworkFile? img = _snapshot;
    if (img == null) {
      var base64 = getString('snapshot');
      img = _snapshot = PortableNetworkFile.parse(base64);
    }
    return img;
  }

  /// 设置视频快照（封面图，同步更新字典中的snapshot字段）
  @override
  set snapshot(PortableNetworkFile? img) {
    if (img == null) {
      remove('snapshot');
    } else {
      this['snapshot'] = img.toObject();
    }
    _snapshot = img;
  }
}
