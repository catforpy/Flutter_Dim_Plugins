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

import 'package:dim_client/plugins.dart';

/// 地址名称服务（ANS）抽象接口
/// 提供保留关键字检查、短名称与ID映射查询等功能
abstract interface class AddressNameService {
   /// 保留关键字列表
  /// 这些名称无法被注册为ANS短名称
  static final List<String> keywords = [
    "all", "everyone", "anyone", "owner", "founder",
    // --------------------------------
    "dkd", "mkm", "dimp", "dim", "dimt",
    "rsa", "ecc", "aes", "des", "btc", "eth",
    // --------------------------------
    "crypto", "key", "symmetric", "asymmetric",
    "public", "private", "secret", "password",
    "id", "address", "meta",
    "tai", "document", "profile", "visa", "bulletin",
    "entity", "user", "group", "contact",
    // --------------------------------
    "member", "admin", "administrator", "assistant",
    "main", "polylogue", "chatroom",
    "social", "organization",
    "company", "school", "government", "department",
    "provider", "station", "thing", "bot", "robot",
    // --------------------------------
    "message", "instant", "secure", "reliable",
    "envelope", "sender", "receiver", "time",
    "content", "forward", "command", "history",
    "keys", "data", "signature",
    // --------------------------------
    "type", "serial", "sn",
    "text", "file", "image", "audio", "video", "page",
    "handshake", "receipt", "block", "mute",
    "register", "suicide", "found", "abdicate",
    "invite", "expel", "join", "quit", "reset", "query",
    "hire", "fire", "resign",
    // --------------------------------
    "server", "client", "terminal", "local", "remote",
    "barrack", "cache", "transceiver",
    "ans", "facebook", "store", "messenger",
    "root", "supervisor",
  ];

  /// 检查别名是否为保留关键字
  /// [name] 要检查的别名
  /// 返回：true=保留关键字（不可注册），false=可注册
  bool isReserved(String name);

  /// 通过短名称获取对应的用户ID
  /// [name] 短名称
  /// 返回：对应的用户ID（无映射返回null）
  ID? identifier(String name);

  /// 获取指定ID对应的所有短名称
  /// [identifier] 用户ID
  /// 返回：短名称列表
  List<String> names(ID identifier);
}

/// 地址名称服务（ANS）实现类
class AddressNameServer implements AddressNameService {

  /// 构造方法
  /// 初始化时加载常量ANS记录和保留关键字
  AddressNameServer() {
    // 初始化常量ANS记录（固定映射关系）
    _caches['all']      = ID.EVERYONE;
    _caches['everyone'] = ID.EVERYONE;
    _caches['anyone']   = ID.ANYONE;
    _caches['owner']    = ID.ANYONE;
    _caches['founder']  = ID.FOUNDER;
    // 初始化保留关键字映射（标记为已保留）
    for (String item in AddressNameService.keywords) {
      _reserved[item] = true;
    }
  }

  /// 保留关键字映射表（名称→是否保留）
  final Map<String, bool>        _reserved = {};
  /// ANS缓存表（短名称→ID）
  final Map<String, ID>            _caches = {};
  /// ID反向映射表（ID→短名称列表）
  final Map<ID, List<String>> _namesTables = {};

  @override
  bool isReserved(String name) => _reserved[name] ?? false;

  @override
  ID? identifier(String name) => _caches[name];

  @override
  List<String> names(ID identifier){
    // 先从反向映射表获取短名称列表
    List<String>? array = _namesTables[identifier];
    if(array == null){
      // 反向映射表无数据时，遍历缓存表构建
      array = [];
      // TODO:是否需要更新所有表
      for(String key in _caches.keys){
        if(_caches[key] == identifier){
          array.add(key);
        }
      }
      // 存入反向映射表，避免重复遍历
      _namesTables[identifier] = array;
    }
    return array;
  }

  // 内部缓存更新方法（受保护）
  bool cache(String name,ID? identifier){
    if(isReserved(name)){
      // 保留名称无法注册，返回失败
      return false;
    }
    if(identifier == null){
      // 标识符为空，移除该短名称映射
      _caches.remove(name);
      // TODO: 是否只需要移除一个表？
      _namesTables.clear();
    }else{
      // 存入新的短名称->ID映射
      _caches[name] = identifier;
      // 名称变更，移除该ID对应的反向映射表（触发重新构建）
      _namesTables.remove(identifier);
    }
    return true;
  }
  
  /// 保存ANS记录（异步）
  /// [name] 用户名/短名称
  /// [identifier] 用户ID（为空表示删除该名称）
  /// 返回：true=保存成功，false=保存失败
  Future<bool> save(String name,ID? identifier) async{
    // TODO: 将新纪录保存到数据库
    return cache(name,identifier);
  }

  /// 修复ANS记录（临时移除部分保留关键字）
  /// [records] 待保存的ANS记录（名称→ID字符串）
  /// 返回：成功保存的记录数量
  Future<int> fix(Map<String,String> records) async{
    // 临时移除保留部分关键字（允许注册）
    // _reserved['apns'] = false;
    _reserved['master'] = false;
    _reserved['monitor'] = false;
    _reserved['archivist'] = false;
    _reserved['announcer'] = false;
    _reserved['assistant'] = false;

    int count = 0;
    ID? identifier;
    // 遍历保持保存的记录
    for(String alias in records.keys){
      // 将ID字符串解析为ID对象
      identifier = ID.parse(records[alias]);
      // 断言：记录解析失败（调试模式触发）
      assert(identifier != null,'record error: $alias => ${records[alias]}');
      // 保存记录并统计成功数量
      if(await save(alias,identifier)){
        count += 1;
      }
    }

    // 回复保留关键字标记
    // _reserved['station'] = true;
    _reserved['assistant'] = true;
    _reserved['announcer'] = true;
    _reserved['archivist'] = true;
    _reserved['monitor'] = true;
    _reserved['master'] = true;
    // _reserved['apns'] = true;
    return count;
  }
  
}