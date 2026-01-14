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
 *  消息转换流程说明
 *  ~~~~~~~~~~~~~~~~~~~~
 *
 *     即时消息（明文） <-> 安全消息（加密） <-> 可靠消息（加密+签名）
 *     +-------------+     +------------+     +--------------+
 *     |  发送者     |     |  发送者    |     |  发送者      |
 *     |  接收者     |     |  接收者    |     |  接收者      |
 *     |  时间       |     |  时间      |     |  时间        |
 *     |             |     |            |     |              |
 *     |  明文内容   |     |  加密内容  |     |  加密内容    |
 *     +-------------+     |  加密密钥  |     |  加密密钥    |
 *                         +------------+     |  数字签名    |
 *                                            +--------------+
 *     核心算法：
 *         加密内容 = 对称密钥.encrypt(明文内容)
 *         加密密钥 = 接收者公钥.encrypt(对称密钥)
 *         数字签名 = 发送者私钥.sign(加密内容)
 */

import 'package:dimp/dimp.dart';

///  带信封的消息基类
///  ~~~~~~~~~~~~~~~~~~~~~
///  作用：所有消息类型的父类，封装信封（发送者、接收者、时间）的通用逻辑
///  说明：信封是消息的“路由信息”，正文是消息的“内容信息”
///
///  数据格式：{
///      //-- 信封字段（路由信息）
///      sender   : "moki@xxx",  // 发送者ID
///      receiver : "hulk@yyy",  // 接收者ID
///      time     : 123,         // 发送时间（时间戳）
///      //-- 正文字段（内容信息）
///      ...
///  }
abstract class BaseMessage extends Dictionary implements Message {
  // 构造方法：从字典初始化（解析网络/本地的消息）
  BaseMessage([super.dict]);

  /// 消息信封（缓存、避免重复解析）
  Envelope? _envelope;

  /// 构造方法：从信封创建消息
  BaseMessage.fromEnvelope(Envelope env) : super(env.toMap()){
    _envelope = env;
  }

  /// 获取消息信封（懒加载+非空校验）
  @override
  Envelope get envelope{
    _envelope ??= Envelope.parse(toMap());
    return _envelope!;
  }

  //-------- 信封字段的快捷访问方法 --------

  /// 获取发送者ID（从信封读取）
  @override
  ID get sender => envelope.sender;

  /// 获取接受者ID（从信封读取）
  @override
  ID get receiver => envelope.receiver;

  /// 获取发送时间（从信封读取）
  @override
  DateTime? get time => envelope.time;

  /// 获取群组ID（从信封读取，群消息专用）
  @override
  ID? get group => envelope.group;

  /// 获取消息类型（从信封读取，用于中间节点识别）
  @override
  String? get type => envelope.type;

  //-------- 工具方法 --------

  /// 判断消息是否为广播消息
  /// @param msg    -  待判断的消息
  /// @return true=广播消息 （发送给所有人/所有群成员）
  static bool isBroadcast(Message msg){
    // 1.接受者是广播ID（如“everyone@everywhere"）
    if(msg.receiver.isBroadcast){
      return true;
    }
    // 2.检查显示的群组字段（群广播）
    Object? overtGroup = msg['group'];
    if(overtGroup == null){
      return false;
    }
    ID? group = ID.parse(overtGroup);
    return group != null && group.isBroadcast;
  }
}