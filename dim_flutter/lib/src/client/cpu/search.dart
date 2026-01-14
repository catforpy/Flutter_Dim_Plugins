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

import 'package:dim_client/client.dart'; // DIM-SDK客户端核心
import 'package:dim_client/ok.dart';     // DIM-SDK基础工具
import 'package:dim_client/sdk.dart';    // DIM-SDK核心库

import '../../common/constants.dart';    // 项目常量（通知名）
import '../../common/protocol/search.dart'; // 自定义搜索命令协议
import '../shared.dart';                 // 全局变量

/// 搜索命令处理器：处理在线用户/通用搜索命令
/// 核心功能：
/// 1. 解析搜索响应中的用户列表
/// 2. 预加载用户文档/群成员信息
/// 3. 发送搜索结果更新通知
class SearchCommandProcessor extends BaseCommandProcessor {
  /// 构造方法：初始化处理器
  SearchCommandProcessor(super.facebook, super.messenger);

  /// 核心处理方法：解析搜索命令，分发搜索结果
  @override
  Future<List<Content>> processContent(Content content,ReliableMessage rMsg) async {
    // 断言：确保是搜索命令
    assert(content is SearchCommand, 'search command error: $content');
    SearchCommand command = content as SearchCommand;

    // 解析并校验搜索结果中的用户列表
    List<ID>? users = _checkUsers(command);
    Log.info('search result: ${users?.length} record(s) found');

    // 发送搜索结果更新通知（UI层监听该通知刷新界面）
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kSearchUpdated, this, {
      'cmd': command,
      'users': users,
    });

    // 无需回复搜索命令
    return [];
  }

  /// 私有方法：解析并校验搜索结果中的用户列表
  /// [command] - 搜索命令
  /// 返回：解析后的用户ID列表（null表示解析失败）
  List<ID>? _checkUsers(SearchCommand command) {
    // 从命令中获取用户列表
    List? users = command['users'];
    if(users == null){
      Log.error('users not found in search response');
      return null;
    }

    // 获取全局Facebook实例（身份管理）
    GlobalVariable shared = GlobalVariable();
    ClientFacebook facebook = shared.facebook;

    // 转换为ID列表，并预加载用户文档/群成员
    List<ID> array = ID.convert(users);
    for(ID item in array){
      facebook.getDocuments(item);        // 预加载用户的Meta/Visa文档
      if(item.isGroup){
        facebook.getMembers(item);        // 若是群组，预加载群成员
      }
    }
    return array;
  }
}