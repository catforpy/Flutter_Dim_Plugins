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

import 'package:dimsdk/dimsdk.dart'; // DIM核心协议库（消息/命令模型）
import 'package:lnc/log.dart'; // 日志工具（打印日志）
import 'package:object_key/object_key.dart'; // 通用数据结构（Pair/Triplet键值对）

import '../../common/facebook.dart'; // 通用Facebook接口（扩展基础Facebook）
import '../../common/messenger.dart'; // 通用Messenger接口（扩展基础Messenger）
import '../../group/delegate.dart'; // 群组代理（提供数据访问能力）
import '../../group/helper.dart'; // 群组助手（提供工具方法）
import '../../group/builder.dart'; // 群组构建器（构建历史消息）

/// 历史命令处理器（基础类）
/// 设计定位：所有历史命令处理器的父类，提供基础能力和默认实现
/// 核心功能：
/// 1. 提供Facebook/Messenger的类型转换（转为通用版本）；
/// 2. 提供群组相关的核心实例（delegate/helper/builder）；
/// 3. 默认返回“不支持”的回执（子类可覆盖实现具体逻辑）；
class HistoryCommandProcessor extends BaseCommandProcessor with Logging {
  /// 构造方法
  /// [facebook] - 基础Facebook实例
  /// [messenger] - 基础Messenger实例
  HistoryCommandProcessor(super.facebook, super.messenger);

  /// 类型转换：将基类Facebook转为通用CommonFacebook
  /// 目的：获取通用Facebook的扩展能力（更多数据访问方法）
  @override
  CommonFacebook? get facebook => super.facebook as CommonFacebook?;

  /// 类型转换：将基类Messenger转为通用CommonMessenger
  /// 目的：获取通用Messenger的扩展能力（更多消息处理方法）
  @override
  CommonMessenger? get messenger => super.messenger as CommonMessenger?;

  /// 处理历史命令的核心方法（默认实现）
  /// 核心逻辑：返回“不支持”的回执（子类需覆盖实现具体业务）
  /// [content] - 历史命令内容
  /// [rMsg] - 可靠消息
  /// 返回值：包含错误回执的内容列表
  @override
  Future<List<Content>> processContent(
    Content content,
    ReliableMessage rMsg,
  ) async {
    // 断言：确保传入的内容是HistoryCommand类型（开发阶段校验）
    assert(content is HistoryCommand, 'history command error: $content');
    HistoryCommand command = content as HistoryCommand;
    // 返回不支持的回执（包含模版和替换参数，便于前端展示）
    String text = 'Command not support.';
    return respondReceipt(
      text,
      envelope: rMsg.envelope,
      extra: {
        'template': 'History command (name: \${command}) not support yet!',
        'replacements': {'command': command.cmd},
      },
    );
  }

  //
  //  群组历史相关实例（延迟初始化，首次访问时创建）
  //

  /// 群组代理（核心依赖：提供群组数据访问能力，如群主/管理员/成员列表）
  // protected（Dart通过命名规范模拟protected）
  late final GroupDelegate delegate = createdDelegate();

  /// 群组助手（工具类：提供命令过期检查/成员提取等工具方法）
  // protected
  late final GroupCommandHelper helper = createdHelper();

  /// 群组构建器（功能类：构建群组历史消息列表）
  // protected
  late final GroupHistoryBuilder builder = createBuilder();

  /// 创建群组代理（扩展点：子类可覆盖自定义实现）
  /// 注释说明：override for customized data source（为自定义数据源重写）
  GroupDelegate createdDelegate() => GroupDelegate(facebook!, messenger!);

  /// 创建群组助手（扩展点：子类可覆盖自定义实现）
  /// 注释说明：override for customized helper（为自定义工具方法重写）
  GroupCommandHelper createdHelper() => GroupCommandHelper(delegate);

  /// 创建群组构建器（扩展点：子类可覆盖自定义实现）
  /// 注释说明：override for customized builder（为自定义构建逻辑重写）
  GroupHistoryBuilder createBuilder() => GroupHistoryBuilder(delegate);
}

/// 群组命令处理器（核心基础类）
/// 设计定位：所有群组子命令处理器的父类，封装通用的群组处理能力
/// 核心功能：
/// 1. 封装群组相关的通用方法（获取/保存群主/管理员/成员）；
/// 2. 提供命令校验工具方法（过期检查/成员校验/群组信息校验）；
/// 3. 提供群组历史消息发送能力；
/// 4. 默认返回“不支持”的回执（子类需覆盖实现具体群组命令逻辑）；
class GroupCommandProcessor extends HistoryCommandProcessor {
  /// 构造方法（继承父类）
  GroupCommandProcessor(super.facebook, super.messenger);

  // ========== 群主相关方法 ==========
  /// 获取群主ID（封装delegate的方法）
  /// [group] - 群组ID
  /// 返回值：群主ID（null表示无群主）
  // protected
  Future<ID?> getOwner(ID group) async => await delegate.getOwner(group);

  // ========== 群助理相关方法 ==========
  /// 获取群助理列表（机器人/客服账号）
  /// [group] - 群组ID
  /// 返回值：群助理ID列表
  // protected
  Future<List<ID>> getAssistants(ID group) async =>
      await delegate.getAssistants(group);

  // ========== 管理员相关方法 ==========
  /// 获取群管理员列表
  /// [group] - 群组ID
  /// 返回值：管理员ID列表
  // protected
  Future<List<ID>> getAdministrators(ID group) async =>
      await delegate.getAdministrators(group);

  /// 保存群管理员列表（持久化）
  /// [group] - 群组ID
  /// [admins] - 新的管理员列表
  /// 返回值：保存结果（true=成功，false=失败）
  // protected
  Future<bool> saveAdministrators(ID group, List<ID> admins) async =>
      await delegate.saveAdministrators(admins, group);

  // ========== 成员相关方法 ==========
  /// 获取群成员列表
  /// [group] - 群组ID
  /// 返回值：成员ID列表
  // protected
  Future<List<ID>> getMembers(ID group) async =>
      await delegate.getMembers(group);

  /// 保存群成员列表（持久化）
  /// [group] - 群组ID
  /// [members] - 新的成员列表
  /// 返回值：保存结果（true=成功，false=失败）
  // protected
  Future<bool> saveMembers(ID group, List<ID> members) async =>
      await delegate.saveMembers(members, group);

  // ========== 群历史相关方法 ==========
  /// 保存群组命令到群历史（持久化）
  /// [group] - 群组ID
  /// [content] - 群组命令内容
  /// [rMsg] - 可靠消息
  /// 返回值：保存结果（true=成功，false=失败）
  // protected
  Future<bool> saveGroupHistory(
    ID group,
    GroupCommand content,
    ReliableMessage rMsg,
  ) async => await helper.saveGroupHistory(group, content, rMsg);

  /// 处理群组命令的核心方法（默认实现）
  /// 核心逻辑：返回“不支持”的回执（子类需覆盖实现具体群组命令逻辑）
  /// [content] - 群组命令内容
  /// [rMsg] - 可靠消息
  /// 返回值：包含错误回执的内容列表
  @override
  Future<List<Content>> processContent(
    Content content,
    ReliableMessage rMsg,
  ) async {
    // 断言：确保传入的内容是GroupCommand类型（开发阶段校验）
    assert(content is GroupCommand, 'group command error: $content');
    GroupCommand command = content as GroupCommand;
    // 返回不支持的回执（包含模版和替换参数）
    String text = 'Command not support.';
    return respondReceipt(
      text,
      content: content,
      envelope: rMsg.envelope,
      extra: {
        'template': 'Group command (name: \${command}) not support yet!',
        'replacements': {'command': command.cmd},
      },
    );
  }

  // ========== 命令校验工具方法 ==========
  /// 检查命令是否过期（核心校验逻辑）
  /// 设计目的：防止处理过期的群组命令，保证数据一致性
  /// [content] - 群组命令内容
  /// [rMsg] - 可靠消息
  /// 返回值：Pair(群组ID(过期则为null), 错误回执列表(过期则非空))
  // protected
  Future<Pair<ID?, List<Content>?>> checkCommandExpired(
    GroupCommand content,
    ReliableMessage rMsg,
  ) async {
    ID? group = content.group;
    if (group == null) {
      // 群组ID为空 → 断言失败
      assert(false, 'group command error: $content');
      return Pair(null, null);
    }
    List<Content>? errors;
    // 检查命令是否过期（通过helper工具方法）
    bool expired = await helper.isCommandExpired(content);
    if (expired) {
      // 命令过期 -> 返回错误回执
      String text = 'Command expired.';
      errors = respondReceipt(
        text,
        content: content,
        envelope: rMsg.envelope,
        extra: {
          'template': 'Group command expired: \${cmd}, group: \${gid}',
          'replacements': {'cmd': content.cmd, 'gid': group.toString()},
        },
      );
      group = null; // 标记群组ID为空，表示命令无效
    } else {
      // 命令有效 → 无错误回执
      errors = null;
    }
    return Pair(group, errors);
  }

  /// 检查命令中的成员列表是否有效
  /// 设计目的：确保群组命令包含有效的成员列表
  /// [content] - 群组命令内容
  /// [rMsg] - 可靠消息
  /// 返回值：Pair(成员列表, 错误回执列表(成员为空则非空))
  // protected
  Future<Pair<List<ID>, List<Content>?>> checkCommandMembers(
    GroupCommand content,
    ReliableMessage rMsg,
  ) async {
    ID? group = content.group;
    if (group == null) {
      // 群组ID为空 → 断言失败
      assert(false, 'group command error: $content');
      return Pair([], null);
    }
    List<Content>? errors;
    // 从命令中提取成员列表（通过helper工具方法）
    List<ID> members = await helper.getMembersFromCommand(content);
    if (members.isEmpty) {
      // 成员列表为空 → 返回错误回执
      String text = 'Command error.';
      errors = respondReceipt(
        text,
        content: content,
        envelope: rMsg.envelope,
        extra: {
          'template': 'Group members empty: \${gid}',
          'replacements': {'gid': group.toString()},
        },
      );
    } else {
      // 成员列表有效 → 无错误回执
      errors = null;
    }
    return Pair(members, errors);
  }

  /// 检查群组的成员信息是否有效（群主+成员）
  /// 设计目的：确保群组有有效的群主和成员列表
  /// [content] - 群组命令内容
  /// [rMsg] - 可靠消息
  /// 返回值：Triplet(群主ID, 成员列表, 错误回执列表(信息异常则非空))
  // protected
  Future<Triplet<ID?, List<ID>, List<Content>?>> checkGroupMembers(
    GroupCommand content,
    ReliableMessage rMsg,
  ) async {
    ID? group = content.group;
    if (group == null) {
      // 群组ID为空 → 断言失败
      assert(false, 'group command error: $content');
      return Triplet(null, [], null);
    }
    List<Content>? errors;
    // 获取群主ID和成员列表（通过delegate数据访问）
    ID? owner = await getOwner(group);
    List<ID> members = await getMembers(group);
    if (owner == null || members.isEmpty) {
      // 群组信息异常（无群主/无成员）→ 返回错误回执
      // TODO: 可扩展为自动查询群成员（补充注释：待实现的扩展点）
      String text = 'Group empty.';
      errors = respondReceipt(
        text,
        content: content,
        envelope: rMsg.envelope,
        extra: {
          'template': 'Group empty: \${gid}',
          'replacements': {'gid': group.toString()},
        },
      );
    } else {
      // 群组信息有效 → 无错误回执
      errors = null;
    }
    return Triplet(owner, members, errors);
  }

  /// 向指定接收者发送最新的群组历史命令（同步成员列表）
  /// 核心场景：新成员加入群组后，同步历史成员变更记录
  /// [group] - 目标群组ID
  /// [receiver] - 接收者ID（新成员）
  /// 返回值：发送结果（true=成功，false=失败）
  Future<bool> sendGroupHistories({
    required ID group,
    required ID receiver,
  }) async {
    // 构建群组历史消息列表（包含所有成员变更的命令）
    List<ReliableMessage> messages = await builder.buildGroupHistories(group);
    if (messages.isEmpty) {
      // 构建失败 → 记录警告日志
      logWarning('failed to build history for group: $group');
      return false;
    }
    // 创建转发内容（包含历史消息列表）
    Content content = ForwardContent.create(secrets: messages);
    // 发送转发内容给接收者（优先级1：高优先级）
    var pair = await messenger?.sendContent(
      content,
      sender: null,
      receiver: receiver,
      priority: 1,
    );
    // 返回发送结果（pair.second不为null表示成功）
    return pair?.second != null;
  }
}
