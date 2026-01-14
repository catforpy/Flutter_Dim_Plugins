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

import 'package:dimsdk/core.dart';
import 'package:dimsdk/dimp.dart';

/// DIM 协议消息序列化工具接口
/// 核心作用：将消息/密钥转换为字节数组（便于网络传输），同时集成字段压缩功能，
/// 减少消息体积，提升传输效率；支持逆向反序列化，还原为业务可解析的 Map 结构。
/// 核心流程：
/// 压缩序列化：Map → 字段压缩（Shortener）→ JSON 字符串 → UTF-8 字节数组；
/// 解压缩反序列化：UTF-8 字节数组 → JSON 字符串 → Map → 字段还原（Shortener）。
abstract interface class Compressor {

  /// 压缩并序列化消息内容
  /// 核心逻辑：先压缩内容字段名，再序列化为 JSON 字符串，最后编码为 UTF-8 字节数组。
  /// @param content - 原始消息内容 Map（长字段名）
  /// @param key - 对称密钥 Map（用于关联压缩配置）
  /// @return 压缩后的字节数组（网络传输用）
  Uint8List compressContent(Map content, Map key);

  /// 反序列化并还原消息内容
  /// 核心逻辑：先解码为 JSON 字符串，再解析为 Map，最后还原字段名。
  /// @param data - 压缩后的字节数组
  /// @param key - 对称密钥 Map（用于关联解压缩配置）
  /// @return 还原后的内容 Map；解析失败返回 null
  Map? extractContent(Uint8List data, Map key);

  /// 压缩并序列化对称密钥
  /// 核心逻辑：先压缩密钥字段名，再序列化为 JSON 字符串，最后编码为 UTF-8 字节数组。
  /// @param key - 原始对称密钥 Map（长字段名）
  /// @return 压缩后的字节数组（网络传输用）
  Uint8List compressSymmetricKey(Map key);

  /// 反序列化并还原对称密钥
  /// 核心逻辑：先解码为 JSON 字符串，再解析为 Map，最后还原字段名。
  /// @param data - 压缩后的字节数组
  /// @return 还原后的密钥 Map；解析失败返回 null
  Map? extractSymmetricKey(Uint8List data);

  /// 压缩并序列化可靠消息
  /// 核心逻辑：先压缩消息字段名，再序列化为 JSON 字符串，最后编码为 UTF-8 字节数组。
  /// @param msg - 原始可靠消息 Map（长字段名）
  /// @return 压缩后的字节数组（网络传输用）
  Uint8List compressReliableMessage(Map msg);

  /// 反序列化并还原可靠消息
  /// 核心逻辑：先解码为 JSON 字符串，再解析为 Map，最后还原字段名。
  /// @param data - 压缩后的字节数组
  /// @return 还原后的消息 Map；解析失败返回 null
  Map? extractReliableMessage(Uint8List data);
}


/// 消息序列化工具实现类
/// 实现 Compressor 接口，整合 Shortener 完成字段压缩/还原，
/// 是 DIM 协议消息网络传输的核心工具。
class MessageCompressor implements Compressor{

  /// 构造方法：关联字段压缩工具
  /// @param shortener - 字段名压缩/还原工具（Shortener 实例）
  MessageCompressor(this.shortener);

  /// 字段压缩工具（核心依赖）
  final Shortener shortener;

  // ======================== 消息内容压缩/反序列化 ========================

  @override
  Uint8List compressContent(Map content,Map key){
    // 步骤1：压缩内容字段名（长->短）
    content = shortener.compressContent(content);
    // 步骤2：Map 序列化为 JSON 字符串
    String json = JSONMap.encode(content);
    // 步骤3：JSON 字符串编码为 UTF-8 字节数组
    return UTF8.encode(json);
  }

  @override
  Map? extractContent(Uint8List data,Map key){
    // 步骤1：字节数组解码为 JSON 字符串
    var json = UTF8.decode(data);
    if (json == null) {
      assert(false, 'content data error: ${data.length}');
      return null;
    }
    // 步骤2：JSON 字符串解析为Map
    var info = JSONMap.decode(json);
    if(info != null){
      // 步骤3：还原字段名（短->长）
      info = shortener.extractContent(info);
    }
    return info;
  }

  // ======================== 对称密钥压缩/反序列化 ========================

  @override
  Uint8List compressSymmetricKey(Map key){
    // 步骤1：压缩秘钥字段名（长 -> 短）
    key = shortener.compressSymmetricKey(key);
    // 步骤2：Map 序列化为 JSON 字符串
    String json = JSONMap.encode(key);
    // 步骤3：JSON 字符串编码为 UTF-8 字节数组
    return UTF8.encode(json);
  }

  @override
  Map? extractSymmetricKey(Uint8List data) {
    // 步骤1：字节数组解码为 JSON 字符串
    var json = UTF8.decode(data);
    if (json == null) {
      assert(false, 'symmetric key error: ${data.length}');
      return null;
    }
    // 步骤2：JSON 字符串解析为 Map
    var key = JSONMap.decode(json);
    if (key != null) {
      // 步骤3：还原字段名（短→长）
      key = shortener.extractSymmetricKey(key);
    }
    return key;
  }

  // ======================== 可靠消息压缩/反序列化 ========================

  @override
  Uint8List compressReliableMessage(Map msg) {
    // 步骤1：压缩消息字段名（长→短）
    msg = shortener.compressReliableMessage(msg);
    // 步骤2：Map 序列化为 JSON 字符串
    String json = JSONMap.encode(msg);
    // 步骤3：JSON 字符串编码为 UTF-8 字节数组
    return UTF8.encode(json);
  }

  @override
  Map? extractReliableMessage(Uint8List data) {
    // 步骤1：字节数组解码为 JSON 字符串
    var json = UTF8.decode(data);
    if (json == null) {
      assert(false, 'reliable message error: ${data.length}');
      return null;
    }
    // 步骤2：JSON 字符串解析为 Map
    var msg = JSONMap.decode(json);
    if (msg != null) {
      // 步骤3：还原字段名（短→长）
      msg = shortener.extractReliableMessage(msg);
    }
    return msg;
  }
}