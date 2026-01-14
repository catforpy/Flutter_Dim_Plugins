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

import 'package:dkd/dkd.dart';
import 'package:mkm/mkm.dart';
import 'package:mkm/type.dart';

/// 消息内容接口
/// ~~~~~~~~~~~~~~~
/// 该接口定义消息内容的核心属性和通用方法，用于创建/解析消息内容
///
/// 数据格式(JSON)：
/// {
///     'type'    : i2s(0),         // 消息类型（文本、命令、文件等）
///     'sn'      : 0,              // 序列号（作为消息ID，唯一标识）
///     'time'    : 123,            // 消息创建时间（时间戳）
///     'group'   : '{GroupID}',    // 群组ID（仅群消息需要）
///     //-- 业务扩展字段
///     'text'    : 'text',         // 文本消息内容
///     'command' : 'Command Name'  // 系统命令名称
///     //... 其他自定义字段
/// }
abstract interface class Content implements Mapper{
  
  /// 【只读】消息类型（标识内容类型：文本/命令/文件等）
  String get type;

  /// 【只读】序列号（作为消息唯一ID，uint64类型）
  int get sn;

  /// 【只读】消息创建时间
  DateTime? get time;

  /// 群组ID（仅群消息有效）
  /// - 存在该字段时，表示这是一条群消息
  ID? get group;
  set group(ID? identifier);

  //
  //  便捷方法
  //

  /// 将对象数组转换为 Content 列表
  /// [array] - 待转换的对象数组（每个元素为Map/JSON）
  /// 返回：Content 列表（过滤掉转换失败的元素）
  static List<Content> convert(Iterable array){
    List<Content> contents = [];
    Content? msg;
    for(var item in contents)
    {
      msg = parse(item);
      if(msg == null){
        continue;
      }
      contents.add(msg);
    }
    return contents;
  }

  /// 将 Content 列表转换为 Map 数组
  /// [contents] - Content 列表
  /// 返回：Map 数组（每个元素为Content的JSON映射）
  static List<Map> revert(Iterable<Content> contents){
    List<Map> array = [];
    for(Content msg in contents){
      array.add(msg.toMap());
    }
    return array;
  }

  //
  //  工厂方法（通过工厂类创建/解析实例，解耦实现）
  //

  /// 解析对象为 Content 实例
  /// [content] - 待解析对象（Map/JSON字符串）
  /// 返回：Content 实例（解析失败返回null）
  static Content? parse(Object? content) {
    var ext = MessageExtensions();
    return ext.contentHelper!.parseContent(content);
  }

  /// 获取指定消息类型的内容工厂
  /// [msgType] - 消息类型标识
  /// 返回：ContentFactory 实例（未找到返回null）
  static ContentFactory? getFactory(String msgType) {
    var ext = MessageExtensions();
    return ext.contentHelper!.getContentFactory(msgType);
  }
  
  /// 设置指定消息类型的内容工厂
  /// [msgType] - 消息类型标识
  /// [factory] - 内容工厂实例
  static void setFactory(String msgType, ContentFactory factory) {
    var ext = MessageExtensions();
    ext.contentHelper!.setContentFactory(msgType, factory);
  }
}

/// 内容工厂接口
/// ~~~~~~~~~~~~~~~
/// 定义消息内容的解析规则，不同类型的消息（文本/命令）需实现该接口
abstract interface class ContentFactory{

  /// 将Map对象解析为 Content 实例
  /// [content] - 内容信息（Map/JSON）
  /// 返回：Content 实例（解析失败返回null）
  Content? parseContent(Map content);
}