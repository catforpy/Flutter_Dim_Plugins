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

/// 接收任务抽象类（ArrivalShip）
/// 核心：封装接收任务的过期逻辑，所有接收端任务需继承此类
abstract class ArrivalShip implements Arrival {
  /// 构造函数：初始化过期时间（默认当前时间+5分钟）
  ArrivalShip([DateTime? now]) {
    now ??= DateTime.now();
    _expired = now.add(EXPIRES);
  }

  /// 任务过期时间（超过该时间未完成重组则判定为过期）
  late DateTime _expired;

  /// 接收任务过期阈值：5分钟（未完成重组则丢弃）
  // ignore: non_constant_identifier_names
  static Duration EXPIRES = Duration(minutes: 5);

  /// 更新过期时间（收到分片时调用，重置过期倒计时）
  @override
  void touch(DateTime now) {
    // 更新过期时间为「当前时间+5分钟」
    _expired = now.add(EXPIRES);
  }

  /// 获取任务状态（核心判定逻辑）
  @override
  ShipStatus getStatus(DateTime now) {
    if (now.isAfter(_expired)) {
      // 当前时间超过过期时间 → 任务过期
      return ShipStatus.expired;
    } else {
      // 未过期 → 正在重组中
      return ShipStatus.assembling;
    }
  }
}

/// 接收大厅（ArrivalHall）
/// 核心：内存缓存接收任务，负责分片重组、过期清理
class ArrivalHall {

  /// 所有待重组的接收任务（存储完整对象，用于遍历清理）
  final Set<Arrival> _arrivals = {};
  /// 任务索引：SN → 接收任务（弱引用Map，避免内存泄漏）
  final Map<dynamic, Arrival> _arrivalMap = WeakValueMap();  // SN => Ship
  /// 已完成任务记录：SN → 完成时间（避免重复处理）
  final Map<dynamic, DateTime> _arrivalFinished = {};        // SN => timestamp

  /// 重组接收的数据包分片
  /// @param income - 携带分片/完整包的接收任务
  /// @return 携带完整包的接收任务（null表示仍在重组中）
  Arrival? assembleArrival(Arrival income) {
    // 1. 校验任务ID（SN）：无SN表示是完整包，直接返回
    dynamic sn = income.sn;
    if (sn == null) {
      // 无SN的数据包视为完整包（无需重组）
      return income;
    }

    // 2. 检查缓存的任务
    Arrival? completed;
    Arrival? cached = _arrivalMap[sn];
    if (cached == null) {
      // 2.1 无缓存任务 → 检查是否已完成
      DateTime? time = _arrivalFinished[sn];
      if (time != null) {
        // 该SN任务已完成，避免重复处理
        return null;
      }

      // 2.2 新任务 → 尝试重组（判断是否是分片）
      completed = income.assemble(income);
      if (completed == null) {
        // 是分片 → 加入缓存，等待后续分片
        _arrivals.add(income);
        _arrivalMap[sn] = income;
      }
      // 非分片（完整包）→ 返回completed
    } else {
      // 2.3 有缓存任务 → 合并新分片，尝试重组
      completed = cached.assemble(income);
      if (completed == null) {
        // 重组未完成 → 更新过期时间，继续等待
        cached.touch(DateTime.now());
      } else {
        // 重组完成 → 清理缓存，标记完成时间
        _arrivals.remove(cached);
        _arrivalMap.remove(sn);
        _arrivalFinished[sn] = DateTime.now();
      }
    }

    // 返回完整包任务（null表示仍在重组）
    return completed;
  }

  /// 清理所有过期任务
  /// @param now - 当前时间（默认取系统时间）
  /// @return 清理的任务数量
  int purge([DateTime? now]) {
    now ??= DateTime.now();
    int count = 0;
    dynamic sn;

    // 1. 清理过期任务
    _arrivals.removeWhere((ship) {
      if (ship.getStatus(now!) == ShipStatus.expired) {
        // 任务过期 → 移除索引
        sn = ship.sn;
        if (sn != null) {
          _arrivalMap.remove(sn);
          // TODO: 可添加过期回调
        }
        count++;
        return true;
      } else {
        return false;
      }
    });

    // 2. 清理1小时前的完成记录（避免内存溢出）
    DateTime ago = DateTime.fromMillisecondsSinceEpoch(
        now.millisecondsSinceEpoch - 3600 * 1000
    );
    _arrivalFinished.removeWhere((sn, when) => when.isBefore(ago));

    return count;
  }

}