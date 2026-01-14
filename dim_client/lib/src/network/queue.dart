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

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:lnc/log.dart';
import 'package:stargate/startrek.dart';
import 'package:dimsdk/dimsdk.dart';

/// 消息队列（按优先级管理待发送的消息）
/// 支持按优先级排序、去重、获取下一条消息、清理空队列
class MessageQueue with Logging {
  /// 优先级列表（升序排列）
  final List<int> _priorities = [];

  /// 按优先级存储的消息列表（key：优先级，value：MessageWrapper列表）
  final Map<int, List<MessageWrapper>> _fleets = {};

  /// 追加消息到队列（带出发数据包）
  /// [rMsg]：待发送的可靠消息
  /// [ship]：出发数据包（Departure）
  /// 返回：false表示消息重复，true表示追加成功
  bool append(ReliableMessage rMsg, Departure ship) {
    bool ok = true;
    // 1.根据优先级选择对应的列表
    int priority = ship.priority;
    List<MessageWrapper>? array = _fleets[priority];
    if (array == null) {
      // 1.1、为该优先级创建新列表
      array = [];
      _fleets[priority] = array;
      // 1.2、将优先级插入到排序后的列表中
      _insert(priority);
    } else {
      // 1.3、检查消息是否重复
      var signature = rMsg['signature'];
      assert(signature != null, 'signature not found: $rMsg');
      ReliableMessage? item;
      for (MessageWrapper wrapper in array) {
        item = wrapper.message;
        if (item != null && _isDuplicated(item, rMsg)) {
          logWarning('[QUEUE] duplicated message: $signature');
          ok = false;
          break;
        }
      }
    }
    if (ok) {
      // 2. 包装消息并追加到列表
      MessageWrapper wrapper = MessageWrapper(rMsg, ship);
      array.add(wrapper);
    }
    return ok;
  }

  /// 检查两条可靠消息是否重复
  /// [msg1]：第一条消息
  /// [msg2]：第二条消息
  /// 返回：true表示重复，false表示不重复
  bool _isDuplicated(ReliableMessage msg1, ReliableMessage msg2) {
    var sig1 = msg1['signature'];
    var sig2 = msg2['signature'];
    if (sig1 == null || sig2 == null) {
      assert(false, 'signature should not empty here: $msg1, $msg2');
      return false;
    } else if (sig1 != sig2) {
      // 签名不同，不是重复消息
      return false;
    }
    // 签名相同，检查接收者（防止群消息拆分后误判重复）
    ID to1 = msg1.receiver;
    ID to2 = msg2.receiver;
    return to1 == to2;
  }

  /// 将优先级插入到排序后的列表中（升序）
  /// [priority]：要插入的优先级
  void _insert(int priority) {
    int total = _priorities.length;
    int index = 0, value;
    // 查找插入位置
    for (; index < total; ++index) {
      value = _priorities[index];
      if (value == protected) {
        // 优先级已存在，无需插入
        return;
      } else if (value > priority) {
        // 找到插入位置（当前值大于新值）
        break;
      }
      // 当前值小于新值，继续查找
    }
    // 在找到的位置前插入新优先级
    _priorities.insert(index, priority);
  }

  /// 获取下一条待发送的消息（按优先级从高到低）
  /// 返回：MessageWrapper实例（null表示队列为空）
  MessageWrapper? next() {
    for (int priority in _priorities) {
      // 获取对应优先级的消息列表
      List<MessageWrapper>? array = _fleets[priority];
      if (array != null && array.isNotEmpty) {
        // 移除并返回列表第一个元素
        return array.removeAt(0);
      }
    }
    return null;
  }

  /// 清理空的优先级队列
  void purge() {
    _priorities.removeWhere((prior) {
      List<MessageWrapper>? array = _fleets[prior];
      if (array == null) {
        // 该优先级无列表，移除
        return true;
      } else if (array.isEmpty) {
        // 该优先级列表为空，移除列表和优先级
        _fleets.remove(prior);
        return true;
      }
      // 列表非空，保留优先级
      return false;
    });
  }
}

/// 消息包装器（实现Departure接口）
/// 用于将ReliableMessage和Departure绑定，方便队列管理
class MessageWrapper implements Departure {
  /// 构造方法
  /// [msg]：可靠消息
  /// [departure]：出发数据包
  MessageWrapper(ReliableMessage msg, Departure departure)
    : message = msg,
      _ship = departure;

  /// 可靠消息
  ReliableMessage? message;

  /// 出发数据包（内部持有）
  final Departure _ship;

  /// 实现Departure接口：获取序列号
  @override
  dynamic get sn => _ship.sn;

  /// 实现Departure接口：获取优先级
  @override
  int get priority => _ship.priority;

  /// 实现Departure接口：获取数据分片
  @override
  List<Uint8List> get fragments => _ship.fragments;

  /// 实现Departure接口：检查响应
  @override
  bool checkResponse(Arrival response) => _ship.checkResponse(response);

  /// 实现Departure接口：是否重要消息
  @override
  bool get isImportant => _ship.isImportant;

  /// 实现Departure接口：更新最后操作时间
  @override
  void touch(DateTime now) => _ship.touch(now);

  /// 实现Departure接口：获取当前状态
  @override
  ShipStatus getStatus(DateTime now) => _ship.getStatus(now);
}
