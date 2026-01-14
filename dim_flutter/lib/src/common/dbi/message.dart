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

import 'package:dim_client/ok.dart';
import 'package:dim_client/plugins.dart';

/// 即时消息数据库接口
/// 用于管理会话中的即时消息存储、查询和删除
abstract class InstantMessageDBI {

  ///  获取已存储的消息列表（分页查询）
  ///
  /// @param chat  - 会话ID（联系人/群组ID）
  /// @param start - 起始位置（用于分页，从0开始）
  /// @param limit - 最大查询数量（分页大小）
  /// @return 消息列表 + 剩余消息数（0表示本地已缓存全部消息）
  Future<Pair<List<InstantMessage>, int>> getInstantMessages(ID chat,
      {int start = 0, int? limit});

  ///  保存单条即时消息
  ///
  /// @param chat - 会话ID（联系人/群组ID）
  /// @param iMsg - 即时消息实例
  /// @return 操作成功返回true
  Future<bool> saveInstantMessage(ID chat, InstantMessage iMsg);

  ///  删除指定的单条消息
  ///
  /// @param chat     - 会话ID（联系人/群组ID）
  /// @param envelope - 消息信封（包含收发信息）
  /// @param content  - 消息内容
  /// @return 有数据被影响返回true
  Future<bool> removeInstantMessage(ID chat, Envelope envelope, Content content);

  ///  删除指定会话中的所有消息
  ///
  /// @param chat - 会话ID（联系人/群组ID）
  /// @return 有数据被影响返回true
  Future<bool> removeInstantMessages(ID chat);
}

/// 消息追踪数据库接口
/// 用于管理消息的传输轨迹（MTA列表），记录消息经过的中转节点
abstract class TraceDBI {

  ///  获取指定消息的追踪轨迹
  ///
  /// @param sender    - 消息发送者ID
  /// @param sn        - 消息序列号
  /// @param signature - 消息签名（用于唯一标识消息）
  /// @return MTA列表（每个元素为JSON字符串，包含MTA ID和时间）
  Future<List<String>> getTraces(ID sender, int sn, String? signature);

  ///  保存消息的追踪轨迹（响应信息）
  ///
  /// @param trace     - 响应信息：'{"ID": "{MTA_ID}", "time": 0}'
  /// @param cid       - 会话ID
  /// @param sender    - 原始消息发送者ID
  /// @param sn        - 原始消息序列号
  /// @param signature - 原始消息签名（取后8位）
  /// @return 操作失败返回false
  Future<bool> addTrace(String trace, ID cid,
      {required ID sender, required int sn, required String? signature});

  ///  移除指定消息的所有追踪轨迹
  ///  （删除消息时调用）
  ///
  /// @param sender    - 消息发送者ID
  /// @param sn        - 消息序列号
  /// @param signature - 消息签名
  /// @return 操作失败返回false
  Future<bool> removeTraces(ID sender, int sn, String? signature);

  ///  移除指定会话中的所有追踪轨迹
  ///  （清空会话时调用）
  ///
  /// @param cid       - 会话ID
  /// @return 操作失败返回false
  Future<bool> removeAllTraces(ID cid);
}