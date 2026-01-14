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

import '../client/shared.dart';
import '../models/config.dart';
import '../models/station.dart';

/// 获取最优的邻居基站（优先选择指定服务商的基站）
/// 返回最优基站信息（null表示无可用基站）
Future<NeighborInfo?> getNeighborStation() async {
  GlobalVariable shared = GlobalVariable();
  SessionDBI database = shared.database;
  try{
    // 从配置更新基站列表到数据库
    await _updateStations(database);
  }catch (e, st) {
    Log.error('failed to update stations: $e, $st');
  }
  NeighborInfo? fast;
  // 遍历所有服务提供商，筛选最有基站
  List<ProviderInfo> providers = await database.allProviders();
  List<StationInfo> stations;
  List<NeighborInfo> candidates;
  for(var item in providers){
    // 获取该服务商下的所有基站
    stations = await database.allStations(provider: item.identifier);
    if (stations.isEmpty) {
      Log.error('no station in provider: $item');
      continue;
    }
    Log.info('got ${stations.length} station(s) in provider: $item');
    // 转换为NeighborInfo并按响应速度排序
    candidates = await NeighborInfo.fromList(stations);
    candidates = NeighborInfo.sortStations(candidates);
    if(fast == null){
      // 首次筛选，取第一个基站
      // 如果该基站有测速记录，直接选中
      fast = candidates.first;
      if(fast.responseTime != null){
        Log.info('chose the fast station: $fast, provider: $item');
        break;
      }else if(candidates.first.responseTime != null){
        // 已有候选基站但无测速记录，当前服务商的第一个基站有测速记录，选中它
        fast = candidates.first;
        Log.info('chose the fast station: $fast, provider: $item');
        break;
      }
    }
  }
  return fast;
}

/// 从配置更新基站列表到数据库
/// [database] 数据库实例
/// 返回是否更新成功
Future<bool> _updateStations(SessionDBI database) async {
  // 1.从配置获取服务商和基站信息
  Config config = Config();
  ID? pid = config.provider;
  List stations = config.services;
  if(pid == null || stations.isEmpty){
    assert(false, 'config error: $config');
    return false;
  }

  // 2.检查并添加服务商到数据库
  List<ProviderInfo> providers = await database.allProviders();
  if(providers.isEmpty){
    // 数据库无服务商，添加默认服务商（优先级1）
    if(await database.addProvider(pid,chosen: 1)){
      Log.warning('first provider added: $pid');
    }else {
      Log.error('failed to add provider: $pid');
      return false;
    }
  }else {
    // 检查服务商是否已存在，不存在则添加（优先级0）
    bool exists = false;
    for(var intm in providers){
      if(intm.identifier == pid){
        exists = true;
        break;
      }
    }
    if(!exists){
      if(await database.addProvider(pid,chosen: 0)){
        Log.warning('provider added: $pid');
      } else {
        Log.error('failed to add provider: $pid');
        return false;
      }
    }
  }

  // 3.检查并添加基站到数据库
  List<StationInfo> currentStations = await database.allStations(provider: pid);
  String? host;
  int? port;
  for(Map item in stations){
    host = item['host'];
    port = item['port'];
    if(host == null){
      continue;
    }else{
      port ??= 9394;  // 默认端口9394
    }
    // 检查基站是否已存在，不存在则添加
    if(_stationExists(host,port,currentStations)){
      Log.debug('station exists: $item');
    }else if (await database.addStation(null, host: host, port: port, provider: pid)) {
      Log.warning('station added: $item, $pid');
    } else {
      Log.error('failed to add station: $item');
      return false;
    }
  }
  return true;
}

/// 检查基站是否已存在于当前列表中
/// [host] 基站主机地址
/// [port] 基站端口
/// [stations] 已存在的基站列表
/// 返回是否存在
bool _stationExists(String host, int port, List<StationInfo> stations) {
  for(var item in stations){
    if(item.host == host && item.port == port){
      return true;
    }
  }
  return false;
}