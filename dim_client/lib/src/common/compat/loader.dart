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

import 'dart:typed_data';

import 'package:dim_client/common.dart';
import 'package:dim_client/compat.dart';
import 'package:dim_client/ok.dart';
import 'package:dim_client/plugins.dart';
import 'package:dim_client/src/common/compat/entity.dart';
import 'package:dim_client/src/common/protocol/ans.dart';
import 'package:dim_client/src/common/protocol/handshake.dart';
import 'package:dim_plugins/dim_plugins.dart';

/// 通用扩展加载器
/// 扩展ExtensionLoader，注册自定义内容/命令工厂
class CommonExtensionLoader extends ExtensionLoader {

  /// 注册自定义内容工厂
  @override
  void registerCustomizedFactories() {
    // 注册应用自定义内容工厂
    setContentFactory(ContentType.CUSTOMIZED, 'customized', creator: (dict) => AppCustomizedContent(dict));
    setContentFactory(ContentType.APPLICATION, 'application', creator: (dict) => AppCustomizedContent(dict));
  }

  /// 注册命令工厂（重写）
  @override
  void registerCommandFactories() {
    super.registerCommandFactories();

    // 注册ANS命令工厂
    setCommandFactory(AnsCommand.ANS,creator: (dict) => BaseAnsCommand(dict),);

    // 注册握手/登录命令工厂
    setCommandFactory(HandshakeCommand.HANDSHAKE,creator: (dict) => BaseAnsCommand(dict),);
    setCommandFactory(LoginCommand.LOGIN, creator: (dict) => BaseLoginCommand(dict));

    // 注册静音/拉黑命令工厂
    setCommandFactory(MuteCommand.MUTE,   creator: (dict) => MuteCommand(dict));
    setCommandFactory(BlockCommand.BLOCK, creator: (dict) => BlockCommand(dict));

    // 注册状态上报命令工厂
    setCommandFactory(ReportCommand.REPORT,  creator: (dict) => BaseReportCommand(dict));
    setCommandFactory(ReportCommand.ONLINE,  creator: (dict) => BaseReportCommand(dict));
    setCommandFactory(ReportCommand.OFFLINE, creator: (dict) => BaseReportCommand(dict));

    // 注册群组查询命令工厂（已废弃）
    setCommandFactory(QueryCommand.QUERY,  creator: (dict) => QueryGroupCommand(dict));
  }
}

/// 通用插件加载器
/// 扩展PluginLoader,配置各类基础组件工厂
class CommonPluginLoader extends PluginLoader{

  /// 加载插件（重写）
  @override
  void load(){
    // 设置安全转换器
    Converter.converter = _SafeConverter();
    super.load();
  }

  /// 注册ID工厂
  @override
  void registerIDFactory(){
    ID.setFactory(EntityIDFactory());
  }

  /// 注册地址工厂
  @override
  void registerAddressFactory(){
    Address.setFactory(CompatibleAddressFactory());
  }

  /// 注册Meta工厂
  @override
  void registerMetaFactory(){
    // 创建兼容性Meta工厂
    var mkm = CompatibleMetaFactory(MetaType.MKM);
    var btc = CompatibleMetaFactory(MetaType.BTC);
    var eth = CompatibleMetaFactory(MetaType.ETH);

    // 注册数字类型标识
    Meta.setFactory('1', mkm);
    Meta.setFactory('2', btc);
    Meta.setFactory('3', eth);

    // 注册小写字符串标识
    Meta.setFactory('mkm', mkm);
    Meta.setFactory('btc', btc);
    Meta.setFactory('eth', eth);

    // 注册大写字符串标识
    Meta.setFactory('MKM', mkm);
    Meta.setFactory('BTC', btc);
    Meta.setFactory('ETH', eth);
  }

  /// 注册Base64编码器
  @override
  void registerRSAKeyFactories(){
    /// 注册RSA公钥工厂
    var rsaPub = RSAPublicKeyFactory();
    PublicKey.setFactory(AsymmetricAlgorithms.RSA, rsaPub);
    PublicKey.setFactory('SHA256withRSA', rsaPub);
    PublicKey.setFactory('RSA/ECB/PKCS1Padding', rsaPub);

    /// 注册RSA私钥工厂
    var rsaPri = RSAPrivateKeyFactory();
    PrivateKey.setFactory(AsymmetricAlgorithms.RSA, rsaPri);
    PrivateKey.setFactory('SHA256withRSA', rsaPri);
    PrivateKey.setFactory('RSA/ECB/PKCS1Padding', rsaPri);
  }
}

/// 自定义Base64编码器
/// 扩展Base64Coder,添加字符串清理逻辑
class _Base64Coder extends Base64Coder {
  
  /// 解码Base64字符串（重写）
  /// @param string  - Base64字符串
  /// @return 解码后的二进制数据
  @override
  Uint8List? decode(String string){
    // 清理Base64字符串中的无效字符
    string = trimBase64String(string);
    return super.decode(string);
  }

  /// 清理Base64字符串
  /// @param b64 - 原始Base64字符串
  /// @return 清理后的Base64字符串
  static String trimBase64String(String b64) {
    if (b64.contains('\n')) {
      // 移除换行、回车、制表符、空格
      b64 = b64.replaceAll('\n', '');
      b64 = b64.replaceAll('\r', '');
      b64 = b64.replaceAll('\t', '');
      b64 = b64.replaceAll(' ', '');
    }
    // 移除首尾空白字符
    return b64.trim();
  }
}

/// 自定义RSA私钥工厂
/// 扩展RSAPrivateKeyFactory，创建带时间戳的RSA私钥
class _RSAPrivateKeyFactory extends RSAPrivateKeyFactory {

  /// 生成RSA私钥
  @override
  PrivateKey generatePrivateKey() {
    Map key = {'algorithm': AsymmetricAlgorithms.RSA};
    return _RSAPrivateKey(key);
  }

  /// 解析RSA私钥
  @override
  PrivateKey? parsePrivateKey(Map key) {
    return _RSAPrivateKey(key);
  }

}

/// 带创建时间的RSA私钥
/// 扩展RSAPrivateKey，自动添加/维护创建时间戳
class _RSAPrivateKey extends RSAPrivateKey {
  /// 构造方法
  /// @param dict - 密钥字典
  _RSAPrivateKey(super.dict) {
    // 检查并设置创建时间
    DateTime? time = getDateTime('time');
    if (time == null) {
      time = DateTime.now();
      setDateTime('time', time);
    }
  }

  /// 获取公钥（重写）
  /// 自动将私钥的创建时间同步到公钥
  @override
  PublicKey get publicKey {
    PublicKey key = super.publicKey;
    DateTime? time = getDateTime('time');
    if (time != null) {
      key.setDateTime('time', time);
    }
    return key;
  }

}

/// 安全转换器
/// 扩展BaseConverter，添加异常捕获和日志记录
class _SafeConverter extends BaseConverter with Logging {

  /// 获取布尔值（重写）
  @override
  bool? getBool(Object? value, bool? defaultValue) {
    try {
      return super.getBool(value, defaultValue);
    } catch (e, st) {
      logError('failed to get bool: $value, error: $e, $st');
      return defaultValue;
    }
  }

  /// 获取整数值（重写）
  @override
  int? getInt(Object? value, int? defaultValue) {
    try {
      return super.getInt(value, defaultValue);
    } catch (e, st) {
      logError('failed to get int: $value, error: $e, $st');
      return defaultValue;
    }
  }

  /// 获取浮点数值（重写）
  @override
  double? getDouble(Object? value, double? defaultValue) {
    try {
      return super.getDouble(value, defaultValue);
    } catch (e, st) {
      logError('failed to get double: $value, error: $e, $st');
      return defaultValue;
    }
  }

  /// 获取日期时间（重写）
  @override
  DateTime? getDateTime(Object? value, DateTime? defaultValue) {
    try {
      return super.getDateTime(value, defaultValue);
    } catch (e, st) {
      logError('failed to get datetime: $value, error: $e, $st');
      return defaultValue;
    }
  }

}