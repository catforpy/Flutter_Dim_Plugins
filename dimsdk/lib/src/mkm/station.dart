/* license: https://mit-license.org
 *
 *  ObjectKey : Object & Key kits
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

import 'package:dimsdk/dimp.dart';
import 'package:dimsdk/mkm.dart';

/// DIM 服务器实体类
/// 将服务器抽象为特殊用户（实现 User 接口），复用用户的加密/解密/签名/验签能力，
/// 支持服务器配置管理、动态重载和相等性判断，适配 DIM 协议中「服务器 = 特殊用户」的设计理念。
/// 核心特性：
/// 1. 复用 BaseUser 实现 User 接口，无需重复开发加解密/签名逻辑；
/// 2. 支持动态重载配置（从服务器文档更新主机/端口/服务商信息）；
/// 3. 自定义相等性判断和哈希值，适配服务器地址匹配场景。
class Station implements User {
  /// 构造方法：初始化服务器实体
  /// 核心逻辑：校验服务器ID类型，初始化内部用户代理和网络参数，
  /// 服务器ID必须为 STATION/ANY 类型，确保协议层正确识别实体类型。
  /// @param identifier - 服务器ID（必须为 STATION/ANY 类型，非该类型触发断言）
  /// @param host - 服务器主机地址（IPv4/IPv6/域名，可为null）
  /// @param port - 服务器端口（需符合 17~65535 范围，重载时校验）
  Station(ID identifier, String? host, int port) {
    // 强制校验服务器ID类型：仅允许 STATION/ANY 类型，避免实体类型混淆
    assert(
      identifier.type == EntityType.STATION ||
          identifier.type == EntityType.ANY,
      '服务器ID类型错误: $identifier',
    );
    // 内部用户代理，复用用户核心能力（加解密/签名/验签/文档管理）
    _user = BaseUser(identifier);
    _host = host;
    _port = port;
    _isp = null;
  }

  /// 广播服务器ID常量（适配服务器发现/广播场景）
  /// ANY：匹配任意单台服务器（用于服务器发现请求）
  static ID ANY = Identifier.create(name: 'station', address: Address.ANYWHERE);

  /// EVERY：匹配所有服务器（用于全网广播消息）
  static ID EVERY = Identifier.create(
    name: 'stations',
    address: Address.EVERYWHERE,
  );

  /// 内部用户代理（复用用户的加密/解密等核心能力）
  /// 代理 BaseUser 实现 User 接口的所有方法，避免重复开发
  late User _user;

  /// 服务器主机地址
  /// 存储格式：IPv4（如 192.168.1.1）、IPv6（如 ::1）、域名（如 server.dim.chat）
  String? _host;

  /// 服务器端口
  /// 有效值范围：17~65535（小于17为系统端口，大于65535超出TCP/UDP端口范围）
  int _port = 0;

  /// 所属服务商ID
  /// 关联服务器归属的服务商实体，用于多服务商场景的服务器分组
  ID? _isp;

  /// 仅ID构造（未知主机端口）
  /// 适用场景：仅知道服务器ID，暂未获取到网络配置时初始化实体
  /// @param identifier - 服务器ID（STATION/ANY 类型）
  Station.fromID(ID identifier) : this(identifier, null, 0);

  /// 主机+端口构造（未知ID，使用广播ID ANY）
  /// 适用场景：服务器发现阶段，仅获取到网络地址，暂未绑定ID时初始化
  /// @param host - 服务器主机地址
  /// @param port - 服务器端口（17~65535）
  Station.fromRemote(String host, int port) : this(ANY, host, port);

  /// 相等性判断：复用服务商的服务器匹配逻辑
  /// 核心规则：由 ServiceProvider.sameStation 统一判定，支持按ID/主机端口/服务商多维度匹配，
  /// 若对比对象非 Station 类型，则降级使用 User 的相等性判断（按ID匹配）。
  /// @param other - 待对比对象
  /// @return 匹配返回true，否则返回false
  @override
  bool operator ==(Object other) {
    if (other is Station) {
      return ServiceProvider.sameStation(other, this);
    }
    return _user == other;
  }

  /// 哈希值：优先使用主机+端口，兜底使用用户哈希值
  /// 核心逻辑：
  /// 1. 有主机地址时：用 host.hashCode + port*13 生成哈希（避免端口相同的不同主机哈希冲突）；
  /// 2. 无主机地址时：降级使用 User 的哈希值（按ID生成）；
  /// 保证相同主机端口的服务器哈希值一致，适配集合/映射的键值匹配。
  /// @return 服务器实体的哈希值
  @override
  int get hashCode {
    if (_host != null) {
      return _host.hashCode + _port * 13;
    }
    return _user.hashCode;
  }

  /// 获取运行时类名（调试用）
  /// 核心逻辑：断言块中动态获取 runtimeType（仅调试模式生效），
  /// 正式环境返回固定值 'Station'，避免运行时类型解析开销。
  /// @return 运行时类名（调试模式为实际子类名，正式模式为 'Station'）
  String get className {
    String name = 'Station';
    assert(() {
      name = runtimeType.toString();
      return true;
    }());
    return name;
  }

  /// 字符串格式化（调试用）
  /// 输出格式：<类名 id="服务器ID" network=网络类型 host="主机" port=端口 />
  /// 示例：<Station id="station@anywhere" network=0 host="192.168.1.1" port=9394 />
  /// @return 格式化的调试字符串
  @override
  String toString() {
    String clazz = className;
    int network = identifier.address.network;
    return '<$clazz id="$identifier" network=$network host="$host" port=$port />';
  }

  /// 重新加载服务器配置（动态更新）
  /// 核心逻辑：从服务器文档中重新解析主机、端口、服务商ID，支持配置热更新，
  /// 无需重启应用即可更新服务器网络参数，适配服务器动态扩容/迁移场景。
  /// 解析规则：
  /// 1. host：从文档 'host' 字段读取，覆盖现有值；
  /// 2. port：从文档 'port' 字段读取，校验 17~65535 范围后覆盖；
  /// 3. provider：从文档 'provider' 字段解析为ID，覆盖服务商ID；
  /// 注意：仅当文档非空时执行解析，无文档则保留现有配置。
  Future<void> reload() async {
    Document? doc = await profile;
    if (doc != null) {
      // 解析主机地址（支持IPv4/IPv6/域名）
      String? host = Converter.getString(doc.getProperty('host'));
      if (host != null) {
        _host = host;
      }
      // 解析端口（校验端口范围：17~65535，避免无效端口）
      int? port = Converter.getInt(doc.getProperty('port'));
      if (port != null && port > 0) {
        assert(16 < port && port < 65536, '服务器端口错误: $port');
        _port = port;
      }
      // 解析所属服务商ID（关联服务商实体）
      ID? sp = ID.parse(doc.getProperty('provider'));
      if (sp != null) {
        _isp = sp;
      }
    }
  }

  /// 服务器档案
  /// 筛选最新通用文档（类型为 '*'），作为服务器配置源，
  /// 通用文档存储服务器的网络配置、服务商归属等核心信息，
  /// 优先返回最新文档，保证配置为最新状态。
  /// @return 最新通用服务器文档；无文档返回null
  Future<Document?> get profile async =>
      DocumentUtils.lastDocument(await documents, '*');

  /// 服务器主机地址
  /// 只读属性，需通过 reload() 从文档更新，避免直接修改导致配置不一致
  /// @return 主机地址（IPv4/IPv6/域名）；未配置返回null
  String? get host => _host;

  /// 服务器端口
  /// 只读属性，需通过 reload() 从文档更新，有效值范围 17~65535
  /// @return 服务器端口；未配置返回0
  int get port => _port;

  /// 所属服务商ID
  /// 只读属性，需通过 reload() 从文档更新，关联服务商实体
  /// @return 服务商ID；未配置返回null
  ID? get provider => _isp;

  //===== Entity 接口代理 =====
  /// 服务器唯一标识
  /// 代理内部 User 的 identifier，确保与用户实体ID逻辑一致
  /// @return 服务器ID（STATION/ANY 类型）
  @override
  ID get identifier => _user.identifier;

  /// 重新设置服务器ID（更新内部用户代理）
  /// 核心逻辑：创建新的 BaseUser 实例，继承原有数据源，替换内部代理，
  /// 保证ID更新后，加解密/文档管理等能力仍关联原数据源。
  /// @param sid - 新的服务器ID（STATION/ANY 类型）
  set identifier(ID sid) {
    User inner = BaseUser(sid);
    inner.dataSource = dataSource;
    _user = inner;
  }

  /// 实体类型（固定为 STATION 类型）
  /// 代理内部 User 的 type，确保协议层识别为服务器实体
  /// @return 实体类型值（EntityType.STATION）
  @override
  int get type => _user.type;

  /// 用户数据源（强类型转换）
  /// 代理内部 User 的 dataSource，强制转换为 UserDataSource，
  /// 非该类型触发断言，保证服务器实体的数据源类型正确。
  /// @return UserDataSource 实例；数据源为空/类型错误返回null
  @override
  UserDataSource? get dataSource {
    var facebook = _user.dataSource;
    if (facebook is UserDataSource) {
      return facebook;
    }
    assert(facebook == null, '用户数据源类型错误: $facebook');
    return null;
  }

  /// 设置用户数据源
  /// 代理内部 User 的 dataSource，关联服务器的数据源（元数据/文档/密钥）
  /// @param facebook - 实体数据源（可为null，清空数据源）
  @override
  set dataSource(EntityDataSource? facebook) {
    _user.dataSource = facebook;
  }

  /// 服务器元数据
  /// 代理内部 User 的 meta，获取服务器的核心身份元数据，
  /// 元数据包含服务器公钥、地址等核心信息，用于身份验证。
  /// @return 服务器元数据（非空，无元数据触发断言）
  @override
  Future<Meta> get meta async => await _user.meta;

  /// 服务器文档列表
  /// 代理内部 User 的 documents，获取服务器的所有配置文档，
  /// 包含通用配置文档、服务商关联文档等，用于 reload() 解析配置。
  /// @return 服务器文档列表（可为空）
  @override
  Future<List<Document>> get documents async => await _user.documents;

  //===== User 接口代理 =====
  /// 服务器签证文档
  /// 代理内部 User 的 visa，获取服务器的身份签证，
  /// 签证包含服务器扩展信息（如版本、服务商、有效期），用于密钥轮换。
  /// @return 服务器签证；无签证返回null
  @override
  Future<Visa?> get visa async => await _user.visa;

  /// 服务器关联的联系人列表
  /// 代理内部 User 的 contacts，获取服务器管理的用户/其他服务器列表，
  /// 用于服务器间通信、用户在线状态同步等场景。
  /// @return 联系人ID列表（可为空）
  @override
  Future<List<ID>> get contacts async => await _user.contacts;

  /// 验证数据签名（服务器验签）
  /// 代理内部 User 的 verify，使用服务器公钥验证数据签名，
  /// 确保接收的消息来自合法发送方，未被篡改。
  /// @param data - 原始数据（明文/密文）
  /// @param signature - 签名数据（发送方私钥签名结果）
  /// @return 验签通过返回true，否则返回false
  @override
  Future<bool> verify(Uint8List data, Uint8List signature) async =>
      await _user.verify(data, signature);

  /// 加密数据（服务器加密）
  /// 代理内部 User 的 encrypt，使用服务器公钥加密数据，
  /// 仅服务器持有私钥可解密，保证数据机密性。
  /// @param plaintext - 待加密的明文数据
  /// @return 加密后的密文数据（非空，加密失败触发断言）
  @override
  Future<Uint8List> encrypt(Uint8List plaintext) async =>
      await _user.encrypt(plaintext);

  /// 签名数据（服务器签名）
  /// 代理内部 User 的 sign，使用服务器私钥签名数据，
  /// 接收方可通过服务器公钥验签，确认消息来自合法服务器。
  /// @param data - 待签名的原始数据
  /// @return 签名数据（非空，签名失败触发断言）
  @override
  Future<Uint8List> sign(Uint8List data) async => await _user.sign(data);

  /// 解密数据（服务器解密）
  /// 代理内部 User 的 decrypt，使用服务器私钥解密密文，
  /// 还原发送方用服务器公钥加密的原始数据。
  /// @param ciphertext - 待解密的密文数据
  /// @return 解密后的明文数据；解密失败返回null
  @override
  Future<Uint8List?> decrypt(Uint8List ciphertext) async =>
      await _user.decrypt(ciphertext);

  /// 签名签证文档（服务器签证）
  /// 代理内部 User 的 signVisa，使用服务器私钥签名签证文档，
  /// 用于服务器更新公钥后，发布新签证通知关联实体。
  /// @param doc - 待签名的签证文档（ID需与服务器ID一致）
  /// @return 签名后的签证文档；签名失败返回null
  @override
  Future<Visa?> signVisa(Visa doc) async => await _user.signVisa(doc);

  /// 验证签证文档（服务器验签）
  /// 代理内部 User 的 verifyVisa，使用服务器元数据公钥验证签证签名，
  /// 确保签证文档来自合法服务器，未被篡改。
  /// @param doc - 待验证的签证文档
  /// @return 验签通过返回true，否则返回false
  @override
  Future<bool> verifyVisa(Visa doc) async => await _user.verifyVisa(doc);
}
