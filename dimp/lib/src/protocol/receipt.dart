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

import 'package:dimp/dkd.dart';
import 'package:dimp/mkm.dart';

/// 消息回执命令接口
/// 作用：定义消息“已收到/已读”的回执命令，用于消息状态同步
/// 数据格式：{
///      type : i2s(0x88),  // 命令消息类型
///      sn   : 456,        // 回执命令序列号
///
///      command : "receipt", // 命令名=receipt
///      text    : "...",     // 回执描述（如“已读”/“已收到”）
///      origin  : {          // 被回执的原始消息信封信息
///          sender    : "...", // 原始消息发送者ID
///          receiver  : "...", // 原始消息接收者ID
///          time      : 0,     // 原始消息时间戳
///
///          sn        : 123,   // 原始消息序列号
///          signature : "..."  // 原始消息签名（可选）
///      }
///  }
abstract interface class ReceiptCommand implements Command{
  /// 获取回执描述文本
  String get text;

  /// 获取被回执的原始消息信封
  Envelope? get originalEnvelope;

  /// 获取被回执的原始消息序列号
  int? get originalSerialNumber;

  /// 获取被回执的原始消息签名
  String? get originalSignature;

  //-------- 工厂方法 --------
  /// 创建消息回执命令
  /// @param text - 回执描述文本
  /// @param head - 原始消息信封（可选）
  /// @param body - 原始消息内容（可选）
  /// @return 回执命令实例
  static ReceiptCommand create(String text,Envelope? head,Content? body){
    Map? origin;
    if(head == null){
      // 无原始信封，origin为null
      origin = null;
    }else if(body == null){
      // 只有信封，净化后作为origin
      origin = purify(head);
    }else{
      // 有信封+内容，补充序列号
      origin = purify(head);
      origin['sn'] = body.sn;
    }
    // 创建基础回执命令
    var command = BaseReceiptCommand.from(text, origin);
    // 补充群组信息（群聊场景）
    if(body != null){
      ID? group = body.group;
      if(group != null){
        command.group = group;
      }
    }
    return command;
  }
  /// 精华信封信息（移除冗余字段，保留核心信息）
  /// @param envelope - 原始消息信封
  /// @return 净化后的信封字典
  static Map purify(Envelope envelope){
    Map origin = envelope.copyMap();
    // 移除冗余字段（避免回执消息过大）
    if (origin.containsKey('data')) {
      origin.remove('data');
      origin.remove('key');
      origin.remove('keys');
      origin.remove('meta');
      origin.remove('visa');
    }
    return origin;
  }
}