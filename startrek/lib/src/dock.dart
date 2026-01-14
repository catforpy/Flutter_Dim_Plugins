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

import 'package:startrek/startrek.dart';

/// 核心：整合接收大厅（ArrivalHall）和发送大厅（DepartureHall），提供统一的任务管理入口
class Dock {
  /// 构造函数：创建接收/发送大厅
  Dock() {
    _arrivalHall = createArrivalHall();
    _departureHall = createDepartureHall();
  }

  /// 接收大厅（管理接收任务）
  late final ArrivalHall _arrivalHall;

  /// 发送大厅（管理发送任务）
  late final DepartureHall _departureHall;

  /// 工厂方法：创建接收大厅（子类可重写自定义实现）
  // protected
  ArrivalHall createArrivalHall() => ArrivalHall();

  /// 工厂方法：创建发送大厅（子类可重写自定义实现）
  // protected
  DepartureHall createDepartureHall() => DepartureHall();

  /// 重组接收的数据包分片
  /// @param income - 携带分片/完整包的接收任务
  /// @return 携带完整包的接收任务（null表示仍在重组）
  Arrival? assembleArrival(Arrival income) {
    // 委托给接收大厅处理分片重组
    return _arrivalHall.assembleArrival(income);
  }

  /// 添加发送任务到等待队列
  /// @param outgo - 待发送任务
  /// @return false表示任务重复，true表示添加成功
  bool addDeparture(Departure outgo) {
    // 委托给发送大厅添加任务
    return _departureHall.addDeparture(outgo);
  }

  /// 检查响应（匹配SN，标记发送任务完成）
  /// @param response - 携带SN的接收任务（响应包）
  /// @return 已完成的发送任务（null表示未找到/未完成）
  Departure? checkResponse(Arrival response) {
    // 委托给发送大厅处理响应匹配
    return _departureHall.checkResponse(response);
  }

  /// 获取下一个待发送/超时重试任务
  /// @param now - 当前时间
  /// @return 待处理的发送任务（null表示无任务）
  Departure? getNextDeparture(DateTime now) {
    // 委托给发送大厅获取任务
    return _departureHall.getNextDeparture(now);
  }

  /// 清理所有过期任务（接收+发送）
  /// @param now - 当前时间
  /// @return 清理的总任务数
  int purge([DateTime? now]) {
    int count = 0;
    // 清理接收大厅过期任务
    count += _arrivalHall.purge(now);
    // 清理发送大厅过期任务
    count += _departureHall.purge(now);
    return count;
  }
}

/// 核心：限制清理频率（30秒一次），避免频繁purge消耗性能
class LockedDock extends Dock {
  /// 下次清理时间（限流用）
  DateTime? _nextPurgeTime;

  /// 重写purge：限流清理（30秒一次）
  @override
  int purge([DateTime? now]) {
    now ??= DateTime.now();
    DateTime? nextTime = _nextPurgeTime;

    if (nextTime != null && now.isBefore(nextTime)) {
      // 未到清理时间 → 返回-1表示跳过
      return -1;
    } else {
      // 更新下次清理时间（30秒后）
      _nextPurgeTime = now.add(halfMinute);
    }

    // 调用父类清理逻辑
    return super.purge(now);
  }

  /// 清理间隔：30秒
  static const Duration halfMinute = Duration(seconds: 30);
}
