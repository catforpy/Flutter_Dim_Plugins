/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2025 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2025 Albert Moky
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

import 'dart:convert';
import 'dart:typed_data';

import 'package:stargate/startrek.dart';
import 'package:stargate/stargate.dart';
import 'package:dimsdk/dimsdk.dart';

/// 客户端网关（支持ACK应答的网关实现）
/// 继承自CommonGate，主要用于创建支持ACK应答的Porter（通信端口）
class AckEnableGate extends CommonGate {
  AckEnableGate();

  /// 重写创建Porter的方法
  /// [remote]：远程地址
  /// [local]：本地地址（可选）
  /// 返回：创建的AckEnablePorter实例
  @override
  Porter createPorter({required SocketAddress remote, SocketAddress? local}) {
    var docker = AckEnablePorter(remote: remote, local: local);
    docker.delegate = delegate;
    return docker;
  }
}

/// 支持ACK应答的PlainPorter实现
/// 继承自PlainPorter，主要扩展了收到数据后的ACK应答逻辑
class AckEnablePorter extends PlainPorter {
  AckEnablePorter({super.remote, super.local});

  /// 重写检查收到的数据的方法
  /// [income]：收到的数据包（Arrival类型）
  /// 返回：处理后的Arrival（调用父类方法）
  @override
  Future<Arrival?> checkArrival(Arrival income) async{
    if(income is PlainArrival){
      Uint8List payload = income.payload;
      // 检验浮在数据
      if(payload.isEmpty){
        // 空数据，无处理（源代码注释了return null）
      }else if(payload[0] == _jsonBegin){
        // 数据以JSON开头（{），提取signature和time字段
        Uint8List? sig = _fetchValue(payload,DataUtils.bytes('signature'));
        Uint8List? sec = _fetchValue(payload, DataUtils.bytes('time'));
        if (sig != null && sec != null) {
          // 构造ACK应答数据
          String? signature = UTF8.decode(sig);
          String? timestamp = UTF8.decode(sec);
          String text = 'ACK:{"time":$timestamp,"signature":"$signature"}';
          // Log.info('sending response: $text');
          Uint8List data = DataUtils.bytes(text);
          // 发送应答
          await respond(data);
        }
      }
    }
    // 调用父类的checkArrival方法
    return await super.checkArrival(income);
  }

  /// 重写发送数据的方法
  /// [payload]：要发送的二进制数据
  /// [priority]：发送优先级
  /// 返回：发送是否成功
  @override
  Future<bool> send(Uint8List payload,int priority) async =>
      await sendShip(createDeparture(payload, priority, false));
}

/// JSON起始字符（{）的ASCII码值
final int _jsonBegin = '{'.codeUnitAt(0);

/// 从二进制数据中提取指定标签对应的值
/// [data]：源二进制数据
/// [tag]：要查找的标签（如signature、time）
/// 返回：提取并处理后的二进制值（null表示未找到）
Uint8List? _fetchValue(Uint8List data, Uint8List tag){
  if(tag.isEmpty){
    return null;
  }
  // 查找标签的其实位置
  int pos = DataUtils.find(data,sub:tag,start:0);
  if(pos < 0){
    return null;
  }else{
    pos += tag.length;
  }
  // 跳过到值的起始位置（找到冒号：）
  pos = DataUtils.find(data,sub:DataUtils.bytes(':'),start:pos);
  if (pos < 0) {
    return null;
  } else {
    pos += 1;
  }
  // 查找到值的结束位置（逗号，或右大括号}）
  int end = DataUtils.find(data, sub: DataUtils.bytes(','), start: pos);
  if (end < 0) {
    end = DataUtils.find(data, sub: DataUtils.bytes('}'), start: pos);
    if (end < 0) {
      return null;
    }
  }
  // 截取值的二进制数据
  Uint8List value = data.sublist(pos, end);
  // 去除空格、双引号、单引号
  value = DataUtils.strip(value, removing: DataUtils.bytes(' '));
  value = DataUtils.strip(value, removing: DataUtils.bytes('"'));
  value = DataUtils.strip(value, removing: DataUtils.bytes("'"));
  return value;
}

/// 数据处理工具类（抽象接口）
abstract interface class DataUtils {

  /// 将字符串转换为二进制数据（UTF8编码）
  static Uint8List bytes(String text) =>
      Uint8List.fromList(utf8.encode(text));

  /// 在二进制数据中查找子数据的起始位置
  /// [data]：源数据
  /// [sub]：要查找的子数据
  /// [start]：起始查找位置
  /// 返回：子数据的起始索引（-1表示未找到）
  static int find(Uint8List data, {required Uint8List sub, int start = 0}){
    int end = data.length - sub.length;
    int i,j;
    bool match;
    for(i = start; i <= end; ++i){
      match = true;
      for(j = 0;j < sub.length; ++j){
        if(data[i + j] == sub[j]){
          continue;
        }
        match = false;
        break;
      }
      if(match){
        return i;
      }
    }
    return -1;
  }

  /// 去除二进制数据首尾的指定数据
  /// [data]：源数据
  /// [removing]：要去除的字符/数据
  /// 返回：处理后的二进制数据
  static Uint8List strip(Uint8List data, {required removing}) =>
      stripLeft(
        stripRight(data, trailing: removing),
        leading: removing,
      );

  /// 去除二进制数据开头的指定数据
  /// [data]：源数据
  /// [leading]：要去除的开头数据
  /// 返回：处理后的二进制数据
  static Uint8List stripLeft(Uint8List data, {required Uint8List leading}) {
    if (leading.isEmpty) {
      return data;
    }
    int i;
    while (true) {
      if (data.length < leading.length) {
        return data;
      }
      for (i = 0; i < leading.length; ++i) {
        if (data[i] != leading[i]) {
          // 不匹配，返回原数据
          return data;
        }
      }
      // 匹配成功，移除开头数据
      data = data.sublist(leading.length);
    }
  }

  /// 去除二进制数据结尾的指定数据
  /// [data]：源数据
  /// [trailing]：要去除的结尾数据
  /// 返回：处理后的二进制数据
  static Uint8List stripRight(Uint8List data, {required Uint8List trailing}) {
    if (trailing.isEmpty) {
      return data;
    }
    int i, m;
    while (true) {
      m = data.length - trailing.length;
      if (m < 0) {
        return data;
      }
      for (i = 0; i < trailing.length; ++i) {
        if (data[m + i] != trailing[i]) {
          // 不匹配，返回原数据
          return data;
        }
      }
      // 匹配成功，移除结尾数据
      data = data.sublist(0, m);
    }
  }
}