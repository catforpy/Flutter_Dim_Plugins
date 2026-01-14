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

import 'package:dim_client/common.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';

/// 服务提供商信息类
/// 存储服务提供商（SP）的ID和选中状态
class ProviderInfo {
  /// 构造方法
  /// @param identifier - 服务提供商ID
  /// @param chosen - 选中状态（0=未选中，非0=选中）
  ProviderInfo(this.identifier, this.chosen);

  /// 服务提供商ID
  final ID identifier;
  /// 选中状态（标记当前使用的SP）
  int chosen;

  /// 重写toString，便于日志输出
  @override
  String toString() {
    return '<$runtimeType did="$identifier" chosen=$chosen />';
  }

  /// 默认服务提供商ID(gsp@everywhere)
  static final ID GSP = Identifier.create(name: 'gsp',address: Address.EVERYWHERE);

  //
  //  便捷转换方法
  //

  /// 将字典列表转换为ProviderInfo列表
  /// @param array - 字典列表（包含did/ID/chosen字段）
  /// @return ProviderInfo列表
  static List<ProviderInfo> convert(Iterable<Map> array){
    List<ProviderInfo> providers = [];
    ID? identifier;
    int chosen;
    for(var item in array){
      // 解析服务提供商ID（兼容did/ID字段）
      identifier = ID.parse(item['did']);
      identifier ??= ID.parse(item['ID']);
      //解析选中状态
      chosen = Converter.getInt(item['chosen']) ?? 0;
      if(identifier == null){
        // SP ID解析失败，跳过
        continue;
      }
      providers.add(ProviderInfo(identifier, chosen));
    }
    return providers;
  }

  /// 将ProviderInfo列表转换为字典列表（用于存储）
  /// @param providers - ProviderInfo列表
  /// @return 字典列表
  static List<Map> revert(Iterable<ProviderInfo> providers){
    List<Map> array = [];
    for(var info in providers){
      array.add({
        'ID':info.identifier.toString(),
        'did':info.identifier.toString(),
        'chosen':info.chosen,
      });
    }
    return array;
  }
}

/// 服务器信息类
/// 存储服务器的地址、端口、所属SP和选中状态
class StationInfo {
  /// 构造方法
  /// @param sid - 服务器ID（可为null，默认station@anywhere）
  /// @param chosen - 选中状态
  /// @param host - 服务器IP/域名
  /// @param port - 服务器端口
  /// @param provider - 所属服务提供商ID
  StationInfo(ID? sid, this.chosen,
      {required this.host, required this.port, required this.provider}) {
    identifier = sid ?? Station.ANY;  // 'station@anywhere'
  }

  /// 服务器ID（延迟初始化）
  late ID identifier;
  /// 选中状态（标记当前使用的服务器）
  int chosen;

  /// 服务器IP/域名
  final String host;
  /// 服务器端口
  final int port;

  /// 所属服务提供商ID
  ID? provider;

  /// 重写toString，便于日志输出
  @override
  String toString() {
    return '<$runtimeType host="$host" port=$port did="$identifier"'
        ' provider="$provider" chosen=$chosen />';
  }

  //
  //  便捷转换方法
  //

  /// 将字典列表转换为StationInfo列表
  /// @param array - 字典列表（包含did/ID/chosen/host/port/provider字段）
  /// @return StationInfo列表
  static List<StationInfo> convert(Iterable<Map> array){
    List<StationInfo> stations = [];
    ID? sid;
    int chosen;
    String? host;
    int port;
    ID? provider;
    for(var item in array){
      // 解析服务器ID （兼容did/ID字段）
      sid = ID.parse(item['did']);
      sid ??= ID.parse(item['ID']);
      // 解析选中状态
      chosen = Converter.getInt(item['chosen']) ?? 0;
      //解析服务器地址和端口
      host = Converter.getString(item['host']);
      port = Converter.getInt(item['port']) ?? 0;
      // 解析所属SP
      provider = ID.parse(item['provider']);
      // 地址/端口无效则跳过
      if (host == null || port == 0/* || provider == null*/) {
        continue;
      }
      stations.add(StationInfo(sid, chosen, host: host, port: port, provider: provider));
    }
    return stations;
  }

  /// 将StationInfo列表转换为字典列表（用于存储）
  /// @param stations - StationInfo列表
  /// @return 字典列表
  static List<Map> revert(Iterable<StationInfo> stations) {
    List<Map> array = [];
    for(var info in stations){
      array.add({
        'ID': info.identifier.toString(),
        'did': info.identifier.toString(),
        'chosen': info.chosen,
        'host': info.host,
        'port': info.port,
        'provider': info.provider?.toString(),
      });
    }
    return array;
  }
}

/// 服务提供商数据库接口
/// 负责服务提供商（SP）信息的增删改查
abstract interface class ProviderDBI {

  /// 获取所有服务提供商信息
  /// @return 服务提供商列表（包含ID和选中状态）
  Future<List<ProviderInfo>> allProviders();

  /// 添加服务提供商信息
  /// @param pid - 服务提供商ID
  /// @param chosen - 选中状态（默认0=未选中）
  /// @return 操作结果：false=失败
  Future<bool> addProvider(ID pid, {int chosen = 0});

  /// 更新服务提供商信息
  /// @param pid - 服务提供商ID
  /// @param chosen - 选中状态（默认0=未选中）
  /// @return 操作结果：false=失败
  Future<bool> updateProvider(ID pid, {int chosen = 0});

  /// 移除服务提供商信息
  /// @param pid - 服务提供商ID
  /// @return 操作结果：false=失败
  Future<bool> removeProvider(ID pid);
}

/// 服务器数据库接口
/// 负责服务器信息的增删改查
abstract interface class StationDBI {

  /// 获取指定SP的所有服务器信息
  /// @param provider - 服务提供商ID（默认gsp@everywhere）
  /// @return 服务器列表（包含地址、端口、SP、选中状态）
  Future<List<StationInfo>> allStations({required ID provider});

  /// 添加服务器信息
  /// @param sid - 服务器ID（可为null）
  /// @param chosen - 选中状态（默认0=未选中）
  /// @param host - 服务器IP/域名
  /// @param port - 服务器端口
  /// @param provider - 所属服务提供商ID
  /// @return 操作结果：false=失败
  Future<bool> addStation(ID? sid, {int chosen = 0,
    required String host, required int port, required ID provider});

  /// 更新服务器信息
  /// @param sid - 服务器ID（可为null）
  /// @param chosen - 选中状态（默认0=未选中）
  /// @param host - 服务器IP/域名
  /// @param port - 服务器端口
  /// @param provider - 所属服务提供商ID
  /// @return 操作结果：false=失败
  Future<bool> updateStation(ID? sid, {int chosen = 0,
    required String host, required int port, required ID provider});

  /// 移除指定服务器信息
  /// @param host - 服务器IP/域名
  /// @param port - 服务器端口
  /// @param provider - 所属服务提供商ID
  /// @return 操作结果：false=失败
  Future<bool> removeStation({required String host, required int port, required ID provider});

  /// 移除指定SP的所有服务器信息
  /// @param provider - 服务提供商ID
  /// @return 操作结果：false=失败
  Future<bool> removeStations({required ID provider});

}

/// 登录数据库接口
/// 负责登录命令和消息的存储和查询
abstract interface class LoginDBI {

  /// 获取指定用户的登录命令和消息
  /// @param identifier - 用户ID
  /// @return 登录命令-消息对（null=未找到）
  Future<Pair<LoginCommand?, ReliableMessage?>> getLoginCommandMessage(ID identifier);

  /// 保存指定用户的登录命令和消息
  /// @param identifier - 用户ID
  /// @param content - 登录命令内容
  /// @param rMsg - 可靠消息对象
  /// @return 操作结果：false=失败
  Future<bool> saveLoginCommandMessage(ID identifier, LoginCommand content, ReliableMessage rMsg);

  /// 新增扩展方法：获取带 token 的登录记录（Dart 2 仅定义签名）
  /// 返回 Map 结构：{"cmd": LoginCommand, "msg": ReliableMessage, "token": String?}
  Future<Map<String, dynamic>?> getLoginRecordMap(ID identifier);

  /// 新增扩展方法：保存带 token 的登录记录（Dart 2 仅定义签名）
  Future<bool> saveLoginRecordWithToken(
    ID identifier,
    LoginCommand content,
    ReliableMessage rMsg, {
    String? token,
  });

}

/// 会话数据库总接口
/// 整合登录、服务提供商、服务器数据库接口，提供统一的会话数据访问入口
abstract interface class SessionDBI implements LoginDBI, ProviderDBI, StationDBI {

}