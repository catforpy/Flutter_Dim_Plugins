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

import 'package:dimp/dimp.dart';
import 'package:dimp/dkd.dart';

/// 文件消息基础接口
/// 核心设计：
/// 1. 支持两种文件传输方式：本地二进制（data）/CDN远程链接（url），按需选择
/// 2. 安全机制：CDN传输时文件需加密，通过password字段传递解密密钥
/// 3. 扩展性：作为图片/音频/视频消息的父接口，统一文件类消息的核心逻辑
/// 
/// 标准数据格式：
/// {
///     type : i2s(0x10),  // 消息类型标识（0x10=通用文件，图片/音频/视频有专属值）
///     sn   : 123,        // 消息唯一序列号（用于去重/溯源）
/// 
///     data     : "...",        // 本地文件二进制数据（Base64编码）
///     filename : "photo.png",  // 文件名（含后缀，用于解析文件类型）
/// 
///     URL      : "http://...", // CDN远程下载链接（优先级高于data）
///     key      : {             // CDN文件解密密钥（对称加密，如AES）
///         algorithm : "AES",   // 加密算法标识（DES/AES等）
///         data      : "{BASE64_ENCODE}", // 密钥二进制数据的Base64编码
///         ...                  // 扩展字段（如密钥长度、偏移量）
///     }
/// }
abstract interface class FileContent implements Content{
  
  /// 获取文件二进制数据（本地传输用）
  /// 说明：返回Uint8List原始二进制，无需手动解码Base64（内部已处理）
  Uint8List? get data;

  /// 设置文件二进制数据
  /// 注意：设置后会自动将数据Base64编码存入消息字典
  set data(Uint8List? fileData);

  /// 获取文件名（含扩展名）
  /// 用途：前端解析文件类型（如.png/.mp4）、后端存储时命名文件
  String? get filename;

  /// 设置文件名
  set filename(String? name);

  /// 获取CDN远程下载链接
  /// 优先级：url存在时，优先从CDN下载，而非使用本地data
  Uri? get url;

  /// 设置CDN远程下载链接
  set url(Uri? remote);

  /// 获取CDN文件解密密钥（对称密钥）
  /// 场景：文件上传CDN前用该秘钥加密，接收方通过此秘钥解密
  DecryptKey? get password;

  /// 设置CDN文件解密密钥
  set password(DecryptKey? key);

  // -------------------------- 工厂方法（便捷创建不同类型文件消息） --------------------------
  /// 按消息类型创建文件消息（通用入口）
  /// @param msgType   消息类型（ContentType.FILE/IMAGE/AUDIO/VIDEO）
  /// @param data      本地文件数据（可选，url优先时可省略）
  /// @param filename  文件名（可选，建议传递，便于解析文件类型）
  /// @param url       CDN链接（可选，优先级高于data）
  /// @param password  解密密钥（仅CDN传输时需要）
  /// @return 对应类型的文件消息实例（ImageContent/AudioContent等）
  static FileContent create(String msgType,{TransportableData? data,String? filename,
  Uri? url,DecryptKey? password}){
    // 按类型分发到具体实现类，符合“开闭原则”
    if (msgType == ContentType.IMAGE) {
      return ImageFileContent.from(data, filename, url, password);
    } else if (msgType == ContentType.AUDIO) {
      return AudioFileContent.from(data, filename, url, password);
    } else if (msgType == ContentType.VIDEO) {
      return VideoFileContent.from(data, filename, url, password);
    }
    // 默认创建通用文件消息
    return BaseFileContent.from(msgType, data, filename, url, password);
  }

  /// 创建通用文件信息（快捷方法）
  /// 场景：传输非图片/音频/视频的通用文件（如文档、压缩包）
  static FileContent file({TransportableData? data,String? filename,
                          Uri? url,DecryptKey? password}){
    return BaseFileContent.from(ContentType.FILE, data, filename, url, password);
  }

  /// 创建图片信息（快捷方法）
  /// 场景：发送图片，自动关联ImageContent接口（含缩略图字段）
  static ImageContent image({TransportableData? data, String? filename,
                             Uri? url, DecryptKey? password}) {
    return ImageFileContent.from(data, filename, url, password);
  }

  /// 创建音频信息（快捷方法）
  /// 场景：发送语音信息，自动关联AudioContent接口（含语语音转文字字段）
  static AudioContent audio({TransportableData? data, String? filename,
                             Uri? url, DecryptKey? password}) {
    return AudioFileContent.from(data, filename, url, password);
  }

  /// 创建视频消息（快捷方法）
  /// 场景：发送视频，自动关联VideoContent接口（含封面图字段）
  static VideoContent video({TransportableData? data, String? filename,
                             Uri? url, DecryptKey? password}) {
    return VideoFileContent.from(data, filename, url, password);
  }
}

/// 图片消息接口（继承FileContent）
/// 扩展设计：新增缩略图字段，适配图片预览场景（无需加载原图）
/// 
/// 扩展数据格式（在FileContent基础上新增）：
/// {
///     ... // 继承FileContent所有字段
///     thumbnail : "data:image/jpeg;base64,..." // 缩略图（Base64编码的小尺寸图片）
/// }
abstract interface class ImageContent implements FileContent {
  /// 获取图片缩略图（PNF格式，封装Base64/URL两种存储方式）
  /// 用途：聊天列表快速预览图片，减少流量消耗
  PortableNetworkFile? get thumbnail;
  
  /// 设置图片缩略图
  /// 说明：支持传入本地图片Base64或远程URL，内部自动处理格式
  set thumbnail(PortableNetworkFile? img);
}

/// 音频消息接口（继承FileContent）
/// 扩展设计：新增语音转文字字段，适配语音消息转文字的通用需求
/// 
/// 扩展数据格式（在FileContent基础上新增）：
/// {
///     ... // 继承FileContent所有字段
///     text : "..." // 语音识别文本（ASR），可选（未识别则为空）
/// }
abstract interface class AudioContent implements FileContent {
  /// 获取语音识别文本（ASR结果）
  /// 场景：静音环境下查看语音内容、搜索语音消息
  String? get text;
  
  /// 设置语音识别文本
  set text(String? asr);
}

/// 视频消息接口（继承FileContent）
/// 扩展设计：新增封面图字段，适配视频预览场景（无需加载完整视频）
/// 
/// 扩展数据格式（在FileContent基础上新增）：
/// {
///     ... // 继承FileContent所有字段
///     snapshot : "data:image/jpeg;base64,..." // 视频封面图（Base64编码）
/// }
abstract interface class VideoContent implements FileContent {
  /// 获取视频封面图（PNF格式）
  /// 用途：聊天列表预览视频封面，点击后加载完整视频
  PortableNetworkFile? get snapshot;
  
  /// 设置视频封面图
  set snapshot(PortableNetworkFile? img);
}