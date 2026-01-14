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
import 'package:dkd/dkd.dart';

/// 消息内容基类
/// 所有消息内容（文本、文件、资产、命令等）的父类，封装消息的核心通用字段：
///   - type：消息类型（文本/图片/转账/命令等）
///   - sn：序列号（唯一标识消息内容，防重放/乱序）
///   - time：消息时间
///   - group：群组ID（群消息时必填）
class BaseContent extends Dictionary implements Content {
  
  /// 构造方法1：从字典初始化（解析网络传输的消息内容）
  BaseContent([super.dict]);

  /// 缓存：消息类型（避免重复解析）
  String? _type;

  /// 缓存：序列号（避免重复解析）
  int? _sn;

  /// 缓存：消息时间（避免重复解析）
  DateTime? _time;

  /// 构造方法2：从消息类型初始化（创建新消息时使用）
  /// 自动生成序列号和当前时间，填充到字典中
  /// @param msgType - 消息类型（如ContentType.TEXT）
  BaseContent.fromType(String msgType) {
    DateTime now = DateTime.now();
    _type = msgType;
    // 生成唯一序列号（基于消息类型+时间，保证唯一性）
    _sn = InstantMessage.generateSerialNumber(msgType,now);
    _time = now;
    // 填充到字典
    this['type'] = _type;
    this['sn'] = _sn;
    setDateTime('time',_time);
  }

  ///  获取消息类型（空字符串表示解析失败，触发断言）
  @override
  String get type{
    if(_type == null){
      var ext = SharedMessageExtensions();
      _type = ext.helper!.getContentType(toMap()) ?? '';
      assert(_type != null, '消息类型解析失败: ${toMap()}');
    }
    return _type ?? '';
  }

  /// 获取序列号（0表示解析失败，出发断言）
  @override
  int get sn{
    _sn ??= getInt('sn',0);
    assert(_sn! > 0, '序列号解析失败: $toMap()');
    return _sn ?? 0;
  }

  /// 获取消息时间（null表示解析失败）
  @override
  DateTime? get time{
    _time ??= getDateTime('time');
    return _time;
  }

    /// 获取群组ID（群消息时返回群组ID，个人消息返回null）
  @override
  ID? get group => ID.parse(this['group']);

  /// 设置群组ID（群消息时必填，个人消息设为null）
  @override
  set group(ID? identifier) => setString('group', identifier);
}

///
/// 命令消息基类（继承消息内容基类）
/// 所有命令类消息（如Meta查询、群管理、资料更新）的父类，扩展cmd字段标识命令类型
///
class BaseCommand extends BaseContent implements Command  {
  /// 构造方法1：从字典初始化（解析网络传输的命令消息）
  BaseCommand([super.dict]);

  /// 构造方法2：从消息类型+命令名称初始化（自定义命令类型）
  /// @param msgType - 消息类型（如ContentType.COMMAND）
  /// @param cmd - 命令名称（如Command.META）
  BaseCommand.fromType(String msgType, String cmd) : super.fromType(msgType) {
    this['command'] = cmd;
  }

  /// 构造方法3：默认命令消息类型 + 命令名称初始化（最常用）
  /// @param cmd - 命令名称
  BaseCommand.fromName(String cmd) : this.fromType(ContentType.COMMAND, cmd);

  /// 获取命令名称（空字符串表示解析失败）
  @override
  String get cmd {
    var ext = SharedCommandExtensions();
    return ext.helper!.getCmd(toMap()) ?? '';
  }
}