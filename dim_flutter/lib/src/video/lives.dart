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

import 'package:flutter/material.dart'; // Flutter Material组件
import 'package:flutter_section_list/flutter_section_list.dart'; // 分组列表组件

import 'package:dim_client/ok.dart' as lnc; // DIM基础库（通知中心等）
import 'package:tvbox/lives.dart'; // 直播频道数据模型

import '../common/constants.dart'; // 常量定义
import '../ui/styles.dart'; // UI样式
import '../widgets/table.dart'; // 表格组件

import 'tvbox.dart'; // TVBox核心类


/// 直播频道列表页面 - 显示分组的直播频道，支持展开/收起、播放状态标记
class LiveChannelListPage extends StatefulWidget {
  const LiveChannelListPage(this.tvBox, {super.key});

  final TVBox tvBox; // TVBox实例（包含直播频道数据）

  /// 频道列表刷新通知名称
  static const String kPlayerChannelsRefresh = 'PlayerChannelsRefresh';

  @override
  State<LiveChannelListPage> createState() => _LiveChannelListState();
}

class _LiveChannelListState extends State<LiveChannelListPage> implements lnc.Observer {
  _LiveChannelListState() {
    // 初始化列表适配器
    _adapter = _LiveChannelAdapter(this);

    // 注册通知监听（频道列表刷新）
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, LiveChannelListPage.kPlayerChannelsRefresh);
  }

  /// 列表适配器（处理分组和数据绑定）
  late final _LiveChannelAdapter _adapter;

  /// 获取TVBox实例
  TVBox get tvBox => widget.tvBox;

  @override
  void dispose(){
    // 移除通知监听
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this,LiveChannelListPage.kPlayerChannelsRefresh);
    super.dispose();
  }

  /// 通知回调 - 刷新列表
  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    assert(name == LiveChannelListPage.kPlayerChannelsRefresh, 'notification error: $notification');
    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 构建分组列表
    Widget view = buildSectionListView(
      enableScrollbar: true, // 显示滚动条
      adapter: _adapter,     // 列表适配器
    );
    // 包装容器（固定宽度+半透明黑色背景）
    view = Container(
      width: 220,
      color: Colors.black.withAlpha(0x77),
      child: view,
    );
    return view;
  }
}


//
//  分组列表适配器
//

/// 直播频道列表适配器 - 实现SectionAdapterMixin，处理分组逻辑
class _LiveChannelAdapter with SectionAdapterMixin {
  _LiveChannelAdapter(this.state);

  final _LiveChannelListState state;

  /// 每个分组显示头部
  @override
  bool shouldExistSectionHeader(int section) => true;

  /// 构建分组头部
  @override
  Widget getSectionHeader(BuildContext context, int section) {
    var group = getGroup(section);    // 获取分组数据
    Widget view = Text(
      group.title,
      style:Styles.liveGroupStyle,    //分组标题样式
      softWrap: false,                // 不换行
      overflow: TextOverflow.fade,    // 溢出渐变
      maxLines: 1,                    // 单行        
    );
    return Center(
      child: view,
    );
  }

  /// 获取分组数量
  @override
  int numberOfSections() => getGroupCount();

  /// 获取指定分组的子项数量
  @override
  int numberOfItems(int section) => getSourceCount(section);

  /// 构建列表项
  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    // 获取频道/流数据
    ChannelStream src = getSource(indexPath.section,indexPath.item)!;
    // 构建频道按钮
    Widget view = _getChannelButton(src,state.tvBox);
    view = Container(
      alignment: Alignment.centerLeft,
      child: view,
    );
    return view;
  }

  //
  //  数据源处理
  //

  /// 获取所有直播分组
  List<LiveGenre> get groups => state.widget.tvBox.lives ?? [];
  /// 获取分组数量
  int getGroupCount() => groups.length;
  /// 获取指定分组
  LiveGenre getGroup(int sec) => groups[sec];

  /// 获取指定分组的子项数量（处理展开/收起状态）
  int getSourceCount(int sec) {
    var channels = groups[sec].channels;    // 获取分组下的频道列表
    int count = 0;
    for(var item in channels){
      count += _testSpaces(item);           // 累加每个频道的子项数   
    }
    return count;
  }

  /// 计算单个频道的子项数量（展开/收起）
  int _testSpaces(LiveChannel item) {
    var unfold = item.getValue('unfold', null);       // 获取展开状态
    if(unfold != true){
      return 1;                 // 收起状态：仅显示频道名称
    }
    int count = item.count;     // 频道下的流数量
    if(count == 1){
      return 1;                 // 频道下只有1个流，则显示频道名称+流名称,无需展开
    }
    return count + 1;           // 展开装填：频道名称+所有流
  }

  /// 获取指定位置的频道/流数据
  ChannelStream? getSource(int sec, int idx) {
    var channels = groups[sec].channels; // 获取分组下的频道列表
    for(var item in channels){
      // 计算当前频道的子项数
      int count = item.count;
      int spaces;
      var unfold = item.getValue('unfold', null);
      if(unfold != true){
        spaces = 1;             // 收起状态：仅显示频道名称
      }else{
        spaces = count;
        if(spaces > 1){
          spaces += 1;          // 展开状态：+1 频道名称+所有流
        }
      }
      // 索引超出当前频道范围:继续下一频道
      if(idx >= spaces){
        idx -= spaces;
        continue;
      }else if(idx > 0){
        // 索引>0:对应频道下的流
        var src = item.streams[idx-1];
        return ChannelStream(item,src);
      }else if(count == 1){
        // 只有一个流：直接返回
        var src = item.streams[0];
        return ChannelStream(item,src);
      }else {
        // 索引 = 0：频道名称项（无流）
        return ChannelStream(item, null);
      }
    }
    assert(false, 'failed to get source $sec, $idx');
    return null;
  }
}

/// 构建频道按钮（支持展开/收起、播放状态、多源流选择）
Widget _getChannelButton(ChannelStream src, TVBox tvBox) {
  bool isPlaying = src == tvBox.playingItem;    // 是否正在播放
  var channel = src.channel;                    // 频道信息
  var stream = src.stream;                      // 流信息(可为null)

  if(stream == null){
    // 无流信息：频道名称项（展开/收起按钮）
    var name = channel.name;
    var count = channel.count;
    var unfold = channel.getValue('unfold', null);
    if(unfold != true){
      name += '  ($count srcs)'; // 显示流数量
    }
    return TextButton(
      onPressed: () {
        // 切换展开状态
        channel.setValue('unfold', unfold != true);
        // 发送刷新通知
        var nc = lnc.NotificationCenter();
        nc.postNotification('PlayerChannelsRefresh', null,{});
      }, 
      child: Text(name,
      style: isPlaying ? Styles.liveChannelStyle : Styles.liveChannelStyle,
      softWrap: false,
      overflow: TextOverflow.fade,
      maxLines: 1,
      ),
    );
  } 

  // 有流信息：播放按钮
  var name = channel.name;
  var count = channel.count;
  if(count > 1){
    // 多源流：显示流索引和标签
    String? label = stream.label;
    int index = stream.getValue('index', 0);
    if(label == null || label.trim().isEmpty){
      label = name;
    }
    name = '    #$index  $label'; // 缩进显示
  }
  Widget view = Text(name,
    style: isPlaying ? Styles.liveChannelStyle : Styles.liveChannelStyle,
    softWrap: false,
    overflow: TextOverflow.fade,
    maxLines: 1,
  );
  // 处理直播URL（添加#live标识）
  Uri? url = _getLiveUrl(stream.url);
  view = TextButton(
    onPressed: isPlaying ? null : () { // 正在播放时禁用
      // 发送播放通知
      var nc = lnc.NotificationCenter();
      nc.postNotification(NotificationNames.kVideoPlayerPlay, null,{
        'url':url,
        'title':_getLiveTitle(src),
      });
      // 更新播放状态
      tvBox.playingItem = src;
    }, 
    child: view,
  );
  return view;
}

/// 处理直播URL（添加#live标识）
Uri? _getLiveUrl(Uri? url) {
  if(url == null) return null;
  String urlString = url.toString();
  // 已包含直播标识：直接返回
  if(urlString.endsWith(r'#live') || urlString.contains(r'#live/')) {
    return url;
  }else if(urlString.contains(r'm3u8')){
    // m3u8格式：添加#live/stream.m3u8
    urlString += '#live/stream.m3u8';
  }else {
    // 其他格式：添加#live
    urlString += '#live';
  }
  try{
    return Uri.parse(urlString);
  }catch(e){
    return url; // 解析失败返回原URL
  }
}

/// 获取直播标题（添加-LIVE后缀）
String _getLiveTitle(ChannelStream src) {
  String name = src.channel.name;
  if (name.toUpperCase().endsWith(' - LIVE')) {
    return name;
  }
  return '$name - LIVE';
}