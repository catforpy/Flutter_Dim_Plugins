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

import 'dart:typed_data';

/// 核心抽象：网络数据包容器
/// 封装数据包分片、传输状态管理、唯一标识等核心能力，适配分片传输/重传/响应匹配场景
abstract interface class Ship {
  /// 数据包唯一标识
  /// 用于区分不同数据包，适配分片组装、重传校验、响应匹配等场景
  dynamic get sn;

  /// 更新数据包的发送时间（触达时间）
  /// 用于超时判断、传输状态更新（如判断是否需要重传）
  /// @param now - 当前时间
  void touch(DateTime now);

  /// 检查数据包的当前传输状态
  /// @param now - 当前时间（用于判断超时/过期）
  /// @return 数据包传输状态（ShipStatus）
  ShipStatus getStatus(DateTime now);
}

/// 数据包传输状态枚举
/// 覆盖发送端、接收端全流程的状态管理
enum ShipStatus {
  // ====================== 发送端（Departure）状态 ======================
  init,        // 初始状态：数据包未尝试发送
  waiting,     // 已发送：等待接收端响应（仅重要数据包需要）
  timeout,     // 超时：发送后未按时收到响应，需要重传
  done,        // 完成：所有分片已收到响应（或无需响应的数据包发送完成）
  failed,      // 失败：重试3次仍未收到响应，终止发送

  // ====================== 接收端（Arrival）状态 ======================
  assembling,  // 组装中：等待更多分片（大数据包分片传输时，未收全所有分片）
  expired,     // 过期：未在超时时间内收到所有分片，分片组装失败
}

/// 接收端数据包容器
/// 支持分片组装，适配大数据包分片传输的场景（将多个分片合并为完整数据包）
abstract interface class Arrival implements Ship {
  /// 组装分片数据包
  /// 当收到一个数据包分片时，合并到当前容器，直到组装出完整数据包
  /// @param ship - 携带分片数据的入站数据包
  /// @return 组装后的完整数据包（null表示未组装完成，仍需等待后续分片）
  Arrival? assemble(Arrival ship);
}

/// 发送端数据包容器
/// 支持分片发送、响应校验、优先级管理，适配大数据包分片传输和可靠传输场景
abstract interface class Departure implements Ship {
  /// 获取待发送的数据包分片列表
  /// 用于大数据包分片传输（将大数据包拆分为多个小分片发送，避免单次传输过大）
  /// @return 剩余待发送的分片数据
  List<Uint8List> get fragments;

  /// 校验接收端响应
  /// 匹配入站的响应数据包，确认分片是否发送成功，判断是否完成所有发送任务
  /// @param response - 入站响应数据包
  /// @return true表示所有分片已确认发送成功，发送任务完成
  bool checkResponse(Arrival response);

  /// 判断当前数据包是否需要等待接收端响应
  /// @return false表示“一次性发送”（无需响应，如普通非关键数据），true表示“需要确认”（如重要指令）
  bool get isImportant;

  /// 数据包发送优先级
  /// 用于发送队列的排序（数值越小优先级越高）
  /// @return 默认0，负数为更高优先级，正数为更低优先级
  int get priority;
}

/// 数据包发送优先级常量定义
/// 简化优先级管理，统一业务层优先级配置标准
abstract class DeparturePriority {
  // ignore_for_file: constant_identifier_names
  static const int URGENT = -1;  // 紧急：最高优先级（如心跳包、控制指令）
  static const int NORMAL = 0;   // 正常：默认优先级（普通业务数据）
  static const int SLOWER = 1;   // 低速：低优先级（非关键数据，如日志、统计信息）
}