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

import 'package:flutter/material.dart';

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/pnf.dart';
import 'package:tvbox/lives.dart';

import 'lives.dart';

/// 频道流数据模型
/// 关联直播频道和对应的播放流
class ChannelStream {
  /// 构造函数
  /// [channel] - 直播频道
  /// [stream] - 播放流
  ChannelStream(this.channel, this.stream);

  /// 直播频道
  final LiveChannel channel;
  /// 播放流（可为空）
  final LiveStream? stream;

  /// 重写相等运算符
  @override
  bool operator ==(Object other) {
    if (other is ChannelStream) {
      var src = stream;
      if (src == null) {
        // 流为空时，比较频道是否相等
        return other.channel == channel;
      } else {
        // 流不为空时，比较流是否相等
        return other.stream == src;
      }
    }
    return false;
  }

  /// 重写哈希值计算
  @override
  int get hashCode => stream?.hashCode ?? channel.hashCode;

}

/// 直播盒子核心类
/// 管理直播频道列表、加载直播源、提供频道切换功能
class TVBox extends Dictionary with Logging {
  /// 构造函数
  /// [livesUrl] - 直播源列表地址
  /// [dict] - 初始化数据字典
  TVBox(this.livesUrl, super.dict);

  /// 直播源列表地址
  final Uri livesUrl;

  /// 当前播放的频道流
  ChannelStream? playingItem;

  /// 直播频道分类列表
  List<LiveGenre>? lives;

  /// 频道列表显示/隐藏状态
  bool hidden = false;

  /// 获取直播频道列表视图
  Widget? get view => LiveChannelListPage(this);

  /// 刷新直播频道列表
  /// 返回更新后的频道分类列表
  Future<List<LiveGenre>> refresh() async {
    var helper = _LiveHelper();
    //
    //  0. 保留旧数据，防止加载失败时无数据显示
    //
    var old = lives ?? [];
    lives = null;
    //
    //  1. 从远程地址获取直播源数据
    //
    var text = await helper.httpGet(livesUrl);
    if (text == null || text.isEmpty) {
      // 获取失败，恢复旧数据
      lives = old;
      logError('cannot get lives from $livesUrl');
      return old;
    }
    //
    //  2. 解析直播源数据
    //
    List<LiveGenre> genres = helper.parseLives(text);
    logInfo('got ${genres.length} genres from URL: $livesUrl');
    List<LiveGenre> sections = [];
    // 遍历所有分类
    for (var grp in genres) {
      List<LiveChannel> items = [];
      var channels = grp.channels;
      // 遍历分类下的所有频道
      for (var mem in channels) {
        List<LiveStream> sources = [];
        var streams = mem.streams;
        int index = 0;
        // 遍历频道下的所有播放流
        for (var src in streams) {
          var m3u8 = src.url;
          if (m3u8 == null) {
            // 播放地址为空，跳过并记录警告
            logWarning('channel stream error: "${mem.name}" -> $src');
            continue;
          } else {
            // 有效播放流，索引递增
            index += 1;
          }
          // 为播放流设置索引
          src.setValue('index', index);
          sources.add(src);
        }
        // 只添加有有效播放流的频道
        if (sources.isNotEmpty) {
          items.add(LiveChannel({
            'name': mem.name,
            'streams': sources,
          }));
        }
      }
      // 只添加有有效频道的分类
      if (items.isNotEmpty) {
        sections.add(LiveGenre({
          'title': grp.title,
          'channels': items,
        }));
      }
    }
    // 更新直播频道列表
    lives = sections;
    return sections;
  }

}

/// 直播助手类（单例）
/// 封装HTTP请求和直播源解析功能
class _LiveHelper with Logging {
  /// 工厂方法，返回单例实例
  factory _LiveHelper() => _instance;
  /// 单例实例
  static final _LiveHelper _instance = _LiveHelper._internal();
  /// 私有构造函数
  _LiveHelper._internal();

  //
  //  直播源解析相关
  //

  /// 直播源解析器
  final LiveParser _parser = LiveParser();

  /// 解析直播源文本数据
  /// [text] - 直播源文本内容
  /// 返回解析后的频道分类列表
  List<LiveGenre> parseLives(String text) => _parser.parse(text);

  //
  //  HTTP请求相关
  //

  /// HTTP下载器
  final FileDownloader _http = FileDownloader(HTTPClient());
  /// 直播源缓存，避免重复请求
  final Map<Uri, String> _caches = {};

  /// HTTP GET请求获取文本数据
  /// [url] - 请求地址
  /// 返回解码后的文本内容（UTF8）
  Future<String?> httpGet(Uri url) async {
    // 优先从缓存获取
    String? text = _caches[url];
    if (text == null) {
      // 缓存未命中，从远程下载
      Uint8List? data = await _http.download(url);
      if (data == null) {
        logError('failed to download: $url');
      } else {
        // 解码二进制数据为UTF8文本
        text = UTF8.decode(data);
        if (text == null) {
          logError('failed to decode ${data.length} bytes from $url');
        } else {
          // 存入缓存
          _caches[url] = text;
        }
      }
    }
    return text;
  }

}