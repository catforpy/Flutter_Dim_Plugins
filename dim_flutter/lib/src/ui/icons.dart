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
import 'package:flutter/material.dart';

/// 应用图标常量类
/// 集中管理所有UI使用的图标资源，统一维护便于修改
abstract class AppIcons {

  //
  //  Icons
  //  ~~~~~
  //  图标来源说明：
  //  - CupertinoIcons: iOS风格图标（https://api.flutter.dev/flutter/cupertino/CupertinoIcons-class.html#constants）
  //  - Icons: Material风格图标（https://api.flutter.dev/flutter/material/Icons-class.html）
  //

  // 基础图标
  static const IconData stationIcon = CupertinoIcons.cloud;         // 中继站图标
  static const IconData     ispIcon = CupertinoIcons.cloud_moon;    // ISP图标
  static const IconData     botIcon = Icons.support_agent;          // 机器人/客服图标
  static const IconData     icpIcon = Icons.room_service_outlined;  // ICP图标
  static const IconData    userIcon = CupertinoIcons.person;        // 个人用户图标
  static const IconData   groupIcon = CupertinoIcons.group;         // 群组图标

  // 底部Tab栏图标
  static const IconData    chatsTabIcon = CupertinoIcons.chat_bubble_2;  // 聊天Tab
  static const IconData contactsTabIcon = CupertinoIcons.group;          // 联系人Tab
  static const IconData servicesTabIcon = CupertinoIcons.compass;        // 服务Tab
  // static const IconData settingsTabIcon = CupertinoIcons.gear;        // 设置Tab（备用）
  static const IconData       meTabIcon = CupertinoIcons.person;         // 我的Tab

  // 聊天框相关图标
  static const IconData   chatDetailIcon = Icons.more_horiz;            // 聊天详情
  static const IconData      chatMicIcon = CupertinoIcons.mic;          // 麦克风
  static const IconData chatKeyboardIcon = CupertinoIcons.keyboard;     // 键盘切换
  static const IconData chatFunctionIcon = Icons.add_circle_outline;    // 功能扩展
  static const IconData     chatSendIcon = Icons.send;                  // 发送
  static const IconData      noImageIcon = CupertinoIcons.photo;        // 无图片占位
  static const IconData       cameraIcon = CupertinoIcons.camera;       // 相机
  static const IconData        albumIcon = CupertinoIcons.photo;        // 相册
  static const IconData     saveFileIcon = CupertinoIcons.floppy_disk;  // 保存文件
  static const IconData   encryptingIcon = CupertinoIcons.lock;         // 加密中
  static const IconData   decryptingIcon = CupertinoIcons.lock_open;    // 解密中
  static const IconData decryptErrorIcon = CupertinoIcons.slash_circle; // 解密失败
  // 音频相关
  static const IconData    waitAudioIcon = CupertinoIcons.cloud_download; // 等待音频下载
  static const IconData    playAudioIcon = CupertinoIcons.play;          // 播放音频
  static const IconData playingAudioIcon = CupertinoIcons.volume_up;     // 音频播放中
  // 视频相关
  static const IconData    playVideoIcon = CupertinoIcons.play;          // 播放视频
  static const IconData      airPlayIcon = Icons.airplay;                // 投屏
  static const IconData        livesIcon = Icons.live_tv;                // 直播
  static const IconData  unavailableIcon = CupertinoIcons.slash_circle;  // 不可用/未支持
  // 消息状态
  static const IconData   msgDefaultIcon = CupertinoIcons.ellipsis;      // 消息默认状态
  static const IconData msgEncryptedIcon = CupertinoIcons.lock;          // 消息已加密
  static const IconData   msgWaitingIcon = CupertinoIcons.ellipsis;      // 消息等待发送
  static const IconData      msgSentIcon = Icons.done;                   // 消息已发送
  static const IconData   msgBlockedIcon = Icons.block;                  // 消息被拦截
  static const IconData  msgReceivedIcon = Icons.done_all;               // 消息已接收
  static const IconData   msgExpiredIcon = CupertinoIcons.refresh;       // 消息已过期

  // 通用图标
  static const IconData    encryptedIcon = CupertinoIcons.padlock_solid; // 已加密（实心锁）
  static const IconData      webpageIcon = CupertinoIcons.link;          // 网页链接
  static const IconData        mutedIcon = CupertinoIcons.bell_slash;    // 已静音
  static const IconData    plainTextIcon = CupertinoIcons.doc_plaintext; // 纯文本
  static const IconData     richTextIcon = CupertinoIcons.doc_richtext;  // 富文本
  static const IconData      forwardIcon = CupertinoIcons.arrow_right;   // 转发/前进

  // 搜索相关
  static const IconData searchIcon = CupertinoIcons.search;              // 搜索

  // 联系人相关
  static const IconData newFriendsIcon = CupertinoIcons.person_add;          // 新朋友
  static const IconData  blockListIcon = CupertinoIcons.person_crop_square_fill; // 黑名单
  static const IconData   muteListIcon = CupertinoIcons.app_badge;            // 静音列表
  static const IconData groupChatsIcon = CupertinoIcons.person_2;             // 群聊

  static const IconData      adminIcon = Icons.admin_panel_settings_outlined; // 管理员
  static const IconData invitationIcon = Icons.contact_mail_outlined;         // 邀请

  static const IconData     reportIcon = CupertinoIcons.bell;          // 举报
  static const IconData  addFriendIcon = CupertinoIcons.person_add;    // 添加好友
  static const IconData    sendMsgIcon = CupertinoIcons.chat_bubble;   // 发送消息
  static const IconData     recallIcon = CupertinoIcons.arrow_uturn_down; // 撤回
  static const IconData      shareIcon = CupertinoIcons.share;         // 分享
  static const IconData  clearChatIcon = CupertinoIcons.delete;        // 清空聊天
  static const IconData     deleteIcon = CupertinoIcons.delete;        // 删除
  static const IconData     removeIcon = Icons.remove_circle_outline;  // 移除

  static const IconData      closeIcon = CupertinoIcons.clear_thick;   // 关闭/清除

  static const IconData       quitIcon = CupertinoIcons.escape;        // 退出
  static const IconData  groupChatIcon = CupertinoIcons.group;         // 群聊
  static const IconData       plusIcon = CupertinoIcons.add;           // 加号
  static const IconData      minusIcon = CupertinoIcons.minus;         // 减号
  static const IconData   selectedIcon = CupertinoIcons.checkmark;     // 已选中

  // 设置相关
  static const IconData exportAccountIcon = CupertinoIcons.lock_shield; // 导出账户
  // static const IconData exportAccountIcon = Icons.vpn_key_outlined;   // 备用图标
  // static const IconData exportAccountIcon = Icons.account_balance_wallet_outlined; // 备用图标
  static const IconData          burnIcon = CupertinoIcons.timer;      // 读后即焚

  static const IconData       storageIcon = CupertinoIcons.square_stack_3d_up; // 存储
  // static const IconData       storageIcon = Icons.storage;            // 备用图标
  static const IconData         cacheIcon = CupertinoIcons.folder;     // 缓存
  static const IconData     temporaryIcon = CupertinoIcons.trash;      // 临时文件

  static const IconData    setNetworkIcon = CupertinoIcons.cloud;      // 网络设置
  static const IconData setWhitePaperIcon = CupertinoIcons.doc;        // 白皮书设置
  // static const IconData setOpenSourceIcon = Icons.code;               // 备用图标
  static const IconData setOpenSourceIcon = CupertinoIcons.chevron_left_slash_chevron_right; // 开源设置
  static const IconData      setTermsIcon = CupertinoIcons.doc_checkmark; // 条款设置
  static const IconData      setAboutIcon = CupertinoIcons.info;       // 关于

  static const IconData    brightnessIcon = CupertinoIcons.brightness; // 亮度设置
  static const IconData       sunriseIcon = CupertinoIcons.sunrise;    // 日出（亮色）
  static const IconData        sunsetIcon = CupertinoIcons.sunset_fill; // 日落（暗色）

  static const IconData      languageIcon = Icons.language;            // 语言设置

  static const IconData  notificationIcon = CupertinoIcons.app_badge;  // 通知设置

  // 中继站相关
  static const IconData         refreshIcon = Icons.forward_5;         // 刷新
  static const IconData  currentStationIcon = CupertinoIcons.cloud_upload_fill; // 当前选中的中继站
  static const IconData   chosenStationIcon = CupertinoIcons.cloud_fill; // 已选择的中继站

  // 注册相关
  static const IconData    agreeIcon = CupertinoIcons.check_mark;      // 同意
  static const IconData disagreeIcon = CupertinoIcons.clear;           // 不同意

  static const IconData updateDocIcon = CupertinoIcons.cloud_upload;   // 更新文档

}