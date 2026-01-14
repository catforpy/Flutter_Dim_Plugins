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

import 'package:mkm/mkm.dart';
import 'package:mkm/type.dart';

/// 【核心接口】实体ID（用户/群组）
/// 格式："name@address[/terminal]"
/// - name：实体名称（生成指纹的种子）
/// - address：实体地址（唯一标识）
/// - terminal：终端（设备，预留字段）
abstract interface class ID implements Stringer {
  /// 获取实体名称(如用户名/群组名)
  String? get name;

  /// 获取实体地址(核心唯一标识)
  Address get address;

  /// 获取终端(设备，预留)
  String? get terminal;

  /// 获取ID的类型(地址的网络类型，对应EntityType)
  int get type;

  /// ID类型判断（快捷方法）
  bool get isBroadcast;     // 是否为广播ID
  bool get isUser;          // 是否为用户ID
  bool get isGroup;         // 是否为群组ID

  /// 特殊ID常量
  static final ID ANYONE = Identifier.create(name: 'anyone', address: Address.ANYWHERE);// 任意人
  static final ID EVERYONE = Identifier.create(name: 'everyone', address: Address.EVERYWHERE); // 所有人
  static final ID FOUNDER = Identifier.create(name: 'moky', address: Address.ANYWHERE); // DIM创始人

  // -------------------------- 便捷方法 --------------------------
  /// 将Iterable转换为ID列表
  static List<ID> convert(Iterable array) {
    List<ID> members = [];
    ID? did;
    for(var item in array){
      did = parse(item);
      if(did == null) continue;
      members.add(did);
    }
    return members;
  }

  /// 将ID列表转换为字符串列表(序列化)
  static List<String> revert(Iterable<ID> identifiers){
    List<String> array = [];
    for(ID did in identifiers){
      array.add(did.toString());
    }
    return array;
  }

  // -------------------------- 工厂方法 --------------------------
  /// 解析任意对象为ID（支持字符串/Map）
  static ID? parse(Object? identifier){
    var ext = AccountExtensions();
    return ext.idHelper!.parseIdentifier(identifier);
  }

  /// 创建ID(手动指定名称、地址、终端)
  static ID create({String? name,required Address address, String? terminal}){
    var ext = AccountExtensions();
    return ext.idHelper!.createIdentifier(name: name,address: address,terminal: terminal);
  }

  /// 根据Meta生成ID（自动生成地址）
  static ID generate(Meta meta, int? network, {String? terminal}) {
    var ext = AccountExtensions();
    return ext.idHelper!.generateIdentifier(meta, network, terminal: terminal);
  }

  /// 获取ID工厂
  static IDFactory? getFactory() {
    var ext = AccountExtensions();
    return ext.idHelper!.getIdentifierFactory();
  }
  
  /// 注册ID工厂
  static void setFactory(IDFactory factory) {
    var ext = AccountExtensions();
    ext.idHelper!.setIdentifierFactory(factory);
  }
}

/// 【ID工厂接口】
/// 定义ID的生成/创建/解析规范
abstract interface class IDFactory {
  /// 根据Meta生成ID(自动生成地址)
  ID generateIdentifier(Meta meta, int? network, {String? terminal});

  /// 创建ID（手动指定参数）
  ID createIdentifier({String? name, required Address address, String? terminal});

  /// 解析字符串为ID
  ID? parseIdentifier(String identifier);
}

/// 【ID实现类】
/// 不可变字符串实现，封装ID的名称、地址、终端，实现类型判断逻辑
class Identifier extends ConstantString implements ID {
  /// 构造方法：初始化ID字符串和属性
  Identifier(super.string, {
    String? name, required Address address, String? terminal
  }) : _name = name, _address = address, _terminal = terminal;

  /// 私有成员：名称/地址/终端
  final String? _name;
  final Address _address;
  final String? _terminal;

  /// 实现ID接口：获取名称
  @override
  String? get name => _name; 

  /// 实现ID接口：获取地址
  @override
  Address get address => _address;

  /// 实现ID接口：获取终端
  @override
  String? get terminal => _terminal;

  /// 实现ID接口：获取类型（地址的网络类型）
  @override
  int get type => _address.network;

  /// 实现ID接口：判断是否为广播ID
  @override
  bool get isBroadcast => EntityType.isBroadcast(type);

  /// 实现ID接口：判断是否为用户ID
  @override
  bool get isUser => EntityType.isUser(type);

  /// 实现ID接口：判断是否为群组ID
  @override
  bool get isGroup => EntityType.isGroup(type);

    // -------------------------- 工厂方法 --------------------------
  /// 创建ID实例（拼接字符串）
  static ID create({String? name, required Address address, String? terminal}) {
   String string = concat(name: name, address: address, terminal: terminal);
    return Identifier(string, name: name, address: address, terminal: terminal);
  }

  /// 拼接ID字符串（格式：name@address/terminal）
  static String concat({String? name, required Address address, String? terminal}){
    String string = address.toString();
    // 添加名称: name@address
    if(name != null && name.isNotEmpty){
      string = '$name@$string';
    }
    // 添加终端: address/terminal
    if(terminal != null && terminal.isNotEmpty){
      string = '$string/$terminal';
    }
    return string;
  }
}