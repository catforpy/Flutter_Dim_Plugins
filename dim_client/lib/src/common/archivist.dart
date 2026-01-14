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

/// 通用档案管理员实现类
/// 继承Barrack（兵营），实现Archivist（档案管理员）接口，负责实体缓存、Meta/文档持久化等
class CommonArchivist extends Barrack with Logging implements Archivist {
  /// 构造方法
  /// [facebook] Facebook实例（弱引用，避免内存泄漏）
  /// [database] 账户数据库接口
  CommonArchivist(Facebook facebook, this.database) : _facebook = WeakReference(facebook);

  /// Facebook如引用
  final WeakReference<Facebook> _facebook;
  /// 账户数据库接口（用于持久化Meta/文档）
  final AccountDBI database;

  /// 获取Facebook实例（可能为空，需判空）
  /// 受保护方法
  Facebook? get facebook => _facebook.target;
  
  /// 内存缓存：用户缓存（ID->User）
  late final MemoryCache<ID,User>   _userCache = createUserCache();
  /// 内存缓存：群组缓存（ID -> Group）
  late final MemoryCache<ID,Group>  _groupCache = createGroupCache();

  // 受保护方法：创建用户缓存实例（默认使用ThanosCache）
  MemoryCache<ID,User> createUserCache() => ThanosCache();
  // 受保护方法：创建群组缓存实例（默认使用ThanosCache）
  MemoryCache<ID, Group> createGroupCache() => ThanosCache();

  /// 内存回收方法（收到内存警告时调用）
  /// 会议处50%的缓存对象（ThanosCache特性）
  /// 返回：剩余的缓存对象数量
  int reduceMemory(){
    int cnt1 = _userCache.reduceMemory();
    int cnt2 = _groupCache.reduceMemory();
    return cnt1 + cnt2;
  }

  //
  //  Barrack 接口实现
  //

  /// 缓存用户对象
  /// [user] 要缓存的用户对象
  @override
  void cacheUser(User user){
    // 设置用户数据源为Facebook(为空时)
    user.dataSource ??= facebook;
    // 存入用户缓存
    _userCache.put(user.identifier, user);
  }

  /// 缓存群组对象
  /// [group] 要缓存的群组对象
  @override
  void cacheGroup(Group group){
    // 设置群组数据源为Facebook(为空时)
    group.dataSource ??= facebook;
    // 存入群组缓存
    _groupCache.put(group.identifier, group);
  }

  /// 获取缓存的用户对象
  /// [identifier] 用户ID
  /// 返回：缓存的用户对象（无缓存返回null）
  @override
  User? getUser(ID identifier) => _userCache.get(identifier);

  /// 获取缓存的群组对象
  /// [identifier] 群组ID
  /// 返回：缓存的群组对象（无缓存返回null）
  @override
  Group? getGroup(ID identifier) => _groupCache.get(identifier);

  //
  //  Archivist 接口实现
  //

  /// 保存Meta到数据库
  /// [meta] 要保存的Meta
  /// [identifier] 对应的实体ID
  /// 返回：true=保存成功，false=保存失败
  @override
  Future<bool> saveMeta(Meta meta,ID identifier) async{
    //
    //  1. 检查Meta有效性
    //
    if(!checkMeta(meta,identifier)){
      // 断言：Meta无效（调试模式触发）
      assert(false, 'meta not valid: $identifier');
      return false;
    }
    //
    //  2. 检查Meta是否重复
    //
    Meta? old = await facebook?.getMeta(identifier);
    if(old != null){
      // 日志：Meta已存在，无需重复保存
      logDebug('meta duplicated: $identifier');
      return true;
    }
    //
    //  3. 保存到数据库
    //
    return await database.saveMeta(meta, identifier);
  }

  // 受保护方法：检查Meta有效性
  bool checkMeta(Meta meta,ID identifier){
    // Meta有效，且Meta与ID匹配
    return meta.isValid && MetaUtils.matchIdentifier(identifier, meta);
  }

  /// 保存文档到数据库
  /// [doc] 要保存的文档（Visa/Bulletin等）
  /// 返回：true=保存成功，false=保存失败
  @override
  Future<bool> saveDocument(Document doc)async{
    //
    //  1. 检查文档有效性
    //
    if (await checkDocumentValid(doc)) {
      // 文档有效，继续
    } else {
      // 断言：文档无效（调试模式触发）
      assert(false, 'document not valid: ${doc.identifier}');
      return false;
    }
    //
    //  2. 检查文档是否过期
    //
    if (await checkDocumentExpired(doc)) {
      // 日志：丢弃过期文档
      logInfo('drop expired document: $doc');
      return false;
    }
    //
    //  3. 保存到数据库
    //
    return await database.saveDocument(doc);
  }

  // 受保护方法：检查文档有效性
  Future<bool> checkDocumentValid(Document doc) async {
    ID identifier = doc.identifier;
    DateTime? docTime = doc.time;
    // 检查文档时间
    if (docTime == null) {
      // 日志：文档无时间字段（警告）
      // assert(false, 'document error: $doc');
      logWarning('document without time: $identifier');
    } else {
      // 校准时钟：确保文档时间不超出未来30分钟（避免无效的未来文档）
      DateTime nearFuture = DateTime.now().add(Duration(minutes: 30));
      if (docTime.isAfter(nearFuture)) {
        // 断言：文档时间错误（调试模式触发）
        assert(false, 'document time error: $docTime, $doc');
        // 日志：文档时间错误（错误）
        logError('document time error: $docTime, $identifier');
        return false;
      }
    }
    // 验证文档签名有效性
    return await verifyDocument(doc);
  }

  // 受保护方法：验证文档签名
  Future<bool> verifyDocument(Document doc) async{
    // 文档已验证过，直接返回true
    if (doc.isValid) {
      return true;
    }
    // 获取文档所属实体的Meta
    Meta? meta = await facebook?.getMeta(doc.identifier);
    if (meta == null) {
      // 日志：获取Meta失败（警告）
      logWarning('failed to get meta: ${doc.identifier}');
      return false;
    }
    // 使用Meta公钥验证文档签名
    return doc.verify(meta.publicKey);
  }

  // 受保护方法：检查文档是否过期
  Future<bool> checkDocumentExpired(Document doc) async {
    ID identifier = doc.identifier;
    String type = DocumentUtils.getDocumentType(doc) ?? '*';
    // 获取该实体的所有文档
    List<Document>? documents = await facebook?.getDocuments(identifier);
    if (documents == null || documents.isEmpty) {
      // 无历史文档，未过期
      return false;
    }
    // 获取同类型的最新文档
    Document? old = DocumentUtils.lastDocument(documents, type);
    // 新文档是否比最新历史文档过期
    return old != null && DocumentUtils.isExpired(doc, old);
  }

  // 获取用户的Meta公钥（用于验证签名）
  /// [user] 用户ID
  /// 返回：Meta公钥（无Meta返回null）
  @override
  Future<VerifyKey?> getMetaKey(ID user) async {
    Meta? meta = await facebook?.getMeta(user);
    // 断言：获取Meta失败（调试模式触发）
    // assert(meta != null, 'failed to get meta for: $entity');
    return meta?.publicKey;
  }

  /// 获取用户的Visa公钥（用于加密消息）
  /// [user] 用户ID
  /// 返回：Visa公钥（无Visa返回null）
  @override
  Future<EncryptKey?> getVisaKey(ID user) async {
    // 获取用户的所有文档
    var docs = await facebook?.getDocuments(user);
    if (docs == null || docs.isEmpty) {
      return null;
    }
    // 获取最新的Visa文档
    var visa = DocumentUtils.lastVisa(docs);
    // 断言：获取Visa失败（调试模式触发）
    // assert(doc != null, 'failed to get visa for: $user');
    return visa?.publicKey;
  }

  /// 获取本地用户列表
  /// 返回：本地用户ID列表
  @override
  Future<List<ID>> getLocalUsers() async {
    return await database.getLocalUsers();
  }
}
