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

import 'package:dim_client/sdk.dart';
import 'package:dim_client/pnf.dart';
import 'package:tvbox/lives.dart';

/// 媒体项数据模型
/// 继承自Dictionary，用于存储和管理视频/直播媒体信息
class MediaItem extends Dictionary {
  /// 构造函数
  /// [dict] - 初始化数据字典
  MediaItem(super.dict);

  /// 获取播放地址（M3U8格式）
  /// 优先从'url'或'URL'字段获取，解析为Uri对象
  Uri? get url {
    var m3u8 = getString('url');
    m3u8 ??= getString('URL');
    return m3u8 == null ? null : LiveStream.parseUri(m3u8);
  }

  /// 获取标题
  /// 优先级：title > name > url > URL，为空返回空字符串
  String get title => getString('title')
      ?? getString('name')
      ?? getString('url')
      ?? getString('URL')
      ?? '';

  /// 获取文件名
  String? get filename => getString('filename');

  /// 获取封面图片地址
  /// 优先从'cover'或'snapshot'字段获取，解析为Uri对象
  Uri? get cover {
    var jpeg = getString('cover');
    jpeg ??= getString('snapshot');
    return jpeg == null ? null : LiveStream.parseUri(jpeg);
  }

  /// 刷新媒体项信息
  /// [info] - 新的媒体信息字典
  void refresh(Map info) {
    // 清空原有数据
    clear();
    // 批量更新新数据
    info.forEach((key, value) => this[key] = value);
  }

  //
  //  工厂方法
  //

  /// 创建媒体项实例
  /// [m3u8] - 播放地址
  /// [title] - 标题（必填）
  /// [filename] - 文件名
  /// [cover] - 封面地址
  static MediaItem create(Uri m3u8, {
    required String title,
    String? filename,
    Uri? cover,
  }) => MediaItem({
    'URL': m3u8.toString(),
    'url': m3u8.toString(),
    'title': title,
    'filename': filename ?? Paths.filename(m3u8.path),
    'cover': cover?.toString(),
    'snapshot': cover?.toString(),
  });

}

/// 视频分享回调函数类型
/// 参数为当前播放的媒体项
typedef OnVideoShare = void Function(MediaItem playingItem);