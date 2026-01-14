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

import 'package:object_key/object_key.dart';
import 'package:startrek/startrek.dart';

/// 发送任务抽象类（DepartureShip）
/// 核心：封装发送任务的优先级、重试次数、超时/失败判定
abstract class DepartureShip implements Departure {
  /// 构造函数：初始化优先级、最大重试次数
  /// @param priority - 优先级（数值越小优先级越高）
  /// @param maxTries - 最大重试次数（默认=1+RETRIES=3次）
  DepartureShip({int? priority, int? maxTries}) {
    assert(maxTries != 0, 'max tries should not be 0');
    _prior = priority ?? 0; // 默认优先级0（最高）
    _expired = null; // 初始无过期时间
    _tries = maxTries ?? 1 + RETRIES; // 总尝试次数=1（首次）+2（重试）=3
  }

  /// 过期时间（无响应时的超时时间）
  DateTime? _expired;

  /// 剩余尝试次数
  late int _tries;

  /// 优先级（数值越小，发送越靠前）
  late final int _prior;

  /// 发送任务超时阈值：2分钟（无响应则判定为超时）
  static Duration EXPIRES = Duration(minutes: 2);

  /// 重要任务重试次数：2次（超时后重试）
  static int RETRIES = 2;
  // ignore_for_file: non_constant_identifier_names

  /// 获取优先级（只读）
  @override
  int get priority => _prior;

  /// 触发重试（调用一次则剩余次数-1，更新过期时间）
  @override
  void touch(DateTime now) {
    assert(_tries > 0, 'touch error, tries=$_tries');
    // 剩余重试次数-1
    --_tries;
    // 更新过期时间为「当前时间+2分钟」
    _expired = now.add(EXPIRES);
  }

  /// 获取发送任务状态（核心判定逻辑）
  @override
  ShipStatus getStatus(DateTime now) {
    DateTime? expired = _expired;
    if (fragments.isEmpty) {
      // 无分片 → 任务完成
      return ShipStatus.done;
    } else if (expired == null) {
      // 未触发过发送 → 初始状态
      return ShipStatus.init;
    } else if (now.isBefore(expired)) {
      // 未超时 → 等待响应
      return ShipStatus.waiting;
    } else if (_tries > 0) {
      // 超时但仍有重试次数 → 超时（需重试）
      return ShipStatus.timeout;
    } else {
      // 超时且无重试次数 → 失败
      return ShipStatus.failed;
    }
  }
}

/// 发送大厅（DepartureHall）
/// 核心：内存缓存发送任务，管理优先级队列、重试逻辑、过期清理
class DepartureHall {
  /// 所有发送任务（弱引用Set，避免内存泄漏）
  final Set<Departure> _allDepartures = WeakSet();

  /// 新任务队列（按优先级排序，等待发送）
  final List<Departure> _newDepartures = [];

  /// 等待响应的任务：优先级 → 任务列表（按优先级分组）
  final Map<int, List<Departure>> _departureFleets = {}; // priority => List
  /// 已排序的优先级列表（便于按优先级遍历）
  final List<int> _priorities = [];

  /// 任务索引：SN → 发送任务（弱引用Map）
  final Map<dynamic, Departure> _departureMap = WeakValueMap(); // SN => ship
  /// 已完成任务记录：SN → 完成时间
  final Map<dynamic, DateTime> _departureFinished = {}; // SN => timestamp
  /// 任务优先级索引：SN → 优先级
  final Map<dynamic, int> _departureLevel = {}; // SN => priority

  /// 添加发送任务到等待队列
  /// @param outgo - 待发送任务
  /// @return false表示任务重复，true表示添加成功
  bool addDeparture(Departure outgo) {
    // 1. 校验重复：已存在则返回false
    if (_allDepartures.contains(outgo)) {
      return false;
    } else {
      _allDepartures.add(outgo);
    }

    // 2. 按优先级插入新任务队列（升序：数值越小越靠前）
    int priority = outgo.priority;
    int index = 0;
    for (; index < _newDepartures.length; ++index) {
      if (_newDepartures[index].priority > priority) {
        // 找到第一个优先级更大的任务，插入到其前面
        break;
      }
    }
    _newDepartures.insert(index, outgo);
    return true;
  }

  /// 检查响应（匹配SN，标记任务完成）
  /// @param response - 携带SN的接收任务（响应包）
  /// @return 已完成的发送任务（null表示未找到/未完成）
  Departure? checkResponse(Arrival response) {
    dynamic sn = response.sn;
    assert(sn != null, 'Ship SN not found: $response');

    // 1. 检查是否已完成
    DateTime? time = _departureFinished[sn];
    if (time != null) {
      return null;
    }

    // 2. 匹配发送任务，校验响应
    Departure? ship = _departureMap[sn];
    if (ship != null && ship.checkResponse(response)) {
      // 响应匹配 → 清理任务缓存
      _removeShip(ship, sn);
      // 标记完成时间
      _departureFinished[sn] = DateTime.now();
      return ship;
    }
    return null;
  }

  /// 移除发送任务（内部辅助方法）
  void _removeShip(Departure ship, dynamic sn) {
    // 1. 从优先级队列移除
    int priority = _departureLevel[sn] ?? 0;
    List<Departure>? fleet = _departureFleets[priority];
    if (fleet != null) {
      fleet.remove(ship);
      // 队列为空则移除该优先级
      if (fleet.isEmpty) {
        _departureFleets.remove(priority);
      }
    }

    // 2. 清理所有索引
    _departureMap.remove(sn);
    _departureLevel.remove(sn);
    _allDepartures.remove(ship);
  }

  /// 获取下一个待发送/超时重试任务
  /// @param now - 当前时间
  /// @return 待处理的发送任务（null表示无任务）
  Departure? getNextDeparture(DateTime now) {
    // 先取新任务 → 无则取超时重试任务
    Departure? next = _getNextNewDeparture(now);
    next ??= _getNextTimeoutDeparture(now);
    return next;
  }

  /// 获取下一个新任务（未发送过的）
  Departure? _getNextNewDeparture(DateTime now) {
    if (_newDepartures.isEmpty) {
      return null;
    }

    // 1. 取出队列首个任务
    Departure outgo = _newDepartures.removeAt(0);
    dynamic sn = outgo.sn;

    if (outgo.isImportant && sn != null) {
      // 2. 重要任务（需响应）→ 加入等待响应队列
      int priority = outgo.priority;
      _insertShip(outgo, priority, sn);
      // 建立索引
      _departureMap[sn] = outgo;
    } else {
      // 3. 非重要任务（无需响应）→ 直接移除，不加入等待队列
      _allDepartures.remove(outgo);
    }

    // 4. 更新过期时间（触发首次发送）
    outgo.touch(now);
    return outgo;
  }

  /// 插入任务到优先级队列（内部辅助方法）
  void _insertShip(Departure outgo, int priority, dynamic sn) {
    // 1. 获取/创建优先级队列
    List<Departure>? fleet = _departureFleets[priority];
    if (fleet == null) {
      fleet = [];
      _departureFleets[priority] = fleet;
      // 插入优先级到排序列表
      _insertPriority(priority);
    }

    // 2. 添加任务，建立优先级索引
    fleet.add(outgo);
    _departureLevel[sn] = priority;
  }

  /// 插入优先级到排序列表（升序，内部辅助方法）
  void _insertPriority(int priority) {
    int index = 0, value;
    for (; index < _priorities.length; ++index) {
      value = _priorities[index];
      if (value == priority) {
        // 优先级已存在，无需插入
        return;
      } else if (value > priority) {
        // 找到插入位置
        break;
      }
    }
    // 插入到第一个更大的优先级前面
    _priorities.insert(index, priority);
  }

  /// 获取下一个超时重试任务
  Departure? _getNextTimeoutDeparture(DateTime now) {
    List<Departure> departures;
    List<Departure>? fleet;
    ShipStatus status;
    dynamic sn;

    // 遍历所有优先级（复制列表避免遍历中修改）
    List<int> priorityList = _priorities.toList();
    for (int prior in priorityList) {
      // 1. 获取该优先级的任务队列
      fleet = _departureFleets[prior];
      if (fleet == null) {
        continue;
      }

      // 2. 遍历任务，查找超时/失败任务
      departures = fleet.toList();
      for (Departure ship in departures) {
        sn = ship.sn;
        assert(sn != null, 'Ship ID should not be empty here');

        status = ship.getStatus(now);
        if (status == ShipStatus.timeout) {
          // 2.1 超时 → 移除原队列，插入到「优先级+1」队列（降级）
          fleet.remove(ship);
          _insertShip(ship, prior + 1, sn);
          // 更新过期时间（触发重试）
          ship.touch(now);
          return ship;
        } else if (status == ShipStatus.failed) {
          // 2.2 失败 → 清理缓存
          fleet.remove(ship);
          _departureMap.remove(sn);
          _departureLevel.remove(sn);
          _allDepartures.remove(ship);
          return ship;
        }
      }
    }
    return null;
  }

  /// 清理所有过期/完成任务
  /// @param now - 当前时间
  /// @return 清理的任务数量
  int purge([DateTime? now]) {
    now ??= DateTime.now();
    int count = 0;
    List<Departure> departures;
    List<Departure>? fleet;
    dynamic sn;

    // 1. 清理已完成任务
    List<int> priorityList = _priorities.toList();
    for (int prior in priorityList) {
      fleet = _departureFleets[prior];
      if (fleet == null) {
        // 优先级队列为空 → 移除优先级
        _priorities.remove(prior);
        continue;
      }

      departures = fleet.toList();
      for (Departure ship in departures) {
        if (ship.getStatus(now) == ShipStatus.done) {
          // 任务完成 → 清理缓存
          fleet.remove(ship);
          sn = ship.sn;
          assert(sn != null, 'Ship SN should not be empty here');
          _departureMap.remove(sn);
          _departureLevel.remove(sn);
          // 标记完成时间
          _departureFinished[sn] = now;
          count++;
        }
      }

      // 队列为空则移除该优先级
      if (fleet.isEmpty) {
        _departureFleets.remove(prior);
        _priorities.remove(prior);
      }
    }

    // 2. 清理1小时前的完成记录
    DateTime ago = DateTime.fromMillisecondsSinceEpoch(
      now.millisecondsSinceEpoch - 3600 * 1000,
    );
    _departureFinished.removeWhere((sn, when) => when.isBefore(ago));

    return count;
  }
}
