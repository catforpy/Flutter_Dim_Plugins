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

import 'package:dim_client/common.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/ws.dart';
import 'package:dim_client/sdk.dart';

import '../common/constants.dart';
import '../models/station.dart';
import '../client/shared.dart';

import 'station_speed.dart';

/// 基站测速器：测试单个基站的响应速度，记录网络地址等信息
class VelocityMeter with Logging {

  VelocityMeter(this.info);

  /// 基站信息
  final NeighborInfo info;

  /// 基站的Socket地址（如：255.255.255.255:65535）
  String? socketAddress;  

  /// 基站主机地址
  String get host => info.host;
  /// 基站端口
  int get port => info.port;
  /// 基站ID
  ID? get identifier => info.identifier;
  /// 响应时间（秒）
  double? get responseTime => info.responseTime;

  /// 测速开始时间（秒）
  double _startTime = 0;
  /// 测速结束时间（秒）
  double _endTime = 0;

  /// 重写toString，输出测速器关键信息（便于日志调试）
  @override
  String toString() {
    String clazz = className;
    return '<$clazz host="$host", port=$port id="$identifier" rt=$responseTime />';
  }

  /// 测试指定基站的响应速度（静态方法，入口）
  /// [info] 基站信息
  /// 返回测速器实例
  static Future<VelocityMeter> ping(NeighborInfo info) async {
    var nc = NotificationCenter();
    VelocityMeter meter = VelocityMeter(info);
    // 发送测速开始通知
    nc.postNotification(NotificationNames.kStationSpeedUpdated, meter,{
      'state': 'start',
      'meter': meter,
    });
    // 链接基站
    WebSocketConnector? socket = await meter._connect();
    if(socket == null){
      // 失败通知
      nc.postNotification(NotificationNames.kStationSpeedUpdated, meter,{
        'state': 'failed',
        'meter': meter,
      });
    }else {
      // 连接成功通知
      nc.postNotification(NotificationNames.kStationSpeedUpdated, meter, {
        'state': 'connected',
        'meter': meter,
      });
      // 设置超时时间（30秒）
      double now = TimeUtils.currentTimeSeconds;
      double expired = now + 30;
      while(now < expired){
        if(await meter._run()){
          // 测速完成，退出循环
          break;
        }
        await Future.delayed(const Duration(milliseconds: 128));
        now = TimeUtils.currentTimeSeconds;
      }
      // 测速完成通知
      nc.postNotification(NotificationNames.kStationSpeedUpdated, meter, {
        'state': 'finished',
        'meter': meter,
      });
      // 关闭连接
      await socket.close();
    }
    // 记录测速结果
    String host = meter.host;
    int port = meter.port;
    ID sid = meter.identifier ?? Station.ANY;
    DateTime now = DateTime.now();
    double rt = meter.responseTime ?? -1;
    String? socketAddress = meter.socketAddress;
    Log.info('station test result: $sid ($host:$port) - $rt, $socketAddress');
    // 保存测速记录到数据库
    GlobalVariable shared = GlobalVariable();
    await shared.database.addSpeed(host, port, identifier: sid, time: now, 
      duration: rt, socketAddress: socketAddress);
    return meter;
  }

  /// 连接基站并发送握手数据包
  /// 返回WebSocket连接实例（null表示连接失败）
  Future<WebSocketConnector?> _connect() async {
    StationSpeeder speeder = StationSpeeder();
    // 获取握手数据包
    Uint8List? data = await speeder.handshakePackage;
    if (data == null) {
      // assert(false, 'failed to get message package');
      return null;
    }
    Log.info('connecting to $host:$port ...');
    // 构建WebSocket地址
    Uri url = Uri.parse('ws://$host:$port/');
    WebSocketConnector socket = WebSocketConnector(url);
    try{
      // 连接基站
      bool ok = await socket.connect();
      if(!ok){
        Log.error('failed to connect url: $url');
        return null;
      }
    }on Exception catch(e){
      Log.error('failed to connect $host:$port, $e');
      return null;
    }
    // 注册消息接收回调
    socket.listen((msg) {
      // 收到响应后记录结束时间（仅当消息长度> 64 时有效）
      if(_startTime > 0 && msg.length > 64){
        _endTime = TimeUtils.currentTimeSeconds;
      }
      Log.info('received ${msg.length} bytes from $host:$port');
      // 缓存收到的消息
      _caches.add(msg);
    });
    // 发送握手数据包
    Log.info('connected, sending ${data.length} bytes to $host:$port ...');
    _startTime = TimeUtils.currentTimeSeconds;
    int cnt = await socket.write(data);
    Log.info('$cnt byte(s) sent, waiting response from $host:$port ...');
    return socket;
  }

  /// 消息缓存：存储基站返回的二进制消息
  final List<Uint8List> _caches = [];

  /// 处理缓存中的消息
  /// 返回是否测速完成
  Future<bool> _run() async {
    if(_caches.isEmpty){
      // 无消息，返回false继续等待
      return false;
    }
    // 取出第一条消息处理
    Uint8List? pack = _caches.removeAt(0);
     while (pack != null) {
      if (await _process(pack)) {
        // 处理成功，测速完成
        return true;
      }
      // 处理下一条消息
      pack = _caches.removeAt(0);
    }
    return false;
  }

  /// 检查消息数据是否为合法的JSON格式
  /// [data] 二进制消息数据
  /// 返回是否合法
  static bool _checkMessageData(Uint8List data) {
    // JSON格式消息特征：以{开头，以}结尾，长度>=64
    // {"sender":"","receiver":"","time":0,"data":"","signature":""}
    if (data.length < 64) {
      return false;
    }
    return data.first == _jsonStart && data.last == _jsonEnd;
  }
  /// JSON起始字符（{）的ASCII码
  static final int _jsonStart = '{'.codeUnitAt(0);
  /// JSON结束字符（}）的ASCII码
  static final int _jsonEnd   = '}'.codeUnitAt(0);

  /// 处理基站返回的消息包
  /// [data] 二进制消息数据
  /// 返回是否处理成功
  Future<bool> _process(Uint8List data) async {
    // 检查消息格式是否合法
    if (!_checkMessageData(data)) {
      Log.warning('ignore pack: $data');
      return false;
    }
    GlobalVariable shared = GlobalVariable();
    Messenger? messenger = shared.messenger;
    if(messenger == null){
      assert(false, 'messenger not ready');
      return false;
    }
    // 反序列化可靠消息
    ReliableMessage? rMsg = await messenger.deserializeMessage(data);
    if (rMsg == null) {
      return false;
    }
    // 验证发送者是否为基站
    ID sender = rMsg.sender;
    if (sender.type != EntityType.STATION) {
      Log.error('sender not a station: $sender');
      return false;
    }
    // 计算响应时间
    double? duration = _endTime - _startTime;
    // 更新基站信息
    info.identifier = sender;
    info.responseTime = duration;
    // 提取Socket地址
    try{
      bool ok = await _checkAttachments(rMsg, messenger);
      assert(ok, 'should not happen');
      socketAddress = await _decryptAddress(rMsg, messenger);
    }catch (e, st) {
      Log.error('socket address not found in message from $sender}, error: $e, $st');
    }
    Log.warning('station ($host:$port) $sender responded within $duration seconds via socket: "$socketAddress"');
    return true;
  }

  /// 检查消息附件（元数据/签证）
  /// [rMsg] 可靠消息
  /// [messenger] 消息管理器
  /// 返回是否检查成功
  static Future<bool> _checkAttachments(ReliableMessage rMsg, Messenger messenger) async {
    // [Meta Protocol] 元数据协议
    // [Visa Protocol] 签证协议
    var packer = messenger.packer;
    if (packer is MessagePacker) {
      return await packer.checkAttachments(rMsg);
    } else {
      return false;
    }
  }

  /// 解密获取基站的Socket地址
  /// [sMsg] 安全消息
  /// [messenger] 消息管理器
  /// 返回Socket地址（如：255.255.255.255:65535）
  static Future<String?> _decryptAddress(SecureMessage sMsg, Messenger messenger) async {
    // 解密安全消息为即时消息
    InstantMessage? iMsg = await messenger.decryptMessage(sMsg);
    assert(iMsg != null, 'failed to decrypt message: ${sMsg.sender} => ${sMsg.receiver}');
    Content? content = iMsg?.content;
    // 提取远程地址
    var remote = content?['remote_address'];
    if (remote is List && remote.length == 2) {
      // 格式：[IP, Port] -> "IP:Port"
      return '${remote.first}:${remote.last}';
    }
    return remote?.toString();
  }
}