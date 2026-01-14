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

import 'package:flutter/cupertino.dart';

import 'package:dim_client/sdk.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/ok.dart' as lnc;

import '../common/constants.dart';
import '../models/chat_contact.dart';
import '../models/chat_group.dart';

/// 群头像组件：根据群成员数量动态拼接成员头像生成群头像
class GroupImage extends StatefulWidget {
  const GroupImage(this.info, {super.key, this.width, this.height, this.fit});

  /// 群信息模型
  final GroupInfo info;

  /// 头像整体宽度
  final double? width;
  /// 头像整体高度
  final double? height;
  /// 图片填充模式
  final BoxFit? fit;
  @override
  State<GroupImage> createState() => _GroupImageState();
}

class _GroupImageState extends State<GroupImage> implements lnc.Observer {
  _GroupImageState(){
    // 注册通知监听：群成员更新、参与者更新
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kMembersUpdated);
    nc.addObserver(this, NotificationNames.kParticipantsUpdated); 
  }

  @override
  void dispose(){
    // 移除通知监听，避免内存泄漏
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this,NotificationNames.kParticipantsUpdated);
    nc.removeObserver(this,NotificationNames.kMembersUpdated);
    super.dispose();
  }

  /// 接收通知回调：群成员/参与者更新时刷新头像
  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    // 群成员更新通知
    if (name == NotificationNames.kMembersUpdated) {
      ID? identifier = userInfo?['ID'];
      if (identifier == null) {
        Log.error('notification error: $notification');
      } else if (identifier == widget.info.identifier) {
        // 仅刷新当前群的头像
        await _reload();
      }
    } else if (name == NotificationNames.kParticipantsUpdated) {
      // 群参与者更新通知
      ID? identifier = userInfo?['ID'];
      if (identifier == null) {
        Log.error('notification error: $notification');
      } else if (identifier == widget.info.identifier) {
        if (mounted) {
          // 刷新UI
          setState(() {
          });
        }
      }
    }
  }

  /// 重新加载群成员数据并刷新UI
  Future<void> _reload() async {
    await widget.info.reloadData();
    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // 初始化时加载群成员数据
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    // 将群成员ID列表转换为联系人信息列表
    List<ContactInfo> members = ContactInfo.fromList(widget.info.members);
    int count = members.length;
    // 根据成员数量确定单个头像的尺寸
    double width;
    double height;
    if (count < 5) {
      width = 22;
      height = 22;
    } else {
      width = 15;
      height = 15;
    }
    // 构建成员头像列表
    List<Widget> images = [];
    ContactInfo info;
    Widget img;
    for(int i = 0; i < count; ++i){
      info = members[i];
      info.reloadData();
      // 获取单个成员头像
      img = info.getImage(width: width, height: height,fit: widget.fit);
      images.add(img);
    }
    // 群头像整体尺寸（默认48x48）
    double boxWidth = widget.width ?? 48;
    double boxHeight = widget.height ?? 48;
    // 群头像边框样式
    BoxDecoration decoration = BoxDecoration(
      border: Border.all(color: CupertinoColors.systemGrey,width: 1,style: BorderStyle.solid),
      borderRadius: BorderRadius.circular(4),
    );
    /// 拼接布局逻辑：根据成员数量展示不同的拼接样式
    if (count > 6) {
      // 7-9人布局：3行3列（9人满格，8人缺第一行第一个，7人缺第一行前两个）
      if (count > 9) {
        count = 9; // 最多显示9个成员头像
      }
      return Container(
        decoration: decoration,
        width: boxWidth,
        height: boxHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (count >= 9) images[count - 9],
                if (count >= 8) images[count - 8],
                images[count - 7],
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                images[count - 6],
                images[count - 5],
                images[count - 4],
              ],),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                images[count - 3],
                images[count - 2],
                images[count - 1],
              ],
            ),
          ],
        ),
      );
    } else if (count > 4) {
      // 5-6人布局：2行3列（6人满格，5人缺第一行第一个）
      return Container(
        decoration: decoration,
        width: boxWidth,
        height: boxHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (count >=6) images[count - 6],
                images[count - 5],
                images[count - 4],
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                images[count - 3],
                images[count - 2],
                images[count - 1],
              ],
            ),
          ],
        ),
      );
    } else if (count > 2) {
      // 3-4人布局：2行2列（4人满格，3人缺第一行第一个）
      return Container(
        decoration: decoration,
        width: boxWidth,
        height: boxHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (count >= 4) images[count - 4],
                images[count - 3],
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                images[count - 2],
                images[count - 1],
              ],
            ),
          ],
        ),
      );
    }
     // 1-2人布局：1行展示
    return Container(
      decoration: decoration,
      width: boxWidth,
      height: boxHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if(count > 0) images[0],
          if(count > 1) images[1],
        ],
      ),
    );
  }
}
