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

/*
 *  整体架构说明：
 *
 *              Porter Delegate   Porter Delegate   Porter Delegate
 *                     ^                 ^               ^
 *                     :                 :               :
 *        ~ ~ ~ ~ ~ ~ ~:~ ~ ~ ~ ~ ~ ~ ~ ~:~ ~ ~ ~ ~ ~ ~ ~:~ ~ ~ ~ ~ ~ ~
 *                     :                 :               :
 *          +==========V=================V===============V==========+
 *          ||         :                 :               :         ||
 *          ||         :      Gate       :               :         ||
 *          ||         :                 :               :         ||
 *          ||  +------------+    +------------+   +------------+  ||
 *          ||  |   porter   |    |   porter   |   |   porter   |  ||
 *          +===+------------+====+------------+===+------------+===+
 *          ||  | connection |    | connection |   | connection |  ||
 *          ||  +------------+    +------------+   +------------+  ||
 *          ||          :                :               :         ||
 *          ||          :      HUB       :...............:         ||
 *          ||          :                        :                 ||
 *          ||     +-----------+           +-----------+           ||
 *          ||     |  channel  |           |  channel  |           ||
 *          +======+-----------+===========+-----------+============+
 *                 |  socket   |           |  socket   |
 *                 +-----^-----+           +-----^-----+
 *                       : (TCP)                 : (UDP)
 *                       :               ........:........
 *                       :               :               :
 *        ~ ~ ~ ~ ~ ~ ~ ~:~ ~ ~ ~ ~ ~ ~ ~:~ ~ ~ ~ ~ ~ ~ ~:~ ~ ~ ~ ~ ~ ~
 *                       :               :               :
 *                       V               V               V
 *                  Remote Peer     Remote Peer     Remote Peer
 */

import 'dart:typed_data';

import 'package:startrek/nio.dart';
import 'package:startrek/skywalker.dart';
import 'package:startrek/startrek.dart';

/// 网关（Gate）
/// 核心抽象：多连接的统一入口，负责将数据分发到对应远程地址的Porter
/// 实现Processor（状态机运行器），适配整体状态管理
abstract interface class Gate implements Processor {
  
  /// 发送数据（普通优先级）
  /// 根据远程地址找到对应的Porter，将数据打包为出站飞船并加入发送队列
  /// @param payload - 待发送的原始数据
  /// @param remote  - 目标远程地址（必选）
  /// @param local   - 绑定的本地地址（可选，默认自动选择）
  /// @return false表示发送失败（如无对应Porter、连接异常）
  Future<bool> sendData(Uint8List payload, {required SocketAddress remote, SocketAddress? local});

  /// 发送出站数据包（支持自定义优先级）
  /// 根据远程地址找到对应的Porter，将预制的出站数据包（含分片、优先级等属性）加入发送队列
  /// @param outgo  - 出站数据包（携带数据分片、传输优先级、超时配置等）
  /// @param remote - 目标远程地址（必选）
  /// @param local  - 绑定的本地地址（可选，默认自动选择）
  /// @return false表示发送失败（如无对应Porter、连接异常）
  Future<bool> sendShip(Departure outgo, {required SocketAddress remote, SocketAddress? local});

}