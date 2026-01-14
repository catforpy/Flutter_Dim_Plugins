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

/// 私密消息转发内容类
/// 作用：封装单条/多条加密消息的转发，支持私密消息的安全转发
class SecretContent extends BaseContent implements ForwardContent{
  /// 构造方法1：从字典初始化（解析网络传输的转发消息）
  SecretContent([super.dict]);

  /// 缓存：单条转发的加密消息（避免重复解析）
  ReliableMessage? _forward;
  /// 缓存：多条转发的加密消息列表（避免重复解析）
  List<ReliableMessage>? _secrets;
  /// 构造方法2：从单条加密消息初始化（转发单条私密消息）
  /// @param msg - 带转发的加密消息（ReliableMessage）
  SecretContent.fromMessage(ReliableMessage msg)
   : super.fromType(ContentType.FORWARD){
    _forward = msg;
    _secrets = null;
    this['forward'] = msg.toMap();
   }
  /// 构造方法3：从多条加密消息初始化（转发多条私密消息）
  /// @param messages - 带转发的加密消息列表
  SecretContent.fromMessages(List<ReliableMessage> messages)
   : super.fromType(ContentType.FORWARD){
    _forward = null;
    _secrets = messages;
    this['secrets'] = ReliableMessage.revert(messages);
   }
  /// 获取单条转发的加密消息（null表示转发多条）
  @override
  ReliableMessage? get forward{
    _forward ??= ReliableMessage.parse(this['forward']);
    return _forward;
  }
  /// 获取所有转发的加密消息列表（核心方法）
  /// 逻辑：优先解析secrets字段，无则降级到forward字段，保证兼容性
  @override
  List<ReliableMessage> get secrets{ 
    List<ReliableMessage>? messages = _secrets;
    if(messages == null){
      var info = this['secrets'];
      if(info is List){
        // 从secrets字段解析出多条信息
        messages = ReliableMessage.convert(info);
      }else{
        // 降级解析forward字段的单条信息
        ReliableMessage? msg = forward;
        messages = msg == null ? [] : [msg];
      }
      _secrets = messages;
    }
    return messages;
  }
}

/// 合并转发内容类（聊天记录转发）
/// 作用：封装带标题的历史消息合并转发，适配聊天记录分享场景
class CombineForwardContent extends BaseContent implements CombineContent{
  /// 构造方法1：从字典初始化（解析网络传输的合并转发消息）
  CombineForwardContent([super.dict]);

  /// 缓存：合并的历史消息列表（避免重复解析）
  List<InstantMessage>? _history;
  /// 构造方法2：从标题+消息列表初始化（创建合并转发消息）
  /// @param title - 转发标题（如“群聊记录-产品讨论组”）
  /// @param messages - 待合并的历史消息列表
  CombineForwardContent.from(String title, List<InstantMessage> messages)
  : super.fromType(ContentType.COMBINE_FORWARD){
    // 填充聊天标题
    this['title'] = title;
    // 填充聊天记录
    this['messages'] = InstantMessage.revert(messages);
    _history = messages;
  }
  /// 获取合并转发的标题（空字符串表示未设置）
  @override
  String get title => getString('title') ?? '';
  /// 获取合并的历史消息列表（核心方法）
  @override
  List<InstantMessage> get messages{
    List<InstantMessage>? array = _history;
    if(array == null){
      var info = this['messages'];
      if(info is List){
        // 从messages字段解析出多条信息
        array = InstantMessage.convert(info);
      }else{
        assert(info == null, '合并消息列表解析异常: $info');
        array = [];
      }
      _history = array;
    }
    return array;
  }
}

/// 消息数组内容类
/// 作用：封装多类型消息的数组，支持批量发送不同类型的消息（如批量指令、混合内容）
class ListContent extends BaseContent implements ArrayContent{
  /// 构造方法1：从字典初始化（解析网络传输的消息数组）
  ListContent([super.dict]);

  /// 缓存：消息数组（避免重复解析）
  List<Content>? _list;

  /// 构造方法2：从消息列表初始化（创建消息数组）
  /// @param contents - 不同类型的消息内容列表
  ListContent.fromContents(List<Content> contents)
      : super.fromType(ContentType.ARRAY) {
    // 填充消息内容数组
    this['contents'] = Content.revert(contents);
    _list = contents;
  }

  /// 获取消息内容列表（核心方法）
  @override
  List<Content> get contents{
    var array = _list;
    if(array == null){
      var info = this['contents'];
      if(info is List){
        array = Content.convert(info);
      }else{
        array = [];
      }
      _list = array;
    }
    return array;
  }
}