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
import 'package:dim_client/sdk.dart';

/// 登录命令接口
/// 用于客户端登录服务器，包含客户端和服务器信息
/// 数据结构规范：
/// {
///     type : 0x88,        // 命令类型
///     sn   : 123,         // 序列号
///     command  : "login", // 命令名称
///     time     : 0,       // 登录时间戳
///     //---- 客户端信息 ----
///     ID       : "{UserID}",      // 用户ID
///     device   : "DeviceID",      // 设备ID（可选）
///     agent    : "UserAgent",     // 用户代理（可选，客户端信息）
///     //---- 服务器信息 ----
///     station  : {                // 服务器信息（响应时返回）
///         ID   : "{StationID}",
///         host : "{IP}",
///         port : 9394
///     },
///     provider : {                // 服务提供商（响应时返回）
///         ID   : "{SP_ID}"
///     }
/// }
abstract interface class LoginCommand implements Command{
  // ignore: constant_identifier_names
  static const String LOGIN = 'login';  // 命令名称常量

  //
  //  客户端信息
  //

  /// 获取登录用户ID
  ID get identifier;

  /// 获取/设置设备ID（可选）
  String? get device;
  set device(String? v);

  /// 获取/设置用户代理（可选，客户端标识）
  String? get agent;
  set agent(String? ua);

  //
  //  服务器信息
  //

  /// 获取/设置服务器信息（station）
  Map? get station;
  set station(dynamic info);

  /// 获取/设置服务提供商信息（provider）
  Map? get provider;
  set provider(dynamic info);

  //
  //  工厂方法
  //

  /// 创建登录命令
  /// [identifier] 登录用户ID
  /// 返回：登录命令实例
  static LoginCommand fromID(ID identifier) => BaseLoginCommand.fromID(identifier);
}

/// 登录命令实现类
/// 继承BaseCommand，实现LoginCommand接口
class BaseLoginCommand extends BaseCommand implements LoginCommand{
  /// 从字典初始化登录命令
  /// [dict] 包含登录命令字段的字典
  BaseLoginCommand(super.dict);

  /// 构造方法：从用户ID创建登录命令
  /// [identifier] 登录用户ID
  BaseLoginCommand.fromID(ID identifier) : super.fromName(LoginCommand.LOGIN) {
    setString('did', identifier);  // 设置用户ID字段（did）
  }

  /// 实现identifier获取逻辑：从did字段解析为ID
  @override
  ID get identifier => ID.parse(this['did'])!;

  /// 实现device获取逻辑：从字典中获取设备ID
  @override
  String? get device => getString('device');

  /// 实现device设置逻辑：设置或移除设备ID字段
  @override
  set device(String? v) => v == null ? remove('device') : this['device'] = v;

  /// 实现agent获取逻辑：从字典中获取用户代理
  @override
  String? get agent => getString('agent');

  /// 实现agent设置逻辑：设置或移除用户代理字段
  @override
  set agent(String? ua) => ua == null ? remove('agent') : this['agent'] = ua;

  /// 实现station获取逻辑：从字典中获取服务器信息
  @override
  Map? get station => this['station'];

  /// 实现station设置逻辑：支持多种类型的服务器信息
  /// [info] 可以是Station对象、Map或null
  @override
  set station(dynamic info){
    if(info is Station){
      // Station对象转换为Map
      ID sid = info.identifier;
      if(sid.isBroadcast){
        info = {'host':info.host,'port':info.port};
      }else{
        info = {'host':info.host,'port':info.port,'did':sid.toString()};
      }
      this['station'] = info;
    }else if(info is Map){
      // 直接使用Map(需包含did字段)
      assert(info.containsKey('did'),'station info error: $info');
      this['station'] = info;
    }else{
      // null表示移除字段
      assert(info == null,'station info error: $info');
      remove('station');
    }
  }

  /// 实现provider获取逻辑：从字典中获取服务提供商信息
  @override
  Map? get provider => this['provider'];

  /// 实现provider设置逻辑：支持多种类型的提供商信息
  /// [info] 可以是ServiceProvider、ID、Map或null
  @override
  set provider(dynamic info) {
    if(info is ServiceProvider){
      // ServiceProvider转换为Map
      this['provider'] = {'did': info.identifier.toString()};
    }else if(info is ID){
      // ID转换为Map
      this['provider'] = {'did': info.toString()};
    }else if (info is Map) {
      // 直接使用Map（需包含did字段）
      assert(info.containsKey('did'), 'station info error: $info');
      this['provider'] = info;
    } else {
      // null表示移除字段
      assert(info == null, 'provider info error: $info');
      remove('provider');
    }
  }
}