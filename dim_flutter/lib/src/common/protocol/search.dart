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


import 'package:dim_client/plugins.dart';

///  搜索命令数据结构定义：
///  {
///      type : 0x88,          // 命令类型
///      sn   : 123,           // 序列号
///
///      command  : "search",  // 命令名称（search：通用搜索，users：在线用户）
///      keywords : "{keywords}",    // 搜索关键词字符串
///
///      start    : 0,         // 分页起始位置
///      limit    : 50,        // 分页大小
///
///      station  : "{STATION_ID}",  // 目标服务器ID
///      users    : ["{ID}"]         // 搜索结果：用户ID列表
///  }
///  搜索命令接口，定义搜索相关的属性和方法
abstract interface class SearchCommand implements Command {
  
  // 忽略常量命名检查（保持与SDK命名风格一致）
  // ignore_for_file: constant_identifier_names
  /// 通用搜索命令名称
  static const String SEARCH = 'search';
  /// 在线用户搜索命令名称
  static const String ONLINE_USERS = 'users';

  /// 获取搜索关键词
  String? get keywords;
  /// 设置搜索关键词（字符串形式）
  set keywords(String? words);
  /// 设置搜索关键词（列表形式，会自动拼接为空格分隔的字符串）
  void setKeywords(List<String> keywords);

  /// 获取分页起始位置
  int get start;
  /// 设置分页起始位置
  set start(int value);

  /// 获取分页大小
  int get limit;
  /// 设置分页大小
  set limit(int value);

  /// 获取目标服务器ID
  ID? get station;
  /// 设置目标服务器ID
  set station(ID? sid);

  ///  获取搜索结果中的用户ID列表
  ///
  /// @return 用户ID列表
  List<ID> get users;

  //
  //  工厂方法
  //

  /// 根据关键词创建搜索命令实例
  /// [keywords] - 搜索关键词
  /// @return 搜索命令实例
  static SearchCommand fromKeywords(String keywords){
    assert(keywords.isNotEmpty, 'keywords should not be empty');
    String cmd;
    // 如果关键词为'users',则创建在线用户搜索命令
    if(keywords == SearchCommand.ONLINE_USERS){
      cmd = SearchCommand.ONLINE_USERS;
      keywords = '';
    }else{
      // 否则创建通过搜索命令
      cmd = SearchCommand.SEARCH;
    }
    return BaseSearchCommand.from(cmd,keywords);
  }
}

/// 搜索命令基础实现类，继承BaseCommand并实现SearchCommand接口
class BaseSearchCommand extends BaseCommand implements SearchCommand {
  /// 构造方法：从字典初始化
  /// [dict] - 命令字典数据
  BaseSearchCommand(super.dict);

  /// 构造方法：从命令名称和关键词创建
  /// [name] - 命令名称（search/users）
  /// [keywords] - 搜索关键词
  BaseSearchCommand.from(String name, String keywords) : super.fromName(name) {
    // 关键词非空时才设置
    if (keywords.isNotEmpty) {
      this['keywords'] = keywords;
    }
  }

  /// 实现：获取搜索关键词
  @override
  String? get keywords{
    String? words = getString('keywords');
    // 在线用户搜索命令默认返回“users"作为关键词
    if(words == null && cmd == SearchCommand.ONLINE_USERS){
      words = SearchCommand.ONLINE_USERS;
    }
    return words;
  }

  /// 实现：设置搜索关键词（字符串形式）
  @override
  set keywords(String? words){
    if(words == null || words.isEmpty){
      this.remove('keywords');
    }else{
      this['keywords'] = words;
    }
  }

  /// 实现：设置搜索关键词（列表形式）
  @override
  void setKeywords(List<String> keywords){
    if(keywords.isEmpty){
      remove('keywords');   //空列表时移除字段
    }else{
      // 列表拼接为空格分隔的字符串
      this['keywords'] = keywords.join(' ');
    }
  }

  /// 实现：获取分页起始位置（默认0）
  @override
  int get start => getInt('start') ?? 0;

  /// 实现：设置分页起始位置
  @override
  set start(int value) => this['start'] = value;

  /// 实现：获取分页大小（默认0）
  @override
  int get limit => this['limit'] ?? 0;

  /// 实现：设置分页大小
  @override
  set limit(int value) => this['limit'] = value;

  /// 实现：获取目标服务器ID
  @override
  ID? get station => ID.parse(this['station']);

  /// 实现：设置目标服务器ID
  @override
  set station(ID? sid){
    if (sid == null) {
      remove('station'); // 移除服务器ID字段
    } else {
      this['station'] = sid.toString(); // 设置服务器ID字符串
    }
  }

  /// 实现：获取用户ID列表（搜索结果）
  @override
  List<ID> get users {
    var array = this['users'];
    // 转换为ID列表，空值返回空列表
    return array == null ? [] : ID.convert(array);
  }
}