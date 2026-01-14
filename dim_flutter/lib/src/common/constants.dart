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


import 'package:dim_client/pnf.dart' as pnf show NotificationNames;

/// 应用内通知名称常量类
/// 定义所有业务模块的通知名称，用于跨组件通信
abstract class NotificationNames{

  // ===================== 网络/服务器相关 =====================
  /// 服务提供商更新通知
  static const String kServiceProviderUpdated = 'ServiceProviderUpdated';
  /// 服务器列表更新通知
  static const String kStationsUpdated = 'StationsUpdated';
  /// 服务器速度更新通知
  static const String kStationSpeedUpdated = 'StationSpeedUpdated';
  /// 服务器连接状态变更通知
  static const String kServerStateChanged = 'ServerStateChanged';

  // ===================== 聊天界面相关 =====================
  /// 开始聊天通知
  static const String kStartChat = 'StartChat';
  /// 聊天窗口关闭通知
  static const String kChatBoxClosed = 'ChatBoxClosed';

  // ===================== 账号相关 =====================
  /// 账号删除通知
  static const String kAccountDeleted = 'AccountDeleted';
  /// 私钥保存成功通知
  static const String kPrivateKeySaved = 'PrivateKeySaved';
  /// 元数据保存成功通知
  static const String kMetaSaved = 'MetaSaved';
  /// 文档更新通知
  static const String kDocumentUpdated = 'DocumentUpdated';

  // ===================== 联系人相关 =====================
  /// 本地用户列表更新通知
  static const String kLocalUsersUpdated = 'LocalUsersUpdated';
  /// 联系人列表更新通知
  static const String kContactsUpdated = 'ContactsUpdated';
  /// 联系人备注更新通知
  static const String kRemarkUpdated = 'RemarkUpdated';
  /// 黑名单更新通知
  static const String kBlockListUpdated = 'BlockListUpdated';
  /// 静音列表更新通知
  static const String kMuteListUpdated = 'MuteListUpdated';

  // ===================== 命令/群组相关 =====================
  /// 登录命令更新通知
  static const String kLoginCommandUpdated = 'LoginCommandUpdated';
  /// 群组历史更新通知
  static const String kGroupHistoryUpdated = 'GroupHistoryUpdated';
  /// 群组创建通知
  static const String kGroupCreated = 'GroupCreated';
  /// 群组移除通知
  static const String kGroupRemoved = 'GroupRemoved';
  /// 群成员更新通知
  static const String kMembersUpdated = 'MembersUpdated';
  /// 群管理员更新通知
  static const String kAdministratorsUpdated = 'AdministratorsUpdated';
  /// 群参与者更新通知
  static const String kParticipantsUpdated = 'ParticipantsUpdated';

  // ===================== 消息相关 =====================
  /// 消息历史更新通知
  static const String kHistoryUpdated = 'HistoryUpdated';
  /// 单条消息更新通知
  static const String kMessageUpdated = 'MessageUpdated';
  /// 消息清理通知
  static const String kMessageCleaned = 'MessageCleaned';
  /// 消息追踪更新通知
  static const String kMessageTraced = 'MessageTraced';
  /// 正在输入通知
  static const String kMessageTyping = 'MessageTyping';
  /// 头像长按通知
  static const String kAvatarLongPressed = 'AvatarLongPressed';

  // ===================== 会话相关 =====================
  /// 会话清理通知
  static const String kConversationCleaned = 'ConversationCleaned';
  /// 会话更新通知
  static const String kConversationUpdated = 'ConversationUpdated';

  // ===================== 自定义信息相关 =====================
  /// 自定义信息更新通知
  static const String kCustomizedInfoUpdated = 'CustomizedInfoUpdated';

  // ===================== 搜索相关 =====================
  /// 搜索结果更新通知
  static const String kSearchUpdated = 'SearchUpdated';

  // ===================== 翻译相关 =====================
  /// 翻译结果更新通知
  static const String kTranslateUpdated = 'TranslateUpdated';
  /// 翻译器警告通知
  static const String kTranslatorWarning = 'TranslatorWarning';
  /// 翻译器就绪通知
  static const String kTranslatorReady = 'TranslatorReady';

  // ===================== 音视频相关 =====================
  /// 录音完成通知
  static const String kRecordFinished = 'RecordFinished';
  /// 播放完成通知
  static const String kPlayFinished = 'PlayFinished';

  // ===================== 设置相关 =====================
  /// 阅后即焚时间更新通知
  static const String kBurnTimeUpdated = 'BurnAfterReadingUpdated';
  /// 应用设置更新通知
  static const String kSettingUpdated = 'SettingUpdated';
  /// 配置更新通知
  static const String kConfigUpdated = 'ConfigUpdated';

  // ===================== 缓存文件管理 =====================
  /// 缓存文件找到通知
  static const String kCacheFileFound = 'CacheFileFound';
  /// 缓存扫描完成通知
  static const String kCacheScanFinished = 'CacheScanFinished';

  // ===================== 加密密钥相关（新增） =====================
  /// 私钥映射表新增通知（新会话生成密钥）
  static const String kPrivateKeyMapAdded = 'PrivateKeyMapAdded';
  /// 私钥映射表更新通知（密钥轮换）
  static const String kPrivateKeyMapUpdated = 'PrivateKeyMapUpdated';
  /// 私钥映射表删除通知（会话删除，清理密钥）
  static const String kPrivateKeyMapRemoved = 'PrivateKeyMapRemoved';
  /// 私钥同步失败通知（用于重试逻辑）
  static const String kPrivateKeySyncFailed = 'PrivateKeySyncFailed';

  //
  //  PNF (Portable Network Framework) 网络框架相关
  //

  /// 网络状态变更通知（复用PNF定义）
  static const String       kPortableNetworkStatusChanged =
      pnf.NotificationNames.kPortableNetworkStatusChanged;

  /// 网络发送进度通知（复用PNF定义）
  static const String       kPortableNetworkSendProgress =
      pnf.NotificationNames.kPortableNetworkSendProgress;
  /// 网络接收进度通知（复用PNF定义）
  static const String       kPortableNetworkReceiveProgress =
      pnf.NotificationNames.kPortableNetworkReceiveProgress;

  /// 消息加密完成通知（复用PNF定义）
  static const String       kPortableNetworkEncrypted =
      pnf.NotificationNames.kPortableNetworkEncrypted;

  /// 网络消息接收完成通知（复用PNF定义）
  static const String       kPortableNetworkReceived =
      pnf.NotificationNames.kPortableNetworkReceived;
  /// 消息解密完成通知（复用PNF定义）
  static const String       kPortableNetworkDecrypted =
      pnf.NotificationNames.kPortableNetworkDecrypted;

  /// 文件上传成功通知（复用PNF定义）
  static const String       kPortableNetworkUploadSuccess =
      pnf.NotificationNames.kPortableNetworkUploadSuccess;
  /// 文件下载成功通知（复用PNF定义）
  static const String       kPortableNetworkDownloadSuccess =
      pnf.NotificationNames.kPortableNetworkDownloadSuccess;

  /// 网络错误通知（复用PNF定义）
  static const String       kPortableNetworkError =
      pnf.NotificationNames.kPortableNetworkError;

  //
  //  活跃用户相关
  //

  /// 活跃用户列表更新通知
  static const String kActiveUsersUpdated = 'ActiveUsersUpdated';

  //
  //  播放列表相关
  //

  /// 播放列表更新通知
  static const String kPlaylistUpdated = 'PlaylistUpdated';
  /// 视频项更新通知
  static const String kVideoItemUpdated = 'VideoItemUpdated';

  //
  //  直播播放器相关
  //

  /// 直播源更新通知
  static const String kLiveSourceUpdated = 'LiveSourceUpdated';
  /// 视频播放器播放通知
  static const String kVideoPlayerPlay = 'VideoPlayerPlay';

  //
  //  网页浏览器相关
  //
  /// 网站列表更新通知
  static const String kWebSitesUpdated = 'WebSitesUpdated';
}