/* license: https://mit-license.org
 *
 *  ObjectKey : Object & Key kits
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

import 'dart:convert';
import 'dart:typed_data';

import 'package:stargate/startrek.dart';

/// 纯文本入站数据包（无分片、无序列号）
class PlainArrival extends ArrivalShip {
  /// 构造方法
  /// [_completed] - 完整的数据包
  /// [now] - 接收时间
  PlainArrival(this._completed, [super.now]);

  /// 完整的数据包
  final Uint8List _completed;

  /// 获取负载数据
  Uint8List get payload => _completed;

  /// 序列号（纯文本无序列号 → 返回null）
  @override
  dynamic get sn => null;

  /// 组装数据包（纯文本无需组装 → 返回自身）
  @override
  Arrival? assemble(Arrival income) {
    assert(income == this, 'plain arrival error: $income, $this');
    return this;
  }
}

/// 纯文本出站数据包（无分片、无序列号）
class PlainDeparture extends DepartureShip {
  /// 构造方法
  /// [pack] - 完整的数据包
  /// [prior] - 优先级
  /// [needsRespond] - 是否需要响应
  PlainDeparture(Uint8List pack, int prior, bool needsRespond)
    : _completed = pack,
      _fragments = [pack],
      _important = needsRespond,
      super(priority: prior, maxTries: 1);

  /// 完整的数据包
  final Uint8List _completed;

  /// 数据分片（纯文本无分片 → 仅包含自身）
  final List<Uint8List> _fragments;

  /// 是否重要（是否需要响应）
  final bool _important;

  /// 获取负载数据
  Uint8List get payload => _completed;

  /// 序列号（纯文本无序列号 → 返回null）
  @override
  dynamic get sn => null;

  /// 获取数据分片
  @override
  List<Uint8List> get fragments => _fragments;

  /// 检查响应（纯文本无需响应 → 返回false）
  @override
  bool checkResponse(Arrival response) => false;

  /// 是否重要（是否需要响应）
  @override
  bool get isImportant => _important;
}

/// 纯文本Porter（搬运工：处理纯文本数据收发）
/// 核心职责：
/// 1. 处理心跳（PING/PONG）；
/// 2. 封装纯文本数据的收发逻辑；
/// 3. 过滤无效数据包（NOOP）；
class PlainPorter extends StarPorter {
  /// 构造方法
  PlainPorter({super.remote, super.local});

  /// 创建入站数据包
  // protected
  Arrival createArrival(Uint8List pack) => PlainArrival(pack);

  /// 创建出站数据包
  // protected
  Departure createDeparture(Uint8List pack, int priority, bool needsRespond) =>
      PlainDeparture(pack, priority, needsRespond);

  /// 获取入站数据包列表（纯文本仅一个数据包）
  @override
  List<Arrival> getArrivals(Uint8List data) => [createArrival(data)];

  /// 检查入站数据包（核心：处理心跳、过滤无效数据）
  @override
  Future<Arrival?> checkArrival(Arrival income) async {
    // 断言：必须是PlainArrival类型
    assert(income is PlainArrival, 'arrival ship error: $income');
    Uint8List data = (income as PlainArrival).payload;
    // 检查4字节的心跳包
    if (data.length == 4) {
      if (_equals(data, PING)) {
        // 收到PING → 回复PONG，返回null（不向上层传递）
        /*await */
        respond(PONG);
        return null;
      } else if (_equals(data, PONG) || _equals(data, NOOP)) {
        // 收到PONG/NOOP → 忽略，返回null
        return null;
      }
    }
    // 有效数据 → 返回给上层
    return income;
  }

  //
  //  数据发送（核心接口）
  //

  /// 发送响应数据（低优先级、无需响应）
  Future<bool> respond(Uint8List payload) async =>
      await sendShip(createDeparture(payload, DeparturePriority.SLOWER, false));

  /// 发送数据（指定优先级）
  Future<bool> send(Uint8List payload, int priority) async =>
      await sendShip(createDeparture(payload, priority, true));

  /// 发送数据（默认优先级）
  @override
  Future<bool> sendData(Uint8List payload) async =>
      await send(payload, DeparturePriority.NORMAL);

  /// 发送心跳包（PING）
  @override
  Future<void> heartbeat() async =>
      await sendShip(createDeparture(PING, DeparturePriority.SLOWER, false));

  // 常量：心跳包/空操作包
  static final Uint8List PING = _bytes('PING');
  static final Uint8List PONG = _bytes('PONG');
  static final Uint8List NOOP = _bytes('NOOP');
  // static final Uint8List OK = _bytes('OK');
}

/// 字符串转字节数组（UTF8编码）
Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

/// 比较两个字节数组是否相等
bool _equals(Uint8List a, Uint8List b) {
  if (identical(a, b)) {
    // 同一对象 → 相等
    return true;
  } else if (a.length != b.length) {
    // 长度不同 → 不相等
    return false;
  }
  // 逐字节比较
  for (int i = a.length - 1; i >= 0; --i) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
