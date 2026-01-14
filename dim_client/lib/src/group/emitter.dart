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

import '../common/messenger.dart';

import 'delegate.dart';
import 'packer.dart';

/// 群组消息发送器
/// 负责处理群组消息的发送逻辑，包括转发给机器人、拆分发送给成员等
class GroupEmitter extends TripletsHelper {
  /// 构造方法
  /// [super.delegate] - 父类初始化，传入群组代理对象
  GroupEmitter(super.delegate);

  // 注意：群组机器人可以帮助成员转发消息
  //
  //      如果成员数量 < POLYLOGUE_LIMIT，
  //          表示这是小群，由成员自己拆分并发送消息，
  //          这样可以保证群组隐私（没人能知道群组ID）；
  //      否则，
  //          在公告文档中设置"assistants"字段，告知所有成员
  //          可以让群组机器人代劳发送消息。
  //
  /// 普通群组成员数量阈值（超过则使用机器人转发）
  static int POLYLOGUE_LIMIT = 32;

  // 注意：暴露群组ID以减少加密耗时
  //
  //      如果成员数量 < SECRET_GROUP_LIMIT，
  //          表示这是微型群，可以选择隐藏群组ID，
  //          逐个拆分并加密消息；
  //      否则，
  //          应在即时消息层暴露群组ID，
  //          使用群组对称密钥加密消息，然后
  //          直接拆分并发送给所有成员。
  //
  /// 私密群组成员数量阈值（超过则暴露群组ID）
  static int SECRET_GROUP_LIMIT = 16;

  // 群组打包器（懒加载）
  late final GroupPacker packer = createPacker();

  /// 创建群组打包器（可重写以自定义实现）
  GroupPacker createPacker() => GroupPacker(delegate);

  /// 为即时消息附加群组时间信息（文档时间和历史时间）
  /// [group] - 群组ID
  /// [iMsg] - 即时消息
  /// @return 附加成功返回true
  Future<bool> attachGroupTimes(ID group, InstantMessage iMsg) async {
    // 群组命令无需附加时间
    if (iMsg.content is GroupCommand) {
      return false;
    }
    // 获取群组公告文档
    Bulletin? doc = await facebook?.getBulletin(group);
    if (doc == null) {
      assert(false, 'failed to get bulletin document for group: $group');
      return false;
    }
    // 附加文档时间
    DateTime? lastDocumentTime = doc.time;
    if (lastDocumentTime == null) {
      assert(false, 'document error: $doc');
    } else {
      iMsg.setDateTime('GDT', lastDocumentTime);
    }
    // 附加历史时间
    var checker = facebook?.entityChecker;
    DateTime? lastHistoryTime = await checker?.getLastGroupHistoryTime(group);
    if (lastHistoryTime == null) {
      assert(false, 'failed to get history time: $group');
    } else {
      iMsg.setDateTime('GHT', lastHistoryTime);
    }
    return true;
  }

  /// 发送即时消息（群组消息专用）
  /// [iMsg] - 即时消息
  /// [priority] - 消息优先级（默认0）
  /// @return 发送成功返回可靠消息，失败返回null
  Future<ReliableMessage?> sendInstantMessage(
    InstantMessage iMsg, {
    int priority = 0,
  }) async {
    //
    // 0. 检查群组信息
    //
    Content content = iMsg.content;
    ID? group = content.group;
    if (group == null) {
      assert(false, 'not a group message: $iMsg');
      return null;
    } else {
      assert(iMsg.receiver == group, 'group message error: $iMsg');
      logInfo(
        'sending message (type=${content.type}): ${iMsg.sender} => $group',
      );
      // 为消息附加群文档时间和历史时间（用于接收方校验群组信息是否同步）
      bool ok = await attachGroupTimes(group, iMsg);
      assert(
        ok || content is GroupCommand,
        'failed to attach group times: $group => $content',
      );
    }
    assert(iMsg.receiver == group, 'group message error: $iMsg');

    /// TODO: 如果是文件消息
    ///       请先上传文件数据
    ///       再调用此方法
    assert(
      content is! FileContent || content.data == null,
      'content error: $content',
    );

    //
    //  1. 检查群组机器人
    //
    ID? prime = await delegate.getFastestAssistant(group);
    if (prime != null) {
      // 存在群组机器人，将消息转发给机器人，由其拆分发送（减少本地工作量）
      return await _forwardMessage(
        iMsg,
        prime,
        group: group,
        priority: priority,
      );
    }

    //
    //  2. 检查群成员数量
    //
    List<ID> members = await delegate.getMembers(group);
    if (members.isEmpty) {
      assert(false, 'failed to get members for group: $group');
      return null;
    }
    // 公告文档中没有找到机器人，需拆分消息并逐个发送给成员
    if (members.length < SECRET_GROUP_LIMIT) {
      // 微型群：先拆分，再加签名，最后逐个发送
      int success = await _splitAndSendMessage(
        iMsg,
        members,
        group: group,
        priority: priority,
      );
      logInfo('split $success message(s) for group: $group');
      return null;
    } else {
      logInfo(
        'splitting message for ${members.length} members of group: $group',
      );
      // 大型群：先加密签名，再拆分，最后逐个发送
      return await _disperseMessage(
        iMsg,
        members,
        group: group,
        priority: priority,
      );
    }
  }

  /// 加密签名消息后转发给机器人
  /// [iMsg] - 即时消息
  /// [bot] - 机器人ID
  /// [group] - 群组ID
  /// [priority] - 消息优先级
  /// @return 转发成功返回可靠消息
  Future<ReliableMessage?> _forwardMessage(
    InstantMessage iMsg,
    ID bot, {
    required ID group,
    int priority = 0,
  }) async {
    assert(bot.isUser && group.isGroup, 'ID error: $bot, $group');
    // 注意：群组机器人不能是群成员，因此
    //       向机器人发送群组命令时，需将机器人设为接收者，
    //       并在内容中设置群组ID（直接发送给机器人）。
    CommonMessenger? transceiver = messenger;

    // 指定了群组机器人，由机器人拆分消息，
    // 因此必须暴露群组ID；这会让客户端使用
    // "用户到群组"的加密密钥加密消息内容，
    // 该密钥会被每个成员的公钥加密，因此
    // 所有成员都会收到机器人拆分的消息，
    // 但机器人无法解密。
    iMsg.setString('group', group);

    // 群组机器人只能获取消息签名，
    // 无法解密内容获取sn（序列号），通常无影响；
    // 但有时需要回执中包含原sn，因此建议同时暴露sn
    iMsg['sn'] = iMsg.content.sn;

    //
    //  1. 打包消息
    //
    ReliableMessage? rMsg = await packer.encryptAndSignMessage(iMsg);
    if (rMsg == null) {
      assert(
        false,
        'failed to encrypt & sign message: ${iMsg.sender} => $group',
      );
      return null;
    }

    //
    //  2. 将群组消息转发给机器人
    //
    Content content = ForwardContent.create(forward: rMsg);
    var pair = await transceiver?.sendContent(
      content,
      sender: null,
      receiver: bot,
      priority: priority,
    );
    if (pair == null || pair.second == null) {
      assert(false, 'failed to forward message for group: $group, bot: $bot');
    }

    // 返回转发的消息
    return rMsg;
  }

  /// 加密签名消息后分发给所有成员
  /// [iMsg] - 即时消息
  /// [members] - 成员列表
  /// [group] - 群组ID
  /// [priority] - 消息优先级
  /// @return 分发成功返回可靠消息
  Future<ReliableMessage?> _disperseMessage(
    InstantMessage iMsg,
    List<ID> members, {
    required ID group,
    int priority = 0,
  }) async {
    assert(group.isGroup, 'group ID error: $group');
    CommonMessenger? transceiver = messenger;

    // 注意：成员数量过多时，
    //       如果仍隐藏群组ID，加密成本会很高。
    // 因此，
    //      在消息信封中暴露"group"字段，
    //      使用用户到群组的密钥加密消息内容，
    //      接收方可以通过准确的方向（发送者->群组）获取解密密钥
    iMsg.setString('group', group);

    ID sender = iMsg.sender;

    //
    //  0. 打包消息
    //
    ReliableMessage? rMsg = await packer.encryptAndSignMessage(iMsg);
    if (rMsg == null) {
      assert(false, 'failed to encrypt & sign message: $sender => $group');
      return null;
    }

    //
    //  1. 拆分消息
    //
    List<ReliableMessage> messages = await packer.splitReliableMessage(
      rMsg,
      members,
    );
    ID receiver;
    bool? ok;
    for (ReliableMessage msg in messages) {
      receiver = msg.receiver;
      if (sender == receiver) {
        assert(false, 'cycled message: $sender => $receiver, $group');
        continue;
      }
      //
      //  2. 发送消息
      //
      ok = await transceiver?.sendReliableMessage(msg, priority: priority);
      assert(
        ok == true,
        'failed to send message: $sender => $receiver, $group',
      );
    }
    return rMsg;
  }

  /// 拆分消息并逐个加密签名发送给所有成员
  /// [iMsg] - 即时消息
  /// [members] - 成员列表
  /// [group] - 群组ID
  /// [priority] - 消息优先级
  /// @return 成功发送的消息数量
  Future<int> _splitAndSendMessage(
    InstantMessage iMsg,
    List<ID> members, {
    required ID group,
    int priority = 0,
  }) async {
    assert(group.isGroup, 'group ID error: $group');
    assert(!iMsg.containsKey('group'), 'should not happen');
    CommonMessenger? transceiver = messenger;

    // 注意：这是微型群
    //       建议不暴露群组ID以最大化隐私，
    //       代价是无法使用用户到群组的密钥；
    //       因此其他成员只能将其视为个人消息，
    //       使用用户到用户的对称密钥解密内容，
    //       解密后才能获取群组ID。

    ID sender = iMsg.sender;
    int success = 0;

    //
    //  1. 拆分消息
    //
    List<InstantMessage> messages = await packer.splitInstantMessage(
      iMsg,
      members,
    );
    ID receiver;
    ReliableMessage? rMsg;
    for (InstantMessage msg in messages) {
      receiver = msg.receiver;
      if (sender == receiver) {
        assert(false, 'cycled message: $sender => $receiver, $group');
        continue;
      }
      //
      //  2. 发送消息
      //
      rMsg = await transceiver?.sendInstantMessage(msg, priority: priority);
      if (rMsg == null) {
        logError('failed to send message: $sender => $receiver, $group');
        continue;
      }
      success += 1;
    }
    // 返回成功发送的数量
    return success;
  }
}
