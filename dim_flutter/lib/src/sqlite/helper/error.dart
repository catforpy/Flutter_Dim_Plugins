/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
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

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

/// 数据库错误消息修复工具：从损坏的JSON字符串中提取信息，重建消息对象
abstract interface class DBErrorPatch{

  /// 从损坏的JSON字符串重建InstantMessage对象
  /// [json] 损坏的消息JSON字符串
  /// 返回重建的InstantMessage对象
  static InstantMessage rebuildMessage(String json){
    var info = _getPartiallyInfo(json);
    Log.warning('building partially message: $info');
    return InstantMessage.parse(info)!;
  }
}

/// 从损坏的JSON字符串中提取关键字段
/// [json] 损坏的JSON字符串
/// 返回提取的消息信息Map
Map _getPartiallyInfo(String json){
  // 提取消息基础字段
  String? sender = _getJsonStringValue(json, key: 'sender');
  String? receiver = _getJsonStringValue(json, key: 'receiver');
  String? group = _getJsonStringValue(json, key: 'group');
  double? time = _getJsonNumberValue(json, key: 'time');

  // 提取消息内容字段
  double? type = _getJsonNumberValue(json, key: 'type');
  double? sn = _getJsonNumberValue(json, key: 'sn');
  String? text = _getJsonStringValue(json, key: 'text');

  // 构建基础消息结构（缺失字段用默认值填充）
  return {
    'sender': sender ?? ID.ANYONE.toString(),
    'receiver': receiver ?? ID.ANYONE.toString(),
    'group': group,
    'time': time,
    'content': {
      'type': type,
      'sn': sn,
      'time': time,
      'group': group,
      'text': text ?? '_(error message)_',
    }
  };
}

/// 从JSON字符串中提取字符串类型的字段值（容错处理）
/// [json] JSON字符串
/// [key] 要提取的字段名
/// 返回字段值（null表示未找到）
String? _getJsonStringValue(String json, {required String key}) {
  // 构建字段匹配标签（如"sender":"）
  String tag = '"$key":"';
  int start = json.indexOf(tag);
  if(start < 0){
    // 字段不存在，记录警告日志
    Log.warning('json key not found: $key');
    return null;
  }
  String value;
  // 计算字段值起始位置
  start += tag.length;
  // 查找字段值结束位置（双引号）
  int end = json.indexOf('"',start);
  if(end > start){
    // 找到结束引号，截取值
    value = json.substring(start, end);
  }else{
    // 未找到结束引号，截取到字符串末尾
    value = json.substring(start);
  }
  return value;
}

/// 从JSON字符串中提取数字类型的字段值（容错处理）
/// [json] JSON字符串
/// [key] 要提取的字段名
/// 返回字段值（null表示未找到或类型错误）
double? _getJsonNumberValue(String json, {required String key}){
  // 构建字段匹配标签（如"time":）
  String tag = '"$key":';
  int start = json.indexOf(tag);
  if(start < 0){
    // 字段不存在，记录警告日志
    Log.warning('json key not found: $key');
    return null;
  }
  String value;
  // 计算字段值起始位置
  start += tag.length;
  // 查找字段值结束位置（逗号）
  int end = json.indexOf(',',start);
  if(end > start){
    // 找到结束逗号，截取值
    value = json.substring(start, end);
  }else{
    // 未找到结束逗号，截取到字符串末尾
    value = json.substring(start);
  }
  if(value.startsWith('"')){
    // 值以双引号开头，不是数字，记录警告日志
    Log.warning('json key value error: $key, $value');
    return null;
  }
  // 转换为浮点型
  return Converter.getDouble(value);
}