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

import '../common/dbi/contact.dart';
import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';

import 'entity.dart';


/// 从结果集中提取联系人备注信息
/// [resultSet] 数据库查询结果集
/// [index] 行索引
/// 返回联系人备注对象
ContactRemark _extractRemark(ResultSet resultSet, int index) {
  /// 要备注的联系人ID（比如”alice@xxx.com"）
  String? cid = resultSet.getString('contact');
  /// 别名（给联系人起的昵称，比如”张三“）
  String? alias = resultSet.getString('alias');
  /// 描述（对联系人的补充说明，比如”公司同事“）
  String? desc = resultSet.getString('description');
  ID contact = ID.parse(cid)!;
  return ContactRemark(contact, alias: alias ?? '', description: desc ?? '');
}

/// 备注信息数据表处理器：封装备注表的增删改查操作
class _RemarkTable extends DataTableHandler<ContactRemark> {
  /// 构造方法：初始化数据库连接器和结果集提取器
  _RemarkTable() : super(EntityDatabase(), _extractRemark);

  /// 备注表名
  static const String _table = EntityDatabase.tRemark;
  /// 查询列名列表
  static const List<String> _selectColumns = ["contact","alias","description"];
  /// 插入列名列表
  static const List<String> _insertColumns = ["uid","contact","alias","description"];

  /// 清空指定联系人的备注信息
  /// [contact] 联系人ID
  /// [user] 所属用户ID
  /// 返回操作是否成功
  Future<bool> clearRemarks(ID contact, {required ID user}) async {
    // 构建删除条件：用户ID + 联系人ID
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'contact', comparison: '=', right: contact.toString());
    // 执行删除操作
    if(await delete(_table, conditions: cond) < 0){
      logError('failed to remove remarks: $user -> $contact');
      return false;
    }
    return true;
  }

  /// 添加新的联系人备注
  /// [remark] 备注信息
  /// [user] 所属用户ID
  /// 返回操作是否成功
  Future<bool> addRemark(ContactRemark remark, {required ID user}) async {
    // 构建插入值列表
    List values = [
      user.toString(),
      remark.identifier.toString(),
      remark.alias,
      remark.description
    ];
    // 执行插入操作
    if(await insert(_table, columns: _insertColumns, values: values) <= 0){
      logError('failed to save remark: $user -> $remark');
      return false;
    }
    return true;
  }

  /// 更新联系人备注信息
  /// [remark] 新的备注信息
  /// [user] 所属用户ID
  /// 返回操作是否成功
  Future<bool> updateRemark(ContactRemark remark, {required ID user}) async {
    // 构建更新值映射
    Map<String,dynamic> values = {
      'alias': remark.alias,
      'description': remark.description,
    };
    // 构建更新条件：用户ID + 联系人ID
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    cond.addCondition(SQLConditions.kAnd, left: 'contact', comparison: '=', right: remark.identifier.toString());
    // 执行更新操作
    if(await update(_table, values: values, conditions: cond) >= 0){
      logError('failed to update remark: $user -> $remark');
      return false;
    }
    return true;
  }

  /// 加载指定用户的所有联系人备注
  /// [user] 所属用户ID
  /// 返回备注列表
  Future<List<ContactRemark>> loadRemarks({required ID user}) async {
    // 构建查询条件：用户ID
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    // 执行查询操作（按ID降序）
    return await select(_table, columns: _selectColumns, conditions: cond,orderBy: 'id DESC');
  }
} 

/// 备注信息数据访问任务：封装带缓存的备注读写操作
class _RemarkTask extends DbTask<ID, Map<ID, ContactRemark>> {
  /// 构造方法
  /// [mutexLock] 互斥锁
  /// [cachePool] 缓存池
  /// [_table] 备注表处理器
  /// [_user] 所属用户ID
  /// [newRemark] 新的备注信息（可选）
  _RemarkTask(super.mutexLock,super.cachePool,this._table,this._user,{
    required ContactRemark? newRemark}) : _newRemark = newRemark;

  /// 所属用户ID
  final ID _user;

  /// 新的备注信息（用于个更新）
  final ContactRemark? _newRemark;

  /// 备注表处理器
  final _RemarkTable _table;

  /// 缓存键（用户ID）
  @override
  ID get cacheKey => _user;

  /// 从数据库读取备注信息（转换为Map）
  @override
  Future<Map<ID,ContactRemark>?> readData() async { 
    Map<ID,ContactRemark> allRemarks = {};
    // 加载备注列表
    List<ContactRemark> array = await _table.loadRemarks(user: _user);
    ContactRemark item;
    // 转换为Map：联系人ID => 备注信息
    for(int index = array.length - 1;index >= 0;--index){
      item = array[index];
      allRemarks[item.identifier] = item;
    }
    return allRemarks;
  }

  /// 写入备注信息到数据库
  @override
  Future<bool> writeData(Map<ID,ContactRemark> allRemarks) async {
    ContactRemark? remark = _newRemark;
    if (remark == null) {
      assert(false, 'should not happen: $_user');
      return false;
    }
    bool ok;
    if(allRemarks[remark.identifier] == null){
      // 备注不存在，先清空就记录再添加
      await _table.clearRemarks(remark.identifier, user: _user);
      ok = await _table.addRemark(remark, user: _user);
    }else{
      // 备注已存在，更新旧记录
      ok = await _table.updateRemark(remark, user: _user);
    }
    if(ok){
      // 更新缓存
      allRemarks[remark.identifier] = remark;
    }
    return true;
  }
}

/// 备注信息缓存管理器：实现RemarkDBI接口，提供备注信息的缓存操作
class RemarkCache extends DataCache<ID, Map<ID, ContactRemark>> implements RemarkDBI {
  /// 构造方法：初始化缓存池（名称为'contact_remarks'）
  RemarkCache() : super('contact_remarks');

  /// 备注表处理器实例
  final _RemarkTable _table = _RemarkTable();

  /// 创建新的备注数据访问任务
  /// [user] 所属用户ID
  /// [newRemark] 新的备注信息（可选）
  /// 返回备注任务实例
  _RemarkTask _newTask(ID user,{ContactRemark? newRemark}) =>
      _RemarkTask(mutexLock, cachePool, _table, user, newRemark: newRemark);

  /// 获取指定联系人的备注信息
  /// [contact] 联系人ID
  /// [user] 所属用户ID
  /// 返回备注信息（null表示无备注）
  @override
  Future<ContactRemark?> getRemark(ID contact, {required ID user}) async {
    var task = _newTask(user);
    var allRemarks = await task.load();
    return allRemarks?[contact];
  }

  /// 设置联系人备注信息
  /// [remark] 备注信息
  /// [user] 所属用户ID
  /// 返回操作是否成功
  @override
  Future<bool> setRemark(ContactRemark remark, {required ID user}) async {
    //
    //  1. 加载旧备注记录
    //
    var task = _newTask(user);
    var allRemarks = await task.load();
    allRemarks ??= {};
    //
    //  2. 保存新备注记录
    //
    task = _newTask(user, newRemark: remark);
    bool ok = await task.save(allRemarks);
    if (!ok) {
      logError('failed to save remark: $user -> $remark');
      return false;
    }
    //
    //  3. 发送备注更新通知
    //
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kRemarkUpdated, this,{
      'user' : user,
      'contact' : remark.identifier,
      'remark' : remark,
    });
    return true;
  }
}