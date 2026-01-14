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

import 'dart:typed_data'; // 字节数据处理

import 'package:dim_client/ok.dart';     // DIM-SDK基础工具（日志/异步）
import 'package:dim_client/sdk.dart';    // DIM-SDK核心库（消息/内容/用户模型）
import 'package:dim_client/common.dart'; // DIM-SDK通用接口
import 'package:dim_client/client.dart'; // DIM-SDK客户端基类

import '../common/platform.dart';  // 设备平台工具
import '../models/newest.dart';    // 应用版本信息模型
import '../models/shield.dart';    // 屏蔽/静音管理模型
import '../models/vestibule.dart'; // 消息暂存/恢复模型
import '../network/velocity.dart'; // 服务器测速模型
import '../ui/language.dart';     // 语言管理
import 'shared.dart';             // 全局变量

/// 共享消息收发器：继承ClientMessenger，扩展核心消息处理逻辑
/// 核心扩展：
/// 1. 消息内容反序列化增强（握手命令解析）
/// 2. 消息验证增强（黑名单过滤）
/// 3. 发送逻辑增强（广播消息处理/异常捕获）
/// 4. Visa文档自动更新（包含设备/应用信息）
/// 5. 握手成功后自动广播关键信息
/// 6. 服务器测速数据上报
class SharedMessenger extends ClientMessenger {

  /// 构造方法：初始化消息收发器
  /// [session] - 客户端会话
  /// [facebook] - 身份管理核心
  /// [mdb] - 消息数据库
  SharedMessenger(super.session, super.facebook, super.mdb);

  // ===================== 消息反序列化增强 =====================
  /// 反序列化消息内容（重写父类）
  /// 扩展：解析握手命令中的远程IP地址
  @override
  Future<Content?> deserializeContent(Uint8List data,SymmetricKey password,
      SecureMessage sMsg) async {
    // 执行父类反序列化逻辑
    Content? content = await super.deserializeContent(data, password, sMsg);

    // 解析握手命令中的远程地址
    if(content is Command){
      if(content is HandshakeCommand){
        var remote = content['remote_address'];
        logWarning('socket address: $remote in $content, msg: ${sMsg.sender} -> ${sMsg.receiver}');
      }
    }
    return content;
  }

  // ===================== 消息验证增强 =====================
  /// 验证可靠消息（重写父类）
  /// 扩展：黑名单过滤，拦截被屏蔽联系人的消息
  @override
  Future<SecureMessage?> verifyMessage(ReliableMessage rMsg) async {
    Shield shield = Shield();
    // 检查发送者是否被屏蔽（支持群组屏蔽）
    if(await shield.isBlocked(rMsg.sender,group: rMsg.group)){
      logWarning('contact is blocked: ${rMsg.sender}, group: ${rMsg.group}');
      // TODO: 将黑名单同步到当前服务器
      return null; // 返回null表示拦截该消息
    }
    // 执行父类验证逻辑
    return await super.verifyMessage(rMsg);
  }

  // ===================== 消息发送逻辑增强 =====================
  /// 发送消息内容（重写父类）
  /// 扩展：广播消息接收者转换逻辑
  @override
  Future<Pair<InstantMessage,ReliableMessage?>> sendContent(Content content,
    {required ID? sender,required ID receiver,int priority = 0}) async {
    // 处理广播消息接受者
    if(receiver.isBroadcast){
      // 检查是否需要包装消息
      if(receiver.isUser && receiver != Station.ANY){
        String? name = receiver.name;
        ID? aid;
        if(name != null){
          // 通过ANS解析接受者ID
          aid = ClientFacebook.ans?.identifier(name);
        }
        if(aid == null){
          logInfo('broadcast message with receiver: $receiver');
          // TODO: 使用ForwardContent包装消息
        }else {
          logInfo('convert receiver: $receiver => $aid');
          receiver = aid; // 转换接收者ID
        }
      }
    }
    // 执行父类发送逻辑
    return await super.sendContent(content, sender: sender, receiver: receiver,priority: priority);
  }

  /// 发送即时消息（重写父类）
  /// 扩展：异常捕获+保存消息签名
  @override
  Future<ReliableMessage?> sendInstantMessage(InstantMessage iMsg,{int priority = 0}) async {
    ReliableMessage? rMsg;
    try{
      // 执行父类发送逻辑
      rMsg = await super.sendInstantMessage(iMsg,priority: priority);
    }catch(e,st){
      // 捕获发送异常，记录详细日志
      logError('failed to send message to: ${iMsg.receiver}, error: $e');
      logDebug('failed to send message to: ${iMsg.receiver}, error: $e, $st');
      return null;
    }
    // 保存消息签名（用于追踪验证）
    if(rMsg != null){
      iMsg['signature'] = rMsg.getString('signature');
    }
    return rMsg;
  }

  // ===================== Visa文档自动更新 =====================
  /// 更新当前用户的Visa文档（重写父类）
  /// 扩展：自动填充应用/设备信息
  @override
  Future<bool> updateVisa() async {
    // 获取当前登录用户
    User? user = await facebook.currentUser;
    if(user == null){
      assert(false, 'current user not found');
      return false;
    }

    // 1.获取Visa签名私钥
    SignKey? sKey = await facebook.getPrivateKeyForVisaSignature(user.identifier);
    if(sKey == null){
      assert(false, 'private key not found: $user');
      return false;
    }

    // 2.获取当前用户的Visa文档
    Visa? visa = await user.visa;
    if (visa == null) {
      // FIXME: 从服务器查询或创建新Visa
      assert(false, 'user error: $user');
      return false;
    }  else {
      // 克隆Visa文档用于修改（避免修改对象）
      Document? doc = Document.parse(visa.copyMap(false));
      if(doc is Visa){
        visa = doc;
      } else {
        assert(false, 'visa error: $visa');
        return false;
      }
    }

    // 3. 更新Visa文档属性（应用/设备信息）
    assert(visa.publicKey != null, 'visa error: $visa');
    visa.setProperty('app', _getAppInfo(visa));   // 应用信息
    visa.setProperty('sys', _getDeviceInfo(visa)); // 设备信息

    // 4. 签名更新后的visa文档
    Uint8List? sig = visa.sign(sKey);
    assert(sig != null, 'failed to sign visa: $visa, $user');

    // 5. 保存Visa文档
    var archivist = facebook.archivist;
    bool? ok = await archivist?.saveDocument(visa);
    assert(ok == true, 'failed to save document: $visa');
    logWarning('visa updated: $ok, $visa');
    return ok == true;
  }

  /// 构建Visa中的应用信息
  Map _getAppInfo(Visa visa) {
    // 获取所有应用信息
    var info = visa.getProperty('app');
    if(info == null){
      info = {};
    }else if (info is Map) {
      // 已有应用信息，直接更新
    } else {
      assert(info is String, 'invalid app info: $info');
      info = {'app': info};
    }

    // 填充应用信息
    var lang = LanguageDataSource();
    var newest = NewestManager();
    var shared = GlobalVariable();
    var client = shared.terminal;
    info['id'] = client.packageName;        // 应用包名
    info['name'] = client.displayName;      // 应用显示名
    info['version'] = client.versionName;   // 应用版本名
    info['build'] = client.buildNumber;     // 应用构建号
    info['store'] = newest.store;           // 应用商店信息
    info['language'] = lang.getCurrentLanguageCode(); // 当前语言

    return info;
  }

  /// 构建Visa中的设备信息
  Map _getDeviceInfo(Visa visa) {
    // 获取现有设备信息
    var info = visa.getProperty('sys');
    if (info == null) {
      info = {};
    } else if (info is Map) {
      // 已有设备信息，直接更新
    } else {
      assert(info is String, 'invalid device info: $info');
      info = {'sys': info};
    }

    // 填充设备信息
    GlobalVariable shared = GlobalVariable();
    info['locale'] = shared.terminal.language;    // 系统语言
    info['model'] = shared.terminal.systemModel;  // 设备型号
    info['os'] = DevicePlatform.operatingSystem;   // 操作系统

    return info;
  }

  // ===================== 握手成功后自动广播 =====================
  /// 握手成功处理逻辑（重写父类）
  /// 扩展：自动广播文档/登录信息/屏蔽列表，恢复暂存消息
  @override
  Future<void> handshakeSuccess() async {
    // 1. 广播当前用户文档
    try {
      await super.handshakeSuccess();
    } catch (e, st) {
      logError('failed to broadcast document: $e, $st');
    }

    // 获取当前登录用户
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      assert(false, 'should not happen');
      return;
    }

    // 2. 广播登录命令（包含当前服务器信息）
    try {
      await broadcastLogin(user.identifier, shared.terminal.userAgent);
    } catch (e, st) {
      logError('failed to broadcast login command: $e, $st');
    }

    // 3. 广播黑名单/静音列表
    try {
      Shield shield = Shield();
      await shield.broadcastBlockList();  // 广播黑名单
      await shield.broadcastMuteList();   // 广播静音列表
    } catch (e, st) {
      logError('failed to broadcast block/mute list: $e, $st');
    }

    // 4. 测速完成后上报服务器速度（预留逻辑）

    // 5. 恢复暂存的消息
    Vestibule clerk = Vestibule();
    await clerk.resumeMessages(user.identifier);
  }

  // ===================== 文档广播增强 =====================
  /// 广播用户文档（重写父类）
  /// 扩展：支持向所有联系人广播更新后的Visa
  @override
  Future<void> broadcastDocuments({bool updated = false}) async {
    var checker = facebook.entityChecker;
    if (checker == null) {
      assert(false, 'entity checker not found');
      return;
    }

    // 获取当前用户的Visa文档
    User? user = await facebook.currentUser;
    Visa? visa = await user?.visa;
    if (visa == null) {
      assert(false, 'visa not found: $user');
      return;
    }

    // 向所有联系人发送更新后的Visa
    if (updated) {
      ID me = visa.identifier;
      List<ID> contacts = await facebook.getContacts(me);
      for (ID item in contacts) {
        await checker.sendVisa(visa, item, updated: updated);
      }
    }

    // 广播到全网（everyone@everywhere）
    await checker.sendVisa(visa, ID.EVERYONE, updated: updated);
  }

  // ===================== 服务器测速数据上报 =====================
  /// 上报服务器测速数据到监控节点
  /// [meters] - 测速结果列表
  /// [provider] - 服务提供商ID
  Future<void> reportSpeeds(List<VelocityMeter> meters, ID provider) async {
    if (meters.isEmpty) {
      logWarning('meters empty');
      return;
    }

    // 格式化测速数据
    List stations = [];
    for (VelocityMeter item in meters) {
      stations.add({
        'host': item.host,                // 服务器地址
        'port': item.port,                // 服务器端口
        'response_time': item.responseTime, // 响应时间
        'test_date': item.info.testTime?.toString(), // 测试时间
        'socket_address': item.socketAddress, // 实际连接的IP
      });
    }

    // 构建上报内容
    ID master = ID.parse('monitor@anywhere')!; // 监控节点ID
    Content content = CustomizedContent.create(
      app: 'chat.dim.monitor',
      mod: 'speeds',
      act: 'post',
    );
    content['provider'] = provider.toString(); // 服务提供商
    content['stations'] = stations;           // 测速数据

    // 发送上报消息（优先级1）
    await sendContent(content, sender: null, receiver: master, priority: 1);
  }
}