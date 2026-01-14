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

import 'package:startrek/nio.dart';
import 'package:startrek/skywalker.dart';
import 'package:startrek/startrek.dart';

/// 核心抽象：单连接的数据处理器，负责单个连接的收发、心跳、状态管理、任务清理等
/// 实现Processor（状态机运行器），适配连接状态流转
abstract interface class Porter implements Processor{
  
  /// 判断连接是否已关闭
  /// 对应底层连接（如Socket）的关闭状态
  bool get isClosed;

  /// 判断连接是否存活
  /// 结合心跳、最近活动时间判断（即使连接未关闭，长时间无活动也视为不存活）
  bool get isAlive;

  /// 获取当前连接状态
  /// 适配状态机的ConnectionState，转换为简化的PorterStatus
  PorterStatus get status;

  /// 获取远程地址（连接的对端地址）
  SocketAddress? get remoteAddress;

  /// 获取本地地址（绑定的本地地址）
  SocketAddress? get localAddress;

  /// 发送数据（普通优先级）
  /// 将原始数据打包为出站飞船，加入发送队列
  /// @param payload - 待发送的原始数据
  /// @return false表示发送失败（如连接关闭、队列满）
  Future<bool> sendData(Uint8List payload);

  /// 发送出站飞船（支持自定义优先级）
  /// 将预制的出站飞船加入发送队列，避免重复添加
  /// @param ship - 出站飞船（携带数据分片、优先级等）
  /// @return false表示重复添加（同一飞船已在队列）
  Future<bool> sendShip(Departure ship);

  /// 处理接收到的数据
  /// 底层连接收到数据后，回调此方法进行业务处理
  /// @param data - 接收到的原始数据
  Future<void> processReceived(Uint8List data);

  /// 发送心跳包（PING）
  /// 用于保活连接，更新连接存活状态
  Future<void> heartbeat();

  /// 清理过期任务
  /// 移除超时失败的发送任务、过期未组装完成的接收任务
  /// @param now - 当前时间（可选，默认取系统时间）
  /// @return 清理的任务数量
  int purge([DateTime? now]);

  /// 关闭当前连接
  /// 释放资源，清理队列，更新状态为关闭
  Future<void> close();

}

/// 搬运工状态枚举
/// 简化的连接状态，适配上层业务使用（基于底层ConnectionState转换）
enum PorterStatus {
  init,        // 初始状态：连接未建立
  preparing,   // 准备中：连接建立中（如TCP握手、UDP初始化）
  ready,       // 就绪：连接可用（包括保活中、过期但未关闭）
  error;       // 错误：连接异常（如断开、超时、IO错误）

  // ====================== 状态转换：从ConnectionState转换为PorterStatus ======================
  static PorterStatus getStatus(ConnectionState? state) {
    if (state == null) {
      return error;
    } else if (state.index == ConnectionStateOrder.ready.index        // 就绪
        || state.index == ConnectionStateOrder.expired.index         // 过期（但未关闭）
        || state.index == ConnectionStateOrder.maintaining.index) {  // 保活中
      return ready;
    } else if (state.index == ConnectionStateOrder.preparing.index) { // 准备中
      return preparing;
    } else if (state.index == ConnectionStateOrder.error.index) {    // 错误
      return error;
    } else {                                                         // 其他状态（初始）
      return init;
    }
  }

}

/// 搬运工代理（回调接口）
/// 上层业务通过此接口监听Porter的事件（收/发/失败/状态变化）
abstract interface class PorterDelegate {

  /// 收到新数据包的回调
  /// @param arrival - 入站飞船（携带完整数据）
  /// @param porter  - 对应的搬运工（连接）
  Future<void> onPorterReceived(Arrival arrival, Porter porter);

  /// 数据包发送成功的回调
  /// @param departure - 出站飞船（已发送完成）
  /// @param porter    - 对应的搬运工（连接）
  Future<void> onPorterSent(Departure departure, Porter porter);

  /// 数据包发送失败的回调
  /// @param error     - 错误信息
  /// @param departure - 发送失败的出站飞船
  /// @param porter    - 对应的搬运工（连接）
  Future<void> onPorterFailed(IOError error, Departure departure, Porter porter);

  /// 连接异常的回调
  /// @param error     - 错误信息
  /// @param departure - 触发异常的出站飞船（可选）
  /// @param porter    - 对应的搬运工（连接）
  Future<void> onPorterError(IOError error, Departure departure, Porter porter);

  /// 连接状态变化的回调
  /// @param previous  - 旧状态
  /// @param current   - 新状态
  /// @param porter    - 对应的搬运工（连接）
  Future<void> onPorterStatusChanged(PorterStatus previous, PorterStatus current, Porter porter);

}