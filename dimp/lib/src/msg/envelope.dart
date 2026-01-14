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

import 'package:dimp/dimp.dart';

///  消息信封
///  ~~~~~~~~~~~~~~~~~~~~
///  作用：封装消息的路由核心信息（发送者、接收者、时间），是消息的“地址头”
///  说明：所有消息都必须包含信封，用于节点间路由和消息定位
///
///  数据格式：{
///      sender   : "moki@xxx",  // 发送者ID
///      receiver : "hulk@yyy",  // 接收者ID
///      time     : 123          // 发送时间戳
///  }
class MessageEnvelope extends Dictionary implements Envelope {
  // 构造方法：从字典初始化（解析网络/本地的信封）
  MessageEnvelope([super.dict]);

  /// 发送者ID（缓存）
  ID? _sender;
  /// 接收者ID（缓存）
  ID? _receiver;
  /// 发送时间（缓存）
  DateTime? _time;

  // 构造方法：创建新信封
  // @param sender   - 发送者ID（必填）
  // @param receiver - 接收者ID（可选，默认=任何人）
  // @param time     - 发送时间（可选，默认=当前时间）
  MessageEnvelope.from({required ID sender, required ID? receiver, DateTime? time}) {
    receiver ??= ID.ANYONE; // 接收者默认值：任何人
    time ??= DateTime.now(); // 时间默认值：当前时间
    _sender = sender;
    _receiver = receiver;
    _time = time;
    // 序列化存储
    setString('sender', sender);
    setString('receiver', receiver);
    setDateTime('time', time);
  }

  // 获取发送者ID（懒加载+非空校验）
  @override
  ID get sender {
    ID? did = _sender;
    if (did == null) {
      did = ID.parse(this['sender']);
      assert(did != null, '消息发送者ID错误: ${toMap()}');
      _sender = did;
    }
    return did!;
  }

  // 获取接收者ID（懒加载+默认值）
  @override
  ID get receiver {
    ID? did = _receiver;
    if (did == null) {
      did = ID.parse(this['receiver']);
      did ??= ID.ANYONE; // 解析失败时默认=任何人
      _receiver = did;
    }
    return did;
  }

  // 获取发送时间（懒加载）
  @override
  DateTime? get time {
    _time ??= getDateTime('time');
    return _time;
  }

  /*
   *  群组ID
   *  ~~~~~~~~
   *  场景：群消息拆分时，接收者会改为单个群成员ID，
   *        原群组ID会存入'group'字段，用于标识消息归属
   */
  @override
  ID? get group => ID.parse(this['group']);

  @override
  set group(ID? gid) => setString('group', gid);

  /*
   *  消息类型
   *  ~~~~~~~~~~~~
   *  作用：由于消息内容会被加密，中间节点（服务器）无法识别内容类型，
   *        因此将内容类型提取到信封中，方便中间节点处理（如群消息分发）
   */
  @override
  String? get type => getString('type');

  @override
  set type(String? msgType) => this['type'] = msgType;
}