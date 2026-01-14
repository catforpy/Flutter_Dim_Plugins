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
import 'package:dim_client/common.dart';

import '../common/dbi/network.dart';
import '../client/shared.dart';

/// 基站邻居信息类：存储基站的网络信息、测速数据、选择优先级
class NeighborInfo with Logging {
  NeighborInfo(this.host, this.port, {required this.provider, required this.chosen});

  /// 基站主机地址
  final String host;
  /// 基站端口
  final int port;
  /// 服务提供商ID
  final ID provider;
  /// 选择优先级（数值越高优先级越高）
  int chosen;

  /// 基站唯一标识
  ID? identifier;
  /// 最后测速时间
  DateTime? testTime;    
  /// 平均响应时间（秒）
  double? responseTime;  

  /// 基站名称
  String? name;

  /// 重写toString，输出基站关键信息（便于日志调试）
  @override
  String toString() {
    String clazz = className;
    return '<$clazz host="$host" port=$port pid="$provider" chosen=$chosen>\n'
        '\tID: $identifier, name: $name, speed: $responseTime @ $testTime\n'
        '</$clazz>';
  }

  /// 重新加载基站数据（测速记录、名称）
  Future<void> reloadData() async {
    GlobalVariable shared = GlobalVariable();
    // TODO: 计算平均响应速度
    List<SpeedRecord> records = await shared.database.getSpeeds(host, port);
    if (records.isEmpty) {
      // 无测速记录
      // identifier = null;
      testTime = null;
      responseTime = null;
    } else {
      // 取第一条测速记录（TODO：应计算平均值）
      var speed = records.first;
      identifier = speed.second;
      testTime = speed.third.first;
      responseTime = speed.third.second;
    }
    // 获取基站名称
    ID? sid = identifier;
    if (sid != null) {
      name = await shared.facebook.getName(sid);
    }
  }

  /// 从StationInfo列表创建NeighborInfo列表
  /// [records] StationInfo列表
  /// 返回NeighborInfo列表
  static Future<List<NeighborInfo>> fromList(List<StationInfo> records) async {
    List<NeighborInfo> array = [];
    for (var item in records) {
      array.add(await NeighborInfo.newStation(item));
    }
    return array;
  }

  /// 从StationInfo创建NeighborInfo实例
  /// [record] StationInfo实例
  /// 返回NeighborInfo实例
  static Future<NeighborInfo> newStation(StationInfo record) async =>
      await _StationManager().newStation(
          record.host, record.port,
          provider: record.provider ?? ProviderInfo.GSP, chosen: record.chosen
      );

  /// 获取指定主机/端口/提供商的基站列表
  /// [host] 主机地址
  /// [port] 端口
  /// [provider] 提供商ID（可选）
  /// 返回匹配的基站列表
  static List<NeighborInfo> getStations(String host, int port, {ID? provider}) =>
      _StationManager().getStations(host, port, provider: provider);

  /// 对基站列表排序（优先级：chosen > 响应速度 > 有测速记录）
  /// [stations] 基站列表
  /// 返回排序后的列表
  static List<NeighborInfo> sortStations(List<NeighborInfo> stations) {
    // 按响应时间排序
    stations.sort((a, b) {
      double? art = a.responseTime;
      double? brt = b.responseTime;
      if (art == 0) {
        art = null;
        Log.error('response time error: $a');
      }
      if (brt == 0) {
        brt = null;
        Log.error('response time error: $b');
      }
      assert(art != 0 && brt != 0, 'response time error: $a, $b');
      // 过滤无法连接的基站（响应时间<0）
      if (art != null && art < 0) {
        // a无法连接，检查b
        return brt != null && brt < 0 ? 0 : 1;
      } else if (brt != null && brt < 0) {
        // a可连接，b不可连接，a排前面
        return -1;
      }
      // 都可连接，优先选择chosen高的
      if (a.chosen > b.chosen) {
        // a优先级更高，排前面
        return -1;
      } else if (a.chosen < b.chosen) {
        // b优先级更高，排前面
        return 1;
      }
      // 优先级相同，响应速度快的排前面
      if (art == null || art == 0) {
        // a无测速记录，检查b
        return brt == null || brt == 0 ? 0 : 1;
      } else if (brt == null || brt == 0) {
        // a有记录，b无记录，a排前面
        return -1;
      } else if (art < brt) {
        // a更快，排前面
        return -1;
      } else if (art > brt) {
        // b更快，排前面
        return 1;
      } else {
        // 速度相同
        return 0;
      }
    });
    return stations;
  }
}

/// 基站管理器（单例）：缓存基站信息，避免重复创建
class _StationManager {
  factory _StationManager() => _instance;
  static final _StationManager _instance = _StationManager._internal();
  _StationManager._internal();

  /// 基站缓存：host -> NeighborInfo列表
  final Map<String, List<NeighborInfo>> _stationMap = {};

  /// 创建/获取基站实例（缓存优先）
  /// [host] 主机地址
  /// [port] 端口
  /// [provider] 提供商ID
  /// [chosen] 选择优先级
  /// 返回NeighborInfo实例
  Future<NeighborInfo> newStation(String host, int port,
      {required ID provider, required int chosen}) async {
    List<NeighborInfo>? stations = _stationMap[host];
    if (stations == null) {
      // 新主机，创建空列表
      stations = [];
      _stationMap[host] = stations;
    } else {
      // 检查重复记录（相同host+port+provider）
      for (NeighborInfo srv in stations) {
        if (srv.port == port && srv.provider == provider) {
          assert(srv.host == host, 'station error: $srv');
          // assert(srv.chosen == chosen, 'station error: srv');
          return srv;
        }
      }
    }
    // 创建新实例并加载数据
    NeighborInfo info = NeighborInfo(host, port, provider: provider, chosen: chosen);
    stations.add(info);
    await info.reloadData();
    return info;
  }

  /// 获取指定条件的基站列表
  /// [host] 主机地址
  /// [port] 端口
  /// [provider] 提供商ID（可选）
  /// 返回匹配的基站列表
  List<NeighborInfo> getStations(String host, int port, {ID? provider}) {
    List<NeighborInfo>? stations = _stationMap[host];
    if (stations == null) {
      return [];
    }
    List<NeighborInfo> array = [];
    for (NeighborInfo srv in stations) {
      if (srv.port != port) {
        continue;
      } else if (provider != null && srv.provider != provider) {
        continue;
      }
      assert(srv.host == host, 'station error: $srv');
      array.add(srv);
    }
    return array;
  }

}