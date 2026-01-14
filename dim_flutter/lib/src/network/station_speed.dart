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

import 'dart:typed_data';

import 'package:dim_client/client.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';

import '../client/cpu/handshake.dart';
import '../client/messenger.dart';
import '../client/shared.dart';
import '../models/station.dart';

import 'velocity.dart';

/// 基站测速管理器（单例）：批量测试所有基站的响应速度，管理基站数据源
class StationSpeeder{
  factory StationSpeeder() => _instance;
  static final StationSpeeder _instance = StationSpeeder._internal();
  StationSpeeder._internal();

  /// 测试所有基站的相应速度
  Future<void> testAll() async {
    // 清理过期的测速记录
    GlobalVariable shared = GlobalVariable();
    await shared.database.removeExpiredSpeed(null);
    // 遍历所有服务商的基站进行测速
    int sections = _dataSource.getSectionCount();
    int items;
    ID pid;
    NeighborInfo info;
    for(int sec = 0; sec < sections; ++sec){
      pid = _dataSource.getSection(sec);
      items = _dataSource.getItemCount(sec);
      // 收集该服务商下所有基站的测速任务
      List<Future<VelocityMeter>> futures = [];
      for(int idx = 0; idx < items; ++idx){
        info = _dataSource.getItem(sec, idx);
        futures.add(VelocityMeter.ping(info));
      }
      // 所有基站测速完成后，上报测速结果
      Future.wait(futures).then((meters) {
        shared.messenger?.reportSpeeds(meters, pid);
      });
    }
  }

  ///
  ///   基站数据源（内部类）
  ///

  late final _StationDataSource _dataSource = _StationDataSource();

  /// 重新加载基站数据源
  Future<void> reload() async => await _dataSource.reload();

  /// 获取服务商数量（分区数量）
  int getSectionCount() => _dataSource.getSectionCount();

  /// 获取指定分区的服务商ID
  /// [sec] 分区索引
  ID getSection(int sec) => _dataSource.getSection(sec);

  /// 获取指定服务商下的基站数量
  /// [sec] 分区索引
  int getItemCount(int sec) => _dataSource.getItemCount(sec);

  /// 获取指定服务商下的指定基站信息
  /// [sec] 分区索引
  /// [idx] 基站索引
  NeighborInfo getItem(int sec, int idx) => _dataSource.getItem(sec, idx);

  ///
  ///   握手数据包构建
  ///

  /// 获取握手数据包（用于基站测速的测试消息）
  Future<Uint8List?> get handshakePackage async {
    ReliableMessage? rMsg = await _rMsg;
    if (rMsg == null) {
      return null;
    }
    GlobalVariable shared = GlobalVariable();
    SharedMessenger? messenger = shared.messenger;
    assert(messenger != null, 'messenger not ready');
    // 序列化可靠消息为二进制数据
    return await messenger?.serializeMessage(rMsg);
  }

  /// 构建可靠消息（加密+签名后的握手消息）
  Future<ReliableMessage?> get _rMsg async {
    GlobalVariable shared = GlobalVariable();
    SharedMessenger? messenger = shared.messenger;
    if (messenger == null) {
      // assert(false, 'messenger not ready');
      return null;
    }
    // 构建即时消息
    InstantMessage? iMsg = await _iMsg;
    if (iMsg == null) {
      assert(false, 'failed to build handshake message');
      return null;
    }
    // 加密消息
    SecureMessage? sMsg = await messenger.encryptMessage(iMsg);
    if (sMsg == null) {
      assert(false, 'failed to encrypt message: $iMsg');
      return null;
    }
    // 签名消息
    ReliableMessage? rMsg = await messenger.signMessage(sMsg);
    assert(rMsg != null, 'failed to sign message: $rMsg');
    return rMsg;
  }

  /// 构建即时消息（未加密的握手消息）
  Future<InstantMessage?> get _iMsg async {
    GlobalVariable shared = GlobalVariable();
    ClientFacebook facebook = shared.facebook;
    // 获取当前登录用户
    User? user = await facebook.currentUser;
    if (user == null) {
      assert(false, 'current user not found');
      return null;
    }
    ID uid = user.identifier;
    ID sid = Station.ANY; // 接收方为任意基站
    // 检查当前用户的元数据和签证文档
    Meta? meta = await facebook.getMeta(uid);
    Visa? visa = await facebook.getVisa(uid);
    if (meta == null) {
      assert(false, 'meta should not empty here');
      return null;
    } else if (visa == null) {
      assert(false, 'visa should not empty here');
    }
    // 创建消息信封和测速握手命令
    Envelope env = Envelope.create(sender: uid, receiver: sid);
    Content content = ClientHandshakeProcessor.createTestSpeedCommand();
    content.group = Station.EVERY;    // 广播到所有基站
    // 创建包含元数据和签证的即时消息
    InstantMessage iMsg = InstantMessage.create(env, content);
    iMsg.setMap('meta', meta);
    iMsg.setMap('visa', visa);
    return iMsg;
  }

}

/// 基站数据源：管理服务商和基站的加载与排序
class _StationDataSource {

  /// 服务商ID列表（分区）
  List<ID> _sections = [];
  /// 基站列表：服务商ID -> 基站信息列表
  final Map<ID, List<NeighborInfo>> _items = {};

  /// 重新加载数据源（从数据库获取服务商和基站并排序）
  Future<void> reload() async {
    GlobalVariable shared = GlobalVariable();
    SessionDBI database = shared.database;
    // 获取所有服务商并排序
    var records = await database.allProviders();
    List<ID> providers = _sortProviders(records);
    // 加载每个服务商下的基站并排序
    for (ID pid in providers) {
      var stations = await database.allStations(provider: pid);
      _items[pid] = NeighborInfo.sortStations(await NeighborInfo.fromList(stations));
    }
    _sections = providers;
  }

  /// 获取服务商数量
  int getSectionCount() => _sections.length;

  /// 获取指定分区的服务商ID
  /// [sec] 分区索引
  ID getSection(int sec) {
    return _sections[sec];
  }

  /// 获取指定服务商下的基站数量
  /// [sec] 分区索引
  int getItemCount(int sec) {
    ID pid = _sections[sec];
    return _items[pid]?.length ?? 0;
  }

  /// 获取指定服务商下的指定基站信息
  /// [sec] 分区索引
  /// [idx] 基站索引
  NeighborInfo getItem(int sec, int idx) {
    ID pid = _sections[sec];
    return _items[pid]![idx];
  }
}

/// 排序服务商列表（优先GSP，其次按chosen优先级）
/// [records] 服务商列表
/// 返回排序后的服务商ID列表
List<ID> _sortProviders(List<ProviderInfo> records) {
  // 1. 按优先级排序（broadcast类型优先，其次按chosen降序）
  records.sort((a, b) {
    if (a.identifier.isBroadcast) {
      if (b.identifier.isBroadcast) {} else {
        return -1;
      }
    } else if (b.identifier.isBroadcast) {
      return 1;
    }
    // 按chosen优先级降序
    return b.chosen - a.chosen;
  });
  List<ID> providers = [];
  for (var item in records) {
    providers.add(item.identifier);
  }
  // 2. 将GSP（全球服务提供商）移到最前面
  int pos = providers.indexOf(ProviderInfo.GSP);
  if (pos < 0) {
    // GSP不存在，插入到首位
    providers.insert(0, ProviderInfo.GSP);
  } else if (pos > 0) {
    // GSP已存在，移到首位
    providers.removeAt(pos);
    providers.insert(0, ProviderInfo.GSP);
  }
  return providers;
}