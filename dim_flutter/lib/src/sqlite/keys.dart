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

import '../channels/manager.dart';
import '../common/constants.dart';
import '../common/platform.dart';
import 'helper/sqlite.dart';

///
///  存储私钥
///
///     文件路径: '/data/data/chat.dim.sechat/databases/key.db'
///


/// 加密密钥数据库连接器：管理key.db的创建和表结构
class CryptoKeyDatabase extends DatabaseConnector{
  /// 构造方法：初始化数据库配置
  CryptoKeyDatabase() : super(name: dbName,version: dbVersion,
      onCreate: (db, version) {
        // 创建私钥表
        DatabaseConnector.createTable(db, tPrivateKey, fields: [
          "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "uid VARCHAR(64) NOT NULL",    // 用户ID
          "pri_key TEXT NOT NULL",       // 私钥（JSON字符串）
          "type CHAR(1)",                // 密钥类型
          "sign BIT",                    // 是否用于签名
          "decrypt BIT",                 // 是否用于解密
        ]);
        // 为uid字段创建索引
        DatabaseConnector.createIndex(db, tPrivateKey,
          name: 'user_id_index', fields: ['uid']);

        // // 消息密钥表（已注释）
        // DatabaseConnector.createTable(db, tMsgKey, fields: [
        //   "id INTEGER PRIMARY KEY AUTOINCREMENT",
        //   "sender VARCHAR(64) NOT NULL",
        //   "receiver VARCHAR(64) NOT NULL",
        //   "pwd TEXT NOT NULL",
        // ]);
        // DatabaseConnector.createIndex(db, tMsgKey,
        //     name: 'direction_index', fields: ['sender', 'receiver']);
  });

  /// 数据库文件名
  static const String dbName = 'key.db';
  /// 数据库版本号
  static const int dbVersion = 1;

  /// 表名常量
  static const String tPrivateKey = 't_private_key';  // 私钥表
  // static const String tMsgKey     = 't_msg_key';     // 消息密钥表（已注释）
}

/// 从数据库结果集中提取私钥对象
/// [resultSet] 数据库查询结果集
/// [index] 行索引
/// 返回私钥对象
PrivateKey _extractPrivateKey(ResultSet resultSet, int index) {
  String? json = resultSet.getString('pri_key');
  Map? info = JSON.decode(json!);
  return PrivateKey.parse(info)!;
}

/// 私钥数据表处理器：实现PrivateKeyDBI接口，封装私钥表的增删改查
class _PrivateKeyTable extends DataTableHandler<PrivateKey> implements PrivateKeyDBI {
  /// 构造方法：初始化数据库连接器和结果集提取器
  _PrivateKeyTable() : super(CryptoKeyDatabase(), _extractPrivateKey);

  /// 私钥表名
  static const String _table = CryptoKeyDatabase.tPrivateKey;
  /// 查询列名列表
  static const List<String> _selectColumns = ["pri_key"];
  /// 插入列名列表
  static const List<String> _insertColumns = ["uid", "pri_key", "type", "sign", "decrypt"];

  /// 获取用于解密的私钥列表
  /// [user] 用户ID
  /// 返回解密密钥列表
  @override
  Future<List<DecryptKey>> getPrivateKeysForDecryption(ID user) async {
    // ios平台使用原生通道获取秘钥
    if(DevicePlatform.isIOS){
      ChannelManager man = ChannelManager();
      return await man.dbChannel.getPrivateKeysForDecryption(user);
    }
    // 构建查询条件：用户ID + 解密标志 = 1
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    cond.addCondition(SQLConditions.kAnd, left: 
      'decrypt', comparison: '<>', right: 0);
    // 查询前3条（按类型降序）
    List<PrivateKey> array = await select(_table, columns: _selectColumns, 
        conditions: cond,orderBy: 'type DESC, id DESC',limit: 3);
    // 转换为解密密钥列表
    return PrivateKeyDBI.convertDecryptKeys(array);
  }

  /// 获取用于签名的私钥
  /// [user] 用户ID
  /// 返回私钥对象（默认返回签证签名密钥）
  @override
  Future<PrivateKey?> getPrivateKeyForSignature(ID user) async {
    // iOS平台使用原生通道获取密钥
    if (DevicePlatform.isIOS/* || DevicePlatform.isMacOS*/) {
      ChannelManager man = ChannelManager();
      return await man.dbChannel.getPrivateKeyForSignature(user);
    }
    // TODO: 支持多私钥
    return await getPrivateKeyForVisaSignature(user);
  }

  /// 获取用于签证签名的私钥
  /// [user] 用户ID
  /// 返回私钥对象
  @override
  Future<PrivateKey?> getPrivateKeyForVisaSignature(ID user) async {
    // iOS平台使用原生通道获取密钥
    if (DevicePlatform.isIOS/* || DevicePlatform.isMacOS*/) {
      ChannelManager man = ChannelManager();
      return await man.dbChannel.getPrivateKeyForVisaSignature(user);
    }
    // 构建查询条件：用户ID + 类型 = M + 签名标志 =1
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'type', comparison: '=', right: PrivateKeyDBI.kMeta);
    cond.addCondition(SQLConditions.kAnd, left: 'sign', comparison: '<>', right: 0);
    // 查询最新的一条
    List<PrivateKey> array = await select(_table, columns: _selectColumns, 
        conditions: cond, orderBy: 'id DESC', limit: 1);
    // 返回第一条记录
    return array.isEmpty ? null : array.first;
  }

  /// 保存私钥
  /// [key] 私钥对象
  /// [type] 密钥类型
  /// [user] 用户ID
  /// [sign] 是否用于签名（默认1）
  /// [decrypt] 是否用于解密（必填）
  /// 返回操作是否成功
  @override
  Future<bool> savePrivateKey(PrivateKey key, String type, ID user,
      {int sign = 1, required int decrypt}) async {
    // iOS平台使用原生通道保存密钥
    if (DevicePlatform.isIOS/* || DevicePlatform.isMacOS*/) {
      ChannelManager man = ChannelManager();
      return await man.dbChannel.savePrivateKey(key, type, user,
          sign: sign, decrypt: decrypt);
    }
    // 序列化为JSON字符串
    String json = JSON.encode(key.toMap());
    // 构建插入值列表
    List values = [user.toString(), json, type, sign, decrypt];
    // 执行插入操作
    return await insert(_table, columns: _insertColumns, values: values) > 0;
  }
}

/// 私钥缓存管理器：继承数据表处理器，增加内存缓存和通知机制
class PrivateKeyCache extends _PrivateKeyTable {
  /// 构造方法：初始化缓存池
  PrivateKeyCache(){
    _privateKeyCaches = CacheManager().getPool('private_id_key');  // ID密钥缓存
    _decryptKeysCache = CacheManager().getPool('private_msg_keys');// 解密密钥缓存
  }

  /// ID秘钥缓存池
  late final CachePool<ID,PrivateKey> _privateKeyCaches;
  /// 解密密钥缓存池
  late final CachePool<ID, List<DecryptKey>> _decryptKeysCache;

  /// 获取用于解密的私钥列表（优先从缓存读取）
  @override
  Future<List<DecryptKey>> getPrivateKeysForDecryption(ID user) async {
    CachePair<List<DecryptKey>>? pair;
    CacheHolder<List<DecryptKey>>? holder;
    List<DecryptKey>? value;
    double now = TimeUtils.currentTimeSeconds;

    await lock();
    try{
      // 1. 从缓存池查：返回的是 CachePair（value + holder）
      pair = _decryptKeysCache.fetch(user,now: now);
      holder = pair?.holder;    // 拿到状态容器（CacheHolder）
      value = pair?.value;      // 拿到实际值（存活则非null，过期则null）

      if(value == null){
        if(holder == null){
          // 情况1：缓存池里根本没有这个user的holder → 从未加载过，准备去数据库查
        }else if(holder.isAlive(now: now)){
          // 情况2：holder存在且「存活（未过期）」，但value是null → 说明之前加载过但结果是空，直接返回空列表
          return [];
        }else{
          // 情况3：holder存在但「已过期」→ 先给holder续期（避免并发重复加载），再去数据库查
          holder.renewal(128,now: now);
        }
        // 2.数据库加载实际值
        value = await super.getPrivateKeysForDecryption(user);
        // 更新缓存：把数据库查到的value包裹成新的holder，存入缓存池（有效期10小时）
        _decryptKeysCache.updateValue(user, value, 30000,now: now);
      }
    }finally{
      unlock();   //解锁
    }
    // 返回缓存值
    return value;
  }

  /// 获取用于签证签名的私钥（优先从缓存读取）
  @override
  Future<PrivateKey?> getPrivateKeyForVisaSignature(ID user) async  {
    CachePair<PrivateKey>? pair;
    CacheHolder<PrivateKey>? holder;
    PrivateKey? value;
    double now = TimeUtils.currentTimeSeconds;

    await lock();  //加锁保证线程安全
    try{
      // 1. 从缓存池查：返回的是 CachePair（value + holder）
      pair = _privateKeyCaches.fetch(user,now: now);
      holder = pair?.holder;
      value = pair?.value;

      if(value == null){ 
        if(holder == null){
          // 情况1：缓存池里根本没有这个user的holder → 从未加载过，准备去数据库查
        }else if(holder.isAlive(now: now)){
          // 情况2：holder存在且「存活（未过期）」，但value是null → 说明之前加载过但结果是空，直接返回空列表
          return null;
        }else{
          // 情况3：holder存在但「已过期」→ 先给holder续期（避免并发重复加载
          holder.renewal(128,now: now);
        }
        // 2.数据库加载实际值
        value = await super.getPrivateKeyForVisaSignature(user);
        // 3.更新缓存：把数据库查到的value包裹成新的holder，存入缓存池（有效期10小时）
        _privateKeyCaches.updateValue(user, value, 30000,now: now);
      }
    }finally{
      unlock();   //解锁
    }
    return value;
  }

  /// 保存私钥（带缓存更新和通知）
  @override
  Future<bool> savePrivateKey(PrivateKey key, String type, ID user,
      {int sign = 1, required int decrypt}) async {
    double now = TimeUtils.currentTimeSeconds;

    // 1.更新内存缓存
    if(type == PrivateKeyDBI.kMeta){
      // 更新ID秘钥缓存
      _privateKeyCaches.updateValue(user, key, 36000,now: now);
    }else{
      // 添加到解密密钥列表
      List<DecryptKey> decryptKeys = await getPrivateKeysForDecryption(user);
      List<PrivateKey> privateKeys = PrivateKeyDBI.convertPrivateKeys(decryptKeys);
      List<PrivateKey>? keys = PrivateKeyDBI.insertKey(key, privateKeys);
      if (keys == null) {
        // 密钥已存在，无需更新
        return false;
      }
      // 更新解密密钥缓存
      decryptKeys = PrivateKeyDBI.convertDecryptKeys(keys);
      _decryptKeysCache.updateValue(user, decryptKeys, 36000, now: now);
    }

    // 2. 保存到数据库
    if(await super.savePrivateKey(key, type, user, decrypt: decrypt)){
      // 保存成功
    }else{
      Log.error('failed to save private key: $user');
      return false;
    }

    // 3. 发送私钥保存通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kPrivateKeySaved, this, {
      'user': user,
      'key': key,
    });
    return true;
  }
}

/// 消息密钥缓存管理器：实现CipherKeyDBI接口，管理消息加密密钥的内存缓存
class MsgKeyCache implements CipherKeyDBI {
  /// 构造方法
  MsgKeyCache();

  /// 内存缓存：receiver => {sender => key}
  final Map<ID,Map<ID,SymmetricKey>> _caches = {};

  /// 缓存消息加密密钥
  /// [sender] 发送者ID
  /// [receiver] 接收者ID
  /// [key] 对称密钥
  @override
  Future<void> cacheCipherKey({required ID sender,required ID receiver,
    required SymmetricKey key}) async {
    if(receiver.isBroadcast){
      // 广播消息无加密
      return;
    }
    // 获取接受者的秘钥映射
    Map<ID,SymmetricKey>? keyMap = _caches[receiver];
    if(keyMap == null){
      keyMap = {};
      _caches[receiver] = keyMap;
    }
    // 缓存秘钥
    keyMap[sender] = key;
  }

  /// 获取消息加密密钥（不存在时可生成）
  /// [sender] 发送者ID
  /// [receiver] 接收者ID
  /// [generate] 是否生成新密钥（默认false）
  /// 返回对称密钥
  @override
  Future<SymmetricKey?> getCipherKey({required ID sender,required ID receiver,
                                      bool generate = false}) async {
    if(receiver.isBroadcast){
      // 关播消息返回明文秘钥
      return Password.kPlainKey;
    }
    SymmetricKey? key;
    // 检查缓存
    Map<ID,SymmetricKey>? keyMap = _caches[receiver];
    if(keyMap != null){
      key = keyMap[sender];
    }
    // 缓存未命中
    if(key == null && generate){
      if(keyMap == null){
        keyMap = {};
        _caches[receiver] = keyMap;
      }
      // 生成AES对称密钥
      key = SymmetricKey.generate(SymmetricAlgorithms.AES);
      keyMap[sender] = key!;
      Log.warning('cipher key generated: $sender -> $receiver');
    }
    return key;
  }
}