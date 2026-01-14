/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2025 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2025 Albert Moky
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

import 'package:dimsdk/dimsdk.dart';
import 'package:lnc/log.dart';
import 'package:stargate/skywalker.dart';

import '../common/facebook.dart';
import '../common/messenger.dart';
import '../common/session.dart';
import '../common/dbi/account.dart';

/// 群组代理类
/// 实现GroupDataSource接口，提供群组相关数据的获取和管理能力
class GroupDelegate extends TwinsHelper implements GroupDataSource {
  /// 构造方法
  /// [facebook] - 用户信息管理实例
  /// [messenger] - 消息收发实例
  GroupDelegate(CommonFacebook facebook, CommonMessenger messenger)
    : super(facebook, messenger) {
    // 初始化群组机器人管理器的messenger
    _GroupBotsManager().messenger = messenger;
  }

  /// 重写获取facebook，强转为CommonFacebook类型
  @override
  CommonFacebook? get facebook => super.facebook as CommonFacebook?;

  /// 重写获取messenger，强转为CommonMessenger类型
  @override
  CommonMessenger? get messenger => super.messenger as CommonMessenger?;

  /// 获取档案管理员（用于文档存储）
  Archivist? get archivist => facebook?.archivist;

  /// 构建群组名称（根据成员昵称拼接）
  /// [members] - 群成员ID列表
  /// @return 拼接后的群组名称
  Future<String> buildGroupName(List<ID> members) async {
    assert(members.isNotEmpty, 'members should not be empty here');
    CommonFacebook facebook = this.facebook!;
    // 获取第一个成员的名称作为起始
    String text = await facebook.getName(members.first);
    String nickname;
    // 拼接其他成员名称
    for (int i = 1; i < members.length; ++i) {
      nickname = await facebook.getName(members[i]);
      if (nickname.isEmpty) {
        continue;
      }
      text += ', $nickname';
      // 名称长度超过32时截断并添加省略号
      if (text.length > 32) {
        return '${text.substring(0, 28)} ...';
      }
    }
    return text;
  }

  //
  //  Entity DataSource 接口实现
  //

  /// 获取指定标识的元数据
  /// [identifier] - 实体ID（用户/群组）
  /// @return 元数据对象
  @override
  Future<Meta?> getMeta(ID identifier) async =>
      await facebook?.getMeta(identifier);

  /// 获取指定标识的文档列表
  /// [identifier] - 实体ID（用户/群组）
  /// @return 文档列表
  @override
  Future<List<Document>> getDocuments(ID identifier) async =>
      await facebook!.getDocuments(identifier);

  /// 获取群组公告文档
  /// [group] - 群组ID
  /// @return 公告文档
  Future<Bulletin?> getBulletin(ID group) async =>
      await facebook?.getBulletin(group);

  /// 保存文档
  /// [doc] - 要保存的文档
  /// @return 保存成功返回true
  Future<bool> saveDocument(Document doc) async =>
      await archivist!.saveDocument(doc);

  //
  //  Group DataSource 接口实现
  //

  /// 获取群组创建者
  /// [group] - 群组ID
  /// @return 创建者ID
  @override
  Future<ID?> getFounder(ID group) async => await facebook?.getFounder(group);

  /// 获取群组所有者（群主）
  /// [group] - 群组ID
  /// @return 群主ID
  @override
  Future<ID?> getOwner(ID group) async => await facebook?.getOwner(group);

  /// 获取群成员列表
  /// [group] - 群组ID
  /// @return 成员ID列表
  @override
  Future<List<ID>> getMembers(ID group) async =>
      await facebook!.getMembers(group);

  /// 保存群成员列表
  /// [members] - 成员ID列表
  /// [group] - 群组ID
  /// @return 保存成功返回true
  Future<bool> saveMembers(List<ID> members, ID group) async =>
      await facebook!.saveMembers(members, group);

  //
  //  Group Assistants（群组机器人）相关方法
  //

  /// 获取群组机器人列表
  /// [group] - 群组ID
  /// @return 机器人ID列表
  @override
  Future<List<ID>> getAssistants(ID group) async =>
      await _GroupBotsManager().getAssistants(group);

  /// 获取响应最快的群组机器人
  /// [group] - 群组ID
  /// @return 最快响应的机器人ID
  Future<ID?> getFastestAssistant(group) async =>
      await _GroupBotsManager().getFastestAssistant(group);

  /// 设置通用的群组机器人列表
  /// [bots] - 机器人ID列表
  void setCommonAssistants(List<ID> bots) =>
      _GroupBotsManager().setCommonAssistants(bots);

  /// 更新机器人的响应时间
  /// [content] - 回执命令
  /// [envelope] - 消息信封
  /// @return 更新成功返回true
  bool updateRespondTime(ReceiptCommand content, Envelope envelope) =>
      _GroupBotsManager().updateRespondTime(content, envelope);

  //
  //  Administrators（管理员）相关方法
  //

  /// 获取群组管理员列表
  /// [group] - 群组ID
  /// @return 管理员ID列表
  Future<List<ID>> getAdministrators(ID group) async =>
      await facebook!.getAdministrators(group);

  /// 保存群组管理员列表
  /// [admins] - 管理员ID列表
  /// [group] - 群组ID
  /// @return 保存成功返回true
  Future<bool> saveAdministrators(List<ID> admins, ID group) async =>
      await facebook!.saveAdministrators(admins, group);

  //
  //  Membership（成员身份校验）相关方法
  //

  /// 校验是否为群组创建者
  /// [user] - 用户ID
  /// [group] - 群组ID
  /// @return 是创建者返回true
  Future<bool> isFounder(ID user, {required ID group}) async {
    assert(user.isUser && group.isGroup, 'ID error: $user, $group');
    ID? founder = await getFounder(group);
    if (founder != null) {
      return founder == user;
    }
    // 未找到创建者时，通过公钥匹配校验
    Meta? gMeta = await getMeta(group);
    Meta? mMeta = await getMeta(user);
    if (gMeta == null || mMeta == null) {
      assert(false, 'failed to get meta for group: $group, user: $user');
      return false;
    }
    return MetaUtils.matchPublicKey(mMeta.publicKey, gMeta);
  }

  /// 校验是否为群主
  /// [user] - 用户ID
  /// [group] - 群组ID
  /// @return 是群主返回true
  Future<bool> isOwner(ID user, {required ID group}) async {
    assert(user.isUser && group.isGroup, 'ID error: $user, $group');
    ID? owner = await getOwner(group);
    if (owner != null) {
      return owner == user;
    }
    // 未找到群主时，对于普通群组，创建者即为群主
    if (group.type == EntityType.GROUP) {
      return await isFounder(user, group: group);
    }
    throw Exception('only Polylogue so far');
  }

  /// 校验是否为群成员
  /// [user] - 用户ID
  /// [group] - 群组ID
  /// @return 是成员返回true
  Future<bool> isMember(ID user, {required ID group}) async {
    assert(user.isUser && group.isGroup, 'ID error: $user, $group');
    List<ID> members = await getMembers(group);
    return members.contains(user);
  }

  /// 校验是否为群管理员
  /// [user] - 用户ID
  /// [group] - 群组ID
  /// @return 是管理员返回true
  Future<bool> isAdministrator(ID user, {required ID group}) async {
    assert(user.isUser && group.isGroup, 'ID error: $user, $group');
    List<ID> admins = await getAdministrators(group);
    return admins.contains(user);
  }

  /// 校验是否为群组机器人
  /// [user] - 用户ID
  /// [group] - 群组ID
  /// @return 是机器人返回true
  Future<bool> isAssistant(ID user, {required ID group}) async {
    assert(user.isUser && group.isGroup, 'ID error: $user, $group');
    List<ID> bots = await getAssistants(group);
    return bots.contains(user);
  }
}

//
//  内部工具类：TripletsHelper（三元助手基类）
//
abstract class TripletsHelper with Logging {
  /// 构造方法
  /// [delegate] - 群组代理对象
  TripletsHelper(this.delegate);

  // 群组代理对象
  final GroupDelegate delegate;

  // 获取facebook实例
  CommonFacebook? get facebook => delegate.facebook;

  // 获取messenger实例
  CommonMessenger? get messenger => delegate.messenger;

  // 获取数据库实例
  AccountDBI? get database => facebook?.database;
}

//
//  内部单例类：_GroupBotsManager（群组机器人管理器）
//
class _GroupBotsManager extends Runner with Logging {
  /// 单例工厂方法
  factory _GroupBotsManager() => _instance;
  static final _GroupBotsManager _instance = _GroupBotsManager._internal();

  /// 私有构造方法
  _GroupBotsManager._internal() : super(Runner.INTERVAL_SLOW) {
    /* await */
    run();
  }

  // 通用机器人列表
  List<ID> _commonAssistants = [];

  // 待检查的机器人候选集
  Set<ID> _candidates = {};
  // 机器人响应时间映射表
  final Map<ID, Duration> _respondTimes = {};

  // 消息收发器弱引用
  WeakReference<CommonMessenger>? _transceiver;

  /// 获取消息收发器
  CommonMessenger? get messenger => _transceiver?.target;

  /// 设置消息收发器
  set messenger(CommonMessenger? delegate) =>
      _transceiver = delegate == null ? null : WeakReference(delegate);

  /// 获取facebook实例
  CommonFacebook? get facebook => messenger?.facebook;

  /// 收到机器人的回执命令时，更新该机器人的响应速度
  /// [content] - 回执命令
  /// [envelope] - 消息信封
  /// @return 更新成功返回true
  bool updateRespondTime(ReceiptCommand content, Envelope envelope) {
    // 1. 检查发送者是否为机器人：只有机器人的回执才需要统计
    ID sender = envelope.sender;
    if (sender.type != EntityType.BOT) {
      // 不是机器人 → 直接返回false，不统计
      return false;
    }
    // 2. 校验回执的合法性：确保回执是机器人对「发给自己的消息」的回应
    ID? originalReceiver = content.originalEnvelope?.receiver;
    if (originalReceiver != sender) {
      // 原始消息的接收者不是这个机器人 → 非法回执，不统计
      return false;
    }
    // 3. 校验时间有效性：获取原始消息的发送时间
    DateTime? time = content.originalEnvelope?.time;
    if (time == null || DateTime.now().difference(time).inMicroseconds <= 0) {
      // 时间无效 → 不统计
      return false;
    }
    // 4. 记录最优响应时间：只保存「更快」的耗时（缓存中已有更优值则不更新）
    Duration duration = DateTime.now().difference(time);
    Duration? cached = _respondTimes[sender];
    if (cached != null && cached <= duration) {
      // 缓存的耗时更短 → 不更新
      return false;
    }
    _respondTimes[sender] = duration; // 保存更优的响应时间
    return true;
  }

  /// 收到服务提供商的新配置时，设置通用机器人列表
  /// [bots] - 机器人ID列表
  void setCommonAssistants(List<ID> bots) {
    logInfo('add group bots: $bots into $_candidates');
    _candidates.addAll(bots);
    _commonAssistants = bots;
  }

  /// 获取指定群组的机器人列表
  /// [group] - 群组ID
  /// @return 机器人ID列表
  Future<List<ID>> getAssistants(ID group) async {
    List<ID>? bots = await facebook?.getAssistants(group);
    if (bots == null || bots.isEmpty) {
      return _commonAssistants;
    }
    _candidates.addAll(bots);
    return bots;
  }

  /// 获取响应最快的群组机器人
  /// [group] - 群组ID
  /// @return 最快响应的机器人ID
  Future<ID?> getFastestAssistant(ID group) async {
    List<ID>? bots = await getAssistants(group);
    if (bots.isEmpty) return null;

    ID? prime; // 最快的机器人ID
    Duration? primeDuration; // 最快的耗时

    for (ID ass in bots) {
      Duration? duration = _respondTimes[ass]; // 获取该机器人的响应耗时
      if (duration == null) continue; // 无响应记录 → 跳过

      // 核心逻辑：对比耗时，保留更短的
      if (primeDuration == null) {
        // 第一个有响应的机器人 → 暂定为最快
        prime = ass;
        primeDuration = duration;
      } else if (primeDuration < duration) {
        // 当前机器人比已选的慢 → 跳过
        continue;
      } else {
        // 当前机器人更快 → 更新最快记录
        prime = ass;
        primeDuration = duration;
      }
    }

    // 无任何响应记录 → 返回第一个机器人；否则返回最快的
    return prime ?? bots.first;
  }

  ///  Runner接口实现：定时检查机器人状态
  /// @return 处理成功返回true
  @override
  Future<bool> process() async {
    CommonMessenger? transceiver = messenger;
    if (transceiver == null) {
      return false;
    }
    //
    //  1. 检查会话状态（是否已登录）
    //
    Session session = transceiver.session;
    if (session.sessionKey == null || !session.isActive) {
      // 未登录，不处理
      return false;
    }
    //
    //  2. 获取当前用户的签证
    //
    Visa? visa;
    try {
      User? me = await facebook?.currentUser;
      visa = await me?.visa;
      if (visa == null) {
        logError('failed to get visa: $me');
        return false;
      }
    } catch (e, st) {
      logError('failed to get current user: $e, $st');
      return false;
    }
    var checker = facebook?.entityChecker;
    //
    //  3. 检查候选机器人列表
    //
    Set<ID> bots = _candidates;
    _candidates = {};
    for (ID item in bots) {
      if (_respondTimes[item] != null) {
        // 已有响应，无需再次检查
        logInfo('group bot already responded: $item');
        continue;
      }
      // 无响应，尝试向机器人推送签证
      try {
        await checker?.sendVisa(visa, item);
      } catch (e, st) {
        logError('failed to query assistant: $item, $e, $st');
      }
    }
    return false;
  }
}
