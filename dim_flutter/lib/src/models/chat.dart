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

import 'package:dim_flutter/src/ui/nav.dart';
import 'package:flutter/cupertino.dart';

import 'package:dim_client/sdk.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/ok.dart' as lnc;

import '../common/constants.dart';
import '../common/dbi/contact.dart';
import '../client/shared.dart';
import '../widgets/alert.dart';

import '../widgets/name_label.dart';
import 'chat_contact.dart';
import 'chat_group.dart';
import 'shield.dart';

/// 会话抽象基类（所有聊天会话的通用父类）
/// 混入 Logging 用于日志输出，实现 Observer 接口处理通知
abstract class Conversation with Logging implements lnc.Observer {
  /// 构造函数：初始化会话核心属性并注册通知监听
  /// [identifier] 会话ID（联系人ID/群ID）
  /// [unread] 未读消息数，默认0
  /// [lastMessage] 最后一条消息内容，默认null
  /// [lastMessageTime] 最后一条消息时间，默认null
  /// [mentionedSerialNumber] @我的消息序号，默认0
  Conversation(this.identifier,{this.unread = 0, this.lastMessage, this.lastMessageTime, this.mentionedSerialNumber = 0}) {
    // 注册通知监听：文档更新、备注更新、拉黑列表更新、静音列表更新
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kRemarkUpdated);
    nc.addObserver(this, NotificationNames.kBlockListUpdated);
    nc.addObserver(this, NotificationNames.kMuteListUpdated);
  }

  /// 接收通知的处理方法（Observer接口实现）
  /// [notification] 收到的通知对象
  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    // 处理文档更新通知（如群公告、联系人签证更新）
    if(name == NotificationNames.kDocumentUpdated){
      ID? did = userInfo?['did'];
      assert(did != null, 'notification error: $notification');
      if(did == identifier){
        logInfo('document updated: $did');
        setNeedsReload(); // 标记需要重新加载数据
        await reloadData();
      }
    }else if(name == NotificationNames.kRemarkUpdated){
      // 处理备注更新通知
      ID? did = userInfo?['contact'];
      assert(did != null, 'notification error: $notification');
      if(did == identifier){
        logInfo('remark updated: $did');
        setNeedsReload();
        await reloadData();
      }
    }else if(name == NotificationNames.kBlockListUpdated){
      // 处理拉黑列表更新通知
      ID? did = userInfo?['blocked'];
      did ??= userInfo?['unblocked'];
      if(did == identifier){
        logInfo('blocked contact updated: $did');
        setNeedsReload();
        await reloadData();
      }else if(did == null){
        logInfo('block-list updated');
        setNeedsReload();
        await reloadData();
      }
    }else if (name == NotificationNames.kMuteListUpdated) {
      // 处理静音列表更新通知
      ID? did = userInfo?['muted'];
      did ??= userInfo?['unmuted'];
      if (did == identifier) {
        logInfo('muted contact updated: $did');
        setNeedsReload();
        await reloadData();
      } else if (did == null) {
        logInfo('mute-list updated');
        setNeedsReload();
        await reloadData();
      }
    }
  }

  /// 会话唯一标识（联系人ID/群ID）
  final ID identifier;

  /// 数据是否已加载完成（用于控制reloadData的重复加载）
  bool _loaded = false;

  /// 会话名称（联系人昵称/群名称）
  String? _name;

  /// 会话窗口组件的弱引用（避免内存泄漏）
  WeakReference<Widget>? _widget;
  /// 获取会话窗口组件（可能为null）
  Widget? get widget => _widget?.target;
  /// 设置会话窗口组件（弱引用存储）
  set widget(Widget? chatBox) =>
      _widget = chatBox == null ? null : WeakReference(chatBox);

  /// 未读消息数量
  int unread;          
  /// 最后一条消息的显示文本
  String? lastMessage;  
  /// 最后一条消息的时间
  DateTime? lastMessageTime;   
  /// @我的消息序号（用于标记最新的@消息）
  int mentionedSerialNumber;   

  /// 拉黑状态：null=检查中，true=已拉黑，false=未拉黑
  bool? _blocked;
  /// 静音状态：null=检查中，true=已静音，false=未静音
  bool? _muted;

  /// 获取会话类型（用户/群/服务器等，由identifier.type决定）
  int get type => identifier.type;
  /// 是否是用户会话（单聊）
  bool get isUser  => identifier.isUser;
  /// 是否是群会话（群聊）
  bool get isGroup => identifier.isGroup;

  /// 是否已拉黑该会话
  bool get isBlocked => _blocked == true;
  /// 是否未拉黑该会话
  bool get isNotBlocked => _blocked == false;

  /// 是否已静音该会话
  bool get isMuted => _muted == true;
  /// 是否未静音该会话
  bool get isNotMuted => _muted == false;

  /// 抽象方法：获取会话头像组件（由子类实现）
  /// [width] 头像宽度
  /// [height] 头像高度
  /// [fit] 图片适配方式
  Widget getImage({double? width, double? height, BoxFit? fit});

  /// 获取会话名称标签组件（封装NameLabel，用于统一显示名称）
  /// [style] 文本样式
  /// [strutStyle] 行距样式
  /// [textAlign] 文本对齐方式
  /// [textDirection] 文本方向
  /// [locale] 本地化
  /// [softWrap] 是否自动换行
  /// [overflow] 文本溢出处理
  /// [textScaler] 文本缩放
  /// [maxLines] 最大行数
  /// [semanticsLabel] 语义标签
  /// [textWidthBasis] 文本宽度计算方式
  /// [textHeightBehavior] 文本高度行为
  /// [selectionColor] 选中颜色
  NameLabel getNameLabel({
    TextStyle? style,
    StrutStyle? strutStyle,
    TextAlign? textAlign,
    TextDirection? textDirection,
    Locale? locale,
    bool? softWrap,
    TextOverflow? overflow,
    TextScaler? textScaler,
    int? maxLines,
    String? semanticsLabel,
    TextWidthBasis? textWidthBasis,
    TextHeightBehavior? textHeightBehavior,
    Color? selectionColor,
  }) => NameLabel(this,
    style:              style,
    strutStyle:         strutStyle,
    textAlign:          textAlign,
    textDirection:      textDirection,
    locale:             locale,
    softWrap:           softWrap,
    overflow:           overflow,
    textScaler:         textScaler,
    maxLines:           maxLines,
    semanticsLabel:     semanticsLabel,
    textWidthBasis:     textWidthBasis,
    textHeightBehavior: textHeightBehavior,
    selectionColor:     selectionColor,
  );

  /// 获取会话名称
  String get name => _name ?? '';
  /// 设置会话名称
  set name(String text) => _name = text;

  /// 会话标题（默认返回name，子类可重写）
  String get title => name;
  /// 会话副标题（默认返回最后一条消息，用于会话列表显示）
  String get subtitle => lastMessage ?? '';
  /// 会话最后消息时间（默认返回lastMessageTime）
  DateTime? get time => lastMessageTime;

  // @override
  // bool operator ==(Object other) {
  //   if (other is Conversation) {
  //     return identifier == other.identifier;
  //   }
  //   return false;
  // }
  //
  // @override
  // int get hashCode => identifier.hashCode;

  /// 重写toString，输出会话关键信息（便于日志调试）
  @override
  String toString() {
    String clazz = className;
    return '<$clazz id="$identifier" type=$type name="$name" muted=$isMuted>\n'
        '\t<unread>$unread</unread>\n'
        '\t<msg>$subtitle</msg>\n'
        '\t<time>$time</time>\n'
        '</$clazz>';
  }

  /// 会话备注信息
  ContactRemark? _remark;
  /// 空备注对象（避免空指针）
  late final ContactRemark _emptyRemark = ContactRemark.empty(identifier);

  /// 获取会话备注（无备注时返回空备注对象）
  ContactRemark get remark => _remark ?? _emptyRemark;

  /// 设置会话备注（更新内存+数据库）
  /// [context] 上下文（用于显示弹窗）
  /// [alias] 备注名
  /// [description] 备注描述
  void setRemark({required BuildContext context, String? alias, String? description}){
    // 更新内存中的备注
    ContactRemark? cr = _remark;
    if(cr == null){
      cr = ContactRemark(identifier, alias: alias ?? '', description: description ?? '');
      _remark = cr;
    }else{
      if(alias != null){
        cr.alias = alias;
      }
      if(description != null){
        cr.description = description;
      }
    }
    // 保存到本地数据库
    GlobalVariable shared = GlobalVariable();
    shared.facebook.currentUser.then((user) {
      if(user == null){
        logError('current user not found, failed to set remark: $cr => $identifier');
        if(context.mounted){
          Alert.show(context, i18nTranslator.translate('Error'), i18nTranslator.translate('Current user not found'));
        }
      }else {
        shared.database.setRemark(cr!, user: user.identifier).then((ok) {
          if (ok) {
            logInfo('set remark: $cr => $identifier, user: $user');
          } else {
            logError('failed to set remark: $cr => $identifier, user: $user');
            if (context.mounted) {
              Alert.show(context, i18nTranslator.translate('Error'), i18nTranslator.translate('Failed to set remark'));
            }
          }
        });
      }
    });
  }

  /// 标记数据需要重新加载（设置_loaded为false）
  void setNeedsReload() => _loaded = false;

  /// 刷新会话相关文档（如群公告、联系人签证）
  /// 返回是否刷新成功
  Future<bool> refreshDocuments() async {
    var shared = GlobalVariable();
    var facebook = shared.facebook;
    var checker = facebook.entityChecker;
    if(checker == null){
      logError('entity checker lost, cannot refresh documents now.');
      return false;
    }
    List<Document> docs = await facebook.getDocuments(identifier);
    logInfo('refreshing ${docs.length} document(s) "$name" $identifier');
    return await checker.queryDocuments(identifier, docs);
  }

  /// 重新加载数据（仅当_loaded为false时执行loadData）
  Future<void> reloadData() async {
    if (_loaded) {
    } else {
      await loadData();
      _loaded = true;
    }
  }

  /// 加载会话基础数据（名称、备注、拉黑/静音状态）
  /// 子类可重写扩展更多数据加载逻辑
  Future<void> loadData() async {
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      logError('current user not found');
    }
    // 获取会话名称（联系人昵称/群名称）
    _name = await shared.facebook.getName(identifier);
    // 获取会话备注
    if (user != null) {
      _remark = await shared.database.getRemark(identifier, user: user.identifier);
    }
    // 获取拉黑/静音状态
    Shield shield = Shield();
    _blocked = await shield.isBlocked(identifier);
    _muted = await shield.isMuted(identifier);
  }

  /// 拉黑该会话（管理员不可拉黑）
  /// [context] 上下文（用于显示弹窗）
  void block({required BuildContext context}) {
    // 检查是否是管理员（管理员不可拉黑）
    GlobalVariable shared = GlobalVariable();
    List<ID> managers = shared.config.managers;
    if(managers.contains(identifier)){
      logWarning('cannot block manager: $identifier, $managers');
      if(context.mounted){
        Alert.show(context, i18nTranslator.translate('Unblocked'),
          i18nTranslator.translate('Cannot block this contact'),
        );
      }
      return;
    }
    // 标记为已拉黑
    _blocked = true;
    // 更新数据库并广播拉黑列表
    Shield shield = Shield();
    shield.addBlocked(identifier).then((ok) {
      if(ok){
        shield.broadcastBlockList();
        if(context.mounted){
          Alert.show(context, i18nTranslator.translate('Blocked'),
            i18nTranslator.translate('Never receive message from this contact'),
          );
        }
      }
    });
  }

  /// 解除拉黑该会话
  /// [context] 上下文（用于显示弹窗）
  void unblock({required BuildContext context}) {
    // 标记为未拉黑
    _blocked = false;
    // 更新数据库并广播拉黑列表
    Shield shield = Shield();
    shield.removeBlocked(identifier).then((ok){
      if(ok){
        shield.broadcastBlockList();
        if(context.mounted){
          Alert.show(context, i18nTranslator.translate('Unblocked'),
            i18nTranslator.translate('Receive message from this contact'),
          );
        }
      }
    });
  }

  /// 静音该会话（关闭消息通知）
  /// [context] 上下文（用于显示弹窗）
  void mute({required BuildContext context}) {
    // 标记为已静音
    _muted = true;
    // 更新数据库并广播静音列表
    Shield shield = Shield();
    shield.addMuted(identifier).then((ok){
      if(ok){
        shield.broadcastMuteList();
        if(context.mounted){
          Alert.show(context, i18nTranslator.translate('Muted'),
            i18nTranslator.translate('Never receive message from this contact'),
          );
        }
      }
    });
  }

  /// 解除静音该会话（恢复消息通知）
  /// [context] 上下文（用于显示弹窗）
  void unmute({required BuildContext context}) {
    // 标记为未静音
    _muted = false;
    // 更新数据库并广播静音列表
    Shield shield = Shield();
    shield.removeMuted(identifier).then((ok) {
      if (ok) {
        shield.broadcastMuteList();
        if (context.mounted) {
          Alert.show(context, i18nTranslator.translate('Unmuted'),
            i18nTranslator.translate('Receive notification from this contact'),
          );
        }
      }
    });
  }

  /// 从ID创建会话实例（根据ID类型返回GroupInfo/ContactInfo）
  /// [identifier] 会话ID
  /// 返回Conversation实例（群ID返回GroupInfo，用户ID返回ContactInfo，其他返回null）
  static Conversation? fromID(ID identifier) {
    if(identifier.isGroup){
      return GroupInfo.fromID(identifier);
    }
    return ContactInfo.fromID(identifier);
  }

  /// 从ID列表创建会话列表
  /// [chats] ID列表
  /// 返回Conversation列表（过滤无效ID）
  static List<Conversation> fromList(List<ID> chats) {
    List<Conversation> array = [];
    Conversation? info;
    for (ID item in chats) {
      info = fromID(item);
      if (info == null) {
        Log.warning('ignore conversation: $item');
        continue;
      }
      array.add(info);
    }
    return array;
  }
}