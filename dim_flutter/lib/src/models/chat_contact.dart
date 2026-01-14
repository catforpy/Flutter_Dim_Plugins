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

import 'package:dim_flutter/src/dim_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'package:dim_client/ok.dart' as lnc;
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../client/packer.dart';
import '../common/dbi/contact.dart';
import '../common/constants.dart';
import '../client/shared.dart';
import '../pnf/auto_avatar.dart';
import '../ui/language.dart';
import '../utils/syntax.dart';
import '../widgets/alert.dart';

import 'amanuensis.dart';
import 'chat.dart';

/// 联系人会话类（继承自Conversation），封装单聊联系人的属性和操作
class ContactInfo extends Conversation {
  /// 构造函数：初始化联系人会话ID和基础属性
  /// [identifier] 联系人ID
  /// [unread] 未读数
  /// [lastMessage] 最后一条消息
  /// [lastMessageTime] 最后一条消息时间
  /// [mentionedSerialNumber] @我的消息序号
  ContactInfo(super.identifier, {super.unread = 0, super.lastMessage, super.lastMessageTime, super.mentionedSerialNumber = 0}) {
    // 注册联系人更新通知监听
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kContactsUpdated);
  }

  /// 接收通知的处理方法
  /// [notification] 收到的通知
  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    // 处理联系人更新通知
    if(name == NotificationNames.kConfigUpdated){
      ID? contact = userInfo?['contact'];
      // 仅处理当前联系人的更新
      if(contact == identifier){
        // 标记需要重新加载数据
        setNeedsReload();
        await reloadData();
      }
    }else{
      // 其他通知交给父类处理
      await super.onReceiveNotification(notification);
    }
  }

  /// 联系人的签证信息（包含昵称、头像、签名等）
  Visa? _visa;

  /// 获取联系人签证信息
  Visa? get visa => _visa;

  /// 联系人头像
  PortableNetworkFile? _avatar;

  /// 最后活跃时间（最后登录时间）
  DateTime? _lastActiveTime;

  /// 好友标记：null=检查中，true=是好友，false=非好友
  bool? _friendFlag;

  /// 联系人使用的语言名称
  String? _language;
  /// 联系人使用的语言编码（如zh-CN）
  String? _locale;
  /// 联系人的客户端信息（如APP名称、版本、系统）
  String? _clientInfo;

  /// 获取语言显示文本（语言名称 + 编码）
  String? get language => _language == null ? _locale : '$_language ($_locale)';
  /// 获取客户端信息
  String? get clientInfo => _clientInfo;

  /// 是否是好友
  bool get isFriend => _friendFlag == true;
  /// 是否非好友
  bool get isNotFriend => _friendFlag == false;

  /// 是否是新好友（未添加的陌生人，且未拉黑、非服务器）
  bool get isNewFriend {
    if (isFriend) {
      // 已是好友，不是新好友
      return false;
    } else if (isBlocked) {
      // 拉黑的用户不显示在陌生人列表
      return false;
    } else if (identifier.type == EntityType.STATION) {
      // 服务器不能添加为好友
      return false;
    }
    return true;
  }

  /// 获取头像URL
  String? get avatar => _avatar?.url?.toString();

  /// 获取最后活跃时间
  DateTime? get lastActiveTime => _lastActiveTime;

  /// 获取联系人显示标题（昵称 + 备注/语言）联系人备注
  @override
  String get title {
    String nickname = name;
    // 获取联系人备注
    ContactRemark cr = remark;
    String desc = cr.alias;
    if (desc.isEmpty) {
      // 无备注时，非好友显示语言信息
      if (isNotFriend) {
        desc = _language ?? '';
      }
      // 无备注无语言时，显示昵称或匿名名称
      if (desc.isEmpty) {
        return nickname.isEmpty ? Anonymous.getName(identifier) : nickname;
      }
    }
    // 昵称过长时截断
    if (VisualTextUtils.getTextWidth(nickname) > 25) {
      nickname = VisualTextUtils.getSubText(nickname, 22);
      nickname = '$nickname...';
    }
    // 最终标题：昵称 (备注/语言)
    return '$nickname ($desc)';
  }

  /// 获取联系人头像组件
  /// [width] 宽度
  /// [height] 高度
  /// [fit] 适配方式
  @override
  Widget getImage({double? width, double? height, BoxFit? fit}) =>
      AvatarFactory().getAvatarView(identifier, width: width, height: height, fit: fit);

  /// 加载联系人详细数据（签证、活跃时间、好友关系、语言、客户端信息）
  @override
  Future<void> loadData() async {
    // 限制性父类的加载逻辑
    await super.loadData();
    // 获取全局变量
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      logError('current user not found');
    }
    // 获取联系人签证信息
    Visa? visa = await shared.facebook.getVisa(identifier);
    _visa = visa;
    // 从签证中获取头像
    _avatar = _visa?.avatar;
    // 获取最后活跃时间（优先签证更新时间，其次登录时间）
    _lastActiveTime = _visa?.time;
    var pair = await shared.database.getLoginCommandMessage(identifier);
    DateTime? loginTime = pair.first?.time;
    if(_lastActiveTime == null){
      _lastActiveTime = loginTime;
    }else if(DocumentUtils.isBefore(loginTime, _lastActiveTime)){
      _lastActiveTime = loginTime;
    }
    // 检查好友关系
    if (user == null) {
      _friendFlag = null;
    } else {
      List<ID> contacts = await shared.facebook.getContacts(user.identifier);
      _friendFlag = contacts.contains(identifier);
    }
    // 解析语言和客户端信息
    _parseLanguage(visa);
    _parseClient(visa);
  }

  /// 从签证中获取指定section的指定key的字符串属性
  /// [visa] 联系人签证
  /// [section] 属性分区（如app、sys）
  /// [key] 属性名
  /// 返回解析后的字符串（空/非字符串返回null）
  String? _getStringProperty(Visa? visa, String section, String key) {
    var info = visa?.getProperty(section);
    if(info is Map) {} else {
      return null;
    }
    var text = info[key];
    if(text is String) {} else {
      return null;
    }
    text = text.trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  /// 从签证中解析语言信息
  /// [visa] 联系人签证
  void _parseLanguage(Visa? visa){
    LanguageItem? item;
    /// 优先解析app.language
    String? code1 = _getStringProperty(visa, 'app', 'language');
    item = getLanguageItem(code1);
    if(item != null){
      _language = item.name;
      _locale = code1;
      return;
    }
    // 其次解析sys.locale
    String? code2 = _getStringProperty(visa, 'sys', 'locale');
    item = getLanguageItem(code2);
    if (item != null) {
      _language = item.name;
      _locale = code2;
    }
    // 都解析失败时，保存原始编码
    _locale = code1 ?? code2;
  }

  /// 从签证中解析客户端信息（APP名称、版本、系统、应用商店）
  /// [visa] 联系人签证
  void _parseClient(Visa? visa) {
    String? name;
    String? version;
    String? os;
    String? store;
    // 解析app分区属性
    var app = visa?.getProperty('app');
    if (app is Map) {
      name = app['name'];
      name ??= app['id'];
      version = app['version'];
      store = app['store'];
    }
    // 解析sys分区的os属性
    var sys = visa?.getProperty('sys');
    if (sys is Map) {
      os = sys['os'];
      // 格式化系统名称
      if (os == 'ios') {
        os = 'iOS';
      } else if (os == 'android') {
        os = 'Android';
      } else if (os == 'macos') {
        os = 'MacOS';
      } else if (os == 'windows') {
        os = 'Windows';
      } else if (os == 'linux') {
        os = 'Linux';
      }
    }
    // 构建客户端信息文本
    if (name != null) {
      String? platform;
      if (os == null || os.isEmpty) {
        platform = store;
      } else if (store == null || store.isEmpty) {
        platform = os;
      } else {
        platform = '$os; $store';
      }
      if (platform == null || platform.isEmpty) {
        _clientInfo = '$name $version';
      } else {
        _clientInfo = '$name ($platform) $version';
      }
    }
  }

  /// 添加当前联系人为好友（带确认弹窗）
  /// [context] 上下文
  void add({required BuildContext context}) {
    // 获取当前登录用户
    GlobalVariable shared = GlobalVariable();
    shared.facebook.currentUser.then((user){
      if(user == null){
        logError('current user not found, failed to add contact: $identifier');
        if (context.mounted) {
          Alert.show(context, i18nTranslator.translate('Error'), 
          i18nTranslator.translate('Current user not found'));
        }
      }else if(context.mounted){
        // 显示确认弹窗
        Alert.confirm(context, i18nTranslator.translate('Confirm Add'), 
          i18nTranslator.translate('Sure to add this friend?'),
          okAction: () => _doAdd(context, identifier, user.identifier),
        );
      }
    });
  }

  /// 执行添加好友的具体逻辑
  /// [ctx] 上下文
  /// [contact] 要添加的联系人ID
  /// [user] 当前用户ID
  void _doAdd(BuildContext ctx, ID contact, ID user) {
    GlobalVariable shared = GlobalVariable();
    // 保存到数据库
    shared.database.addContact(contact, user: user).then((ok) {
      if (!ok && ctx.mounted) {
        Alert.show(ctx, i18nTranslator.translate('Error'), 
          i18nTranslator.translate('Failed to add contact'));
      }
    });
    // 推送当前用户的签证给新联系人
    var packer = shared.messenger?.packer;
    if(packer is SharedPacker){
      logInfo('push visa document to new contact: $contact');
      packer.pushVisa(contact);
    }
  }

  /// 删除当前联系人/群（带确认弹窗）
  /// [context] 上下文
  void delete({required BuildContext context}) {
    // 获取当前登录用户
    GlobalVariable shared = GlobalVariable();
    shared.facebook.currentUser.then((user) {
      if(user == null){
        logError('current user not found, failed to add contact: $identifier');
        if (context.mounted) {
          Alert.show(context, i18nTranslator.translate('Error'), 
            i18nTranslator.translate('Current user not found'));
        }
      }else{
        // 根据类型显示不同的确认文案
        String msg;
        if(identifier.isUser){
          msg = i18nTranslator.translate('Sure to remove this friend?');
        }else{
          msg = i18nTranslator.translate('Sure to remove this group?');
        }
        // 显示确认弹窗
        if(context.mounted){
          Alert.confirm(context, i18nTranslator.translate('Confirm Delete'), msg,
            okAction: () => _doRemove(context, identifier, user.identifier));
        }
      }
    });
  }

  /// 执行删除联系人的具体逻辑
  /// [ctx] 上下文
  /// [contact] 要删除的联系人/群ID
  /// [user] 当前用户ID
  void _doRemove(BuildContext ctx, ID contact, ID user) {
    //删除会话
    Amanuensis clerk = Amanuensis();
    clerk.removeConversation(contact).onError((error, stackTrace) {
      if (ctx.mounted) {
        Alert.show(ctx, i18nTranslator.translate('Error'), 
          i18nTranslator.translate('Failed to remove conversation'));
      }
      return false;
    });
    // 从数据库移除联系人
    GlobalVariable shared = GlobalVariable();
    shared.database.removeContact(contact, user: user).then((ok) {
      if (ok) {
        logWarning('contact removed: $contact, user: $user');
      } else if (ctx.mounted) {
        Alert.show(ctx, i18nTranslator.translate('Error'), 
          i18nTranslator.translate('Failed to remove contact'));
      }
    });
  }

  /// 从ID创建ContactInfo实例（带初始属性）
  /// [identifier] 联系人ID
  /// [unread] 未读数
  /// [lastMessage] 最后一条消息
  /// [lastMessageTime] 最后一条消息时间
  /// [mentionedSerialNumber] @我的消息序号
  /// 返回ContactInfo实例
  static ContactInfo from(ID identifier, {
    required int unread,
    required String? lastMessage,
    required DateTime? lastMessageTime,
    required int mentionedSerialNumber,
  }) {
    ContactInfo info = _ContactManager().getContactInfo(identifier);
    info.unread = unread;
    info.lastMessage = lastMessage;
    info.lastMessageTime = lastMessageTime;
    info.mentionedSerialNumber = mentionedSerialNumber;
    return info;
  }

  /// 从ID创建ContactInfo实例（仅用户ID，群ID返回null）
  /// [identifier] 联系人ID
  /// 返回ContactInfo实例或null
  static ContactInfo? fromID(ID identifier) {
    if (identifier.isGroup) {
      return null;
    }
    return _ContactManager().getContactInfo(identifier);
  }

  /// 从ID列表创建ContactInfo列表（过滤群ID）
  /// [contacts] ID列表
  /// 返回ContactInfo列表
  static List<ContactInfo> fromList(List<ID> contacts){
    List<ContactInfo> array = [];
    _ContactManager man = _ContactManager();
    for(ID item in contacts){
      if(item.isGroup){
        Log.warning('ignore group conversation: $item');
        continue;
      }
      array.add(man.getContactInfo(item));
    }
    return array;
  }
}

/// 联系人排序器：将联系人按名称首字母分组排序
class ContactSorter {

  /// 分组名称列表（如A、B、#）
  List<String> sectionNames = [];
  /// 分组索引到联系人列表的映射
  Map<int,List<ContactInfo>> sectionItems = {};

  /// 构建排序后的联系人分组
  /// [contacts] 待排序的联系人列表
  /// 返回排序器实例
  static ContactSorter build(List<ContactInfo> contacts) {
    ContactSorter sorter = ContactSorter();
    Set<String> set = {};
    Map<String,List<ContactInfo>> map = {};
    for(ContactInfo item in contacts){
      String name = item.name;
      // 获取首字母（空名称用#）
      String prefix = name.isEmpty ? "#" : name.substring(0,1).toUpperCase();
      // TODO: 拼音转换（适配中文）
      Log.debug('[$prefix] contact: $item');
      set.add(prefix);
      // 按首字母分组
      List<ContactInfo>? list = map[prefix];
      if(list == null){
        list = [];
        map[prefix] = list;
      }
      list.add(item);
    }
    // 初始化分组数据
    sorter.sectionNames = [];
    sorter.sectionItems = {};
    int index = 0;
    // 分组名称排序
    List<String> array= set.toList();
    array.sort();
    for(String prefix in array){
      sorter.sectionNames.add(prefix);
      // 每个分组内的联系人按名称排序
      sorter.sectionItems[index] = _sortContacts(map[prefix]);
      index += 1;
    }
    return sorter;
  }
}

/// 对联系人列表按名称升序排序
/// [contacts] 待排序的联系人列表
/// 返回排序后的列表
List<ContactInfo> _sortContacts(List<ContactInfo>? contacts) {
  if (contacts == null) {
    return [];
  }
  contacts.sort((a, b) => a.name.compareTo(b.name));
  return contacts;
}

/// 联系人管理器（单例）：缓存ContactInfo实例，避免重复创建
class _ContactManager {
  /// 工厂构造函数，保证单例
  factory _ContactManager() => _instance;
  /// 单例实例
  static final _ContactManager _instance = _ContactManager._internal();
  /// 私有构造函数
  _ContactManager._internal();

  /// 联系人ID到ContactInfo的映射缓存
  final Map<ID,ContactInfo> _contacts = {};

  /// 获取指定ID的ContactInfo实例（缓存不存在则创建）
  /// [identifier] 联系人ID
  /// 返回ContactInfo实例
  ContactInfo getContactInfo(ID identifier) {
    ContactInfo? info = _contacts[identifier];
    if(info == null){
      info = ContactInfo(identifier);
      _contacts[identifier] = info;
      // 加载联系人数据
      info.reloadData();
    }
    return info;
  }
}