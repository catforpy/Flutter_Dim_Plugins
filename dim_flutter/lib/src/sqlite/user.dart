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

import '../common/constants.dart';
import 'helper/sqlite.dart';
import 'helper/task.dart';

import 'entity.dart';

/// 从SQL查询结果集中提取用户ID
/// [resultSet]: SQL查询结果集对象
/// [index]: 结果集行索引（此处未实际使用，为兼容父类接口保留）
/// 返回值: 解析后的用户ID对象（ID类型）
ID _extractUser(ResultSet resultSet, int index) {
  // 从结果集中获取'uid'字段的字符串值
  String? user = resultSet.getString('uid');
  // 将字符串解析为ID对象并返回（强制非空）
  return ID.parse(user)!;
}

/// 本地用户数据表处理器
/// 继承自DataTableHandler，负责本地用户表(tLocalUser)的CRUD操作
/// 泛型ID表示该处理器处理的数据类型为用户ID
class _UserTable extends DataTableHandler<ID> {
  /// 构造函数：初始化数据表处理器
  /// 关联EntityDatabase数据库，并指定数据提取方法_extractUser
  _UserTable() : super(EntityDatabase(), _extractUser);

  /// 本地用户数据表名称（关联EntityDatabase中的tLocalUser常量）
  static const String _table = EntityDatabase.tLocalUser;
  /// 查询时要获取的字段列表：仅查询用户ID(uid)
  static const List<String> _selectColumns = ["uid"];
  /// 插入数据时使用的字段列表：用户ID(uid)和选中标记(chosen)
  static const List<String> _insertColumns = ["uid", "chosen"];

  // protected - 受保护方法（仅内部/子类使用）
  /// 从本地用户表中移除指定用户
  /// [user]: 要移除的用户ID
  /// 返回值: 操作是否成功（true=成功，false=失败）
  Future<bool> removeUser(ID user) async {
    // 构建删除条件：uid等于目标用户ID的字符串形式
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    // 执行删除操作，返回值<0表示删除失败
    if (await delete(_table, conditions: cond) < 0) {
      // 记录错误日志
      logError('failed to remove local user: $user');
      return false;
    }
    return true;
  }

  // protected - 受保护方法（仅内部/子类使用）
  /// 向本地用户表添加新用户
  /// [user]: 要添加的用户ID
  /// [chosen]: 是否将该用户设为"选中/当前"状态（true=是，false=否）
  /// 返回值: 操作是否成功（true=成功，false=失败）
  Future<bool> addUser(ID user, bool chosen) async {
    // add other user with chosen flag = 0 - 注释说明：添加普通用户时chosen标记默认0
    // 准备插入的数据：用户ID字符串 + chosen标记（1=选中，0=未选中）
    List values = [
      user.toString(),
      chosen ? 1 : 0
    ];
    // 执行插入操作，返回值<=0表示插入失败
    if (await insert(_table, columns: _insertColumns, values: values) <= 0) {
      // 记录错误日志
      logError('failed to add local user: $user');
      return false;
    }
    return true;
  }

  // protected - 受保护方法（仅内部/子类使用）
  /// 更新指定用户的选中状态
  /// [user]: 目标用户ID
  /// [chosen]: 新的选中状态（true=选中，false=未选中）
  /// 返回值: 操作是否成功（true=成功，false=失败）
  Future<bool> updateUser(ID user, bool chosen) async {
    // 准备要更新的字段和值：仅更新chosen标记
    Map<String, dynamic> values = {
      'chosen': chosen ? 1 : 0
    };
    // 构建更新条件：uid等于目标用户ID的字符串形式
    SQLConditions cond;
    cond = SQLConditions(left: 'uid', comparison: '=', right: user.toString());
    // 执行更新操作，返回值<0表示更新失败
    if (await update(_table, values: values, conditions: cond) < 0) {
      // 记录错误日志
      logError('failed to update local user: $user');
      return false;
    }
    return true;
  }

  // protected - 受保护方法（仅内部/子类使用）
  /// 批量更新所有本地用户的选中状态
  /// [chosen]: 新的选中状态（true=全部选中，false=全部未选中）
  /// 返回值: 操作是否成功（true=成功，false=失败）
  Future<bool> updateUsers(bool chosen) async {
    // 准备要更新的字段和值：仅更新chosen标记
    Map<String, dynamic> values = {
      'chosen': chosen ? 1 : 0
    };
    // 构建更新条件：SQLConditions.kTrue 表示更新所有记录
    SQLConditions cond = SQLConditions.kTrue;
    // 执行批量更新操作，返回值<0表示更新失败
    if (await update(_table, values: values, conditions: cond) < 0) {
      // 记录错误日志
      logError('failed to update local users');
      return false;
    }
    return true;
  }

  // protected - 受保护方法（仅内部/子类使用）
  /// 加载所有本地用户列表
  /// 返回值: 按chosen标记降序排列的用户ID列表（选中的用户排在前面）
  Future<List<ID>> loadUsers() async {
    // 构建查询条件：SQLConditions.kTrue 表示查询所有记录
    SQLConditions cond = SQLConditions.kTrue;
    // 执行查询：去重、仅查询uid字段、按chosen降序排列
    return await select(_table, distinct: true, columns: _selectColumns,
        conditions: cond, orderBy: 'chosen DESC');
  }

}

/// 本地用户数据库操作任务类
/// 继承自DbTask，封装本地用户的读写操作，支持缓存和并发控制
/// 泛型参数说明：
/// - String: 缓存键的类型（固定为'local_users'）
/// - List<ID>: 缓存数据的类型（本地用户ID列表）
class _UsrTask extends DbTask<String, List<ID>> {
  /// 构造函数
  /// [mutexLock]: 互斥锁（父类参数，用于并发控制）
  /// [cachePool]: 缓存池（父类参数，用于数据缓存）
  /// [_table]: 本地用户数据表处理器实例
  /// [append]: 要添加的用户ID（可选）
  /// [remove]: 要移除的用户ID（可选）
  /// [chosen]: 选中标记（可选，仅添加用户时生效）
  _UsrTask(super.mutexLock, super.cachePool, this._table, {
    required ID? append,
    required ID? remove,
    required bool? chosen,
  }) : _append = append, _remove = remove, _chosen = chosen;

  /// 要添加的用户ID
  final ID? _append;
  /// 要移除的用户ID
  final ID? _remove;
  /// 选中标记（仅添加用户时使用）
  final bool? _chosen;

  /// 本地用户数据表处理器实例
  final _UserTable _table;

  /// 获取缓存键（固定为'local_users'）
  @override
  String get cacheKey => 'local_users';

  /// 从数据库读取本地用户数据（实现父类抽象方法）
  /// 返回值: 本地用户ID列表（null表示读取失败）
  @override
  Future<List<ID>?> readData() async {
    return await _table.loadUsers();
  }

  /// 向数据库写入本地用户数据（实现父类抽象方法）
  /// [localUsers]: 当前内存中的本地用户列表（会同步修改）
  /// 返回值: 是否成功执行写入操作（true=至少一个操作成功，false=全部失败）
  @override
  Future<bool> writeData(List<ID> localUsers) async {
    // 处理选中标记：默认false（未选中）
    bool chosen = _chosen == true;
    // 1. 执行添加用户操作
    bool ok1 = false;
    ID? append = _append;
    if (append != null) {
      // 调用数据表处理器添加用户
      ok1 = await _table.addUser(append, chosen);
      if (ok1) {
        // 添加成功：同步更新内存中的用户列表
        localUsers.add(append);
      }
    }
    // 2. 执行移除用户操作
    bool ok2 = false;
    ID? remove = _remove;
    if (remove != null) {
      // 调用数据表处理器移除用户
      ok2 = await _table.removeUser(remove);
      if (ok2) {
        // 移除成功：同步更新内存中的用户列表
        localUsers.remove(remove);
      }
    }
    // 只要添加/移除有一个成功，就返回true
    return ok1 || ok2;
  }

}

/// 本地用户缓存管理器
/// 继承自DataCache，实现UserDBI接口，封装本地用户的缓存和数据库操作
class UserCache extends DataCache<String, List<ID>> implements UserDBI {
  /// 构造函数：初始化缓存名称为'local_users'
  UserCache() : super('local_users');

  /// 本地用户数据表处理器实例
  final _UserTable _table = _UserTable();

  /// 创建新的本地用户操作任务
  /// [append]: 要添加的用户ID（可选）
  /// [remove]: 要移除的用户ID（可选）
  /// [chosen]: 选中标记（可选）
  /// 返回值: 新的_UsrTask实例
  _UsrTask _newTask({ID? append, ID? remove, bool? chosen}) =>
      _UsrTask(mutexLock, cachePool, _table, append: append, remove: remove, chosen: chosen);

  /// 获取所有本地用户列表（实现UserDBI接口）
  /// 返回值: 本地用户ID列表（空列表表示无本地用户）
  @override
  Future<List<ID>> getLocalUsers() async {
    // 创建空任务（仅读取数据）
    var task = _newTask();
    // 从缓存/数据库加载用户列表
    var localUsers = await task.load();
    // 空值处理：返回空列表
    return localUsers ?? [];
  }

  /// 保存本地用户列表（全量更新，实现UserDBI接口）
  /// [newUsers]: 新的用户列表（目标状态）
  /// 返回值: 是否保存成功（true=成功，false=失败）
  @override
  Future<bool> saveLocalUsers(List<ID> newUsers) async {
    // 创建空任务（仅读取数据）
    var task = _newTask();
    // 加载当前用户列表
    var localUsers = await task.load();
    // 空值处理：初始化为空列表
    localUsers ??= [];

    // 复制旧列表用于对比（避免修改原列表影响后续逻辑）
    var oldUsers = [...localUsers];
    // 记录更新的用户数量
    int count = 0;
    
    // 1. 移除不在新列表中的用户（差异删除）
    for (ID item in oldUsers) {
      // 新列表包含该用户：跳过
      if (newUsers.contains(item)) {
        continue;
      }
      // 创建移除用户的任务
      task = _newTask(remove: item);
      // 执行保存操作
      if (await task.save(localUsers)) {
        // 操作成功：计数+1
        ++count;
      } else {
        // 操作失败：记录错误日志并返回false
        logError('failed to remove user: $item');
        return false;
      }
    }
    
    // 2. 添加新列表中新增的用户（差异添加）
    for (ID item in newUsers) {
      // 旧列表已包含该用户：跳过
      if (oldUsers.contains(item)) {
        continue;
      }
      // 创建添加用户的任务
      task = _newTask(append: item);
      // 执行保存操作
      if (await task.save(localUsers)) {
        // 操作成功：计数+1
        ++count;
      } else {
        // 操作失败：记录错误日志并返回false
        logError('failed to add user: $item');
        return false;
      }
    }

    // 日志记录更新结果
    if (count == 0) {
      logWarning('users not changed: $oldUsers');
    } else {
      logInfo('updated $count user(s)');
    }

    // 发送本地用户列表更新通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kLocalUsersUpdated, this, {
      'action': 'update',
      'users': newUsers,
    });
    return true;
  }

  /// 添加单个本地用户（自定义方法）
  /// [user]: 要添加的用户ID
  /// 返回值: 是否添加成功（true=成功，false=失败）
  Future<bool> addUser(ID user) async {
    // 创建空任务（仅读取数据）
    var task = _newTask();
    // 加载当前用户列表
    var localUsers = await task.load();
    
    // 空值处理：初始化为空列表
    if (localUsers == null) {
      localUsers = [];
    } 
    // 检查用户是否已存在：存在则记录警告并返回true
    else if (localUsers.contains(user)) {
      logWarning('user exists: $user');
      return true;
    }

    // 创建添加用户的任务
    task = _newTask(append: user);
    // 执行保存操作
    var ok = await task.save(localUsers);
    
    // 添加成功：发送通知
    if (ok) {
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kLocalUsersUpdated, this, {
        'action': 'add',
        'user': user,
        'users': localUsers,
      });
    }
    return ok;
  }

  /// 移除单个本地用户（自定义方法）
  /// [user]: 要移除的用户ID
  /// 返回值: 是否移除成功（true=成功，false=失败）
  Future<bool> removeUser(ID user) async {
    // 创建空任务（仅读取数据）
    var task = _newTask();
    // 加载当前用户列表
    var localUsers = await task.load();
    
    // 空值处理：读取失败则记录错误并返回false
    if (localUsers == null) {
      logError('failed to get local users');
      return false;
    } 
    // 检查用户是否不存在：不存在则记录警告并返回true
    else if (!localUsers.contains(user)) {
      logWarning('user not exists: $user');
      return true;
    }

    // 创建移除用户的任务
    task = _newTask(remove: user);
    // 执行保存操作
    var ok = await task.save(localUsers);
    
    // 移除成功：发送通知
    if (ok) {
      var nc = NotificationCenter();
      nc.postNotification(NotificationNames.kLocalUsersUpdated, this, {
        'action': 'remove',
        'user': user,
        'users': localUsers,
      });
    }
    return ok;
  }

  /// 设置当前选中的用户（自定义方法）
  /// [user]: 要设为当前用户的ID
  /// 返回值: 是否设置成功（true=成功，false=失败）
  Future<bool> setCurrentUser(ID user) async {
    // load users - 加载当前用户列表
    var task = _newTask();
    var localUsers = await task.load();
    int pos;
    
    // 处理用户列表空值和位置
    if (localUsers == null) {
      localUsers = [];
      pos = -1;
    } else {
      // 获取用户在列表中的索引位置
      pos = localUsers.indexOf(user);
    }

    bool ok;
    // check users - 根据不同场景处理
    if (localUsers.isEmpty) {
      // 场景1：无本地用户 - 添加第一个用户并设为选中
      task = _newTask(append: user, chosen: true);
      ok = await task.save(localUsers);
    } else if (pos == 0) {
      // 场景2：用户已是当前选中用户（列表第一个）- 直接返回成功
      return true;
    } else if (pos > 0) {
      // 场景3：用户存在但不是当前用户 - 切换当前用户
      // 步骤1：将所有用户设为未选中
      await _table.updateUsers(false);
      // 步骤2：将目标用户设为选中
      ok = await _table.updateUser(user, true);
      // 步骤3：调整内存列表顺序 - 将目标用户移到第一个位置
      localUsers.removeAt(pos);
      localUsers.insert(0, user);
    } else {
      // 场景4：用户不存在 - 添加新用户并设为当前用户
      // 步骤1：将所有用户设为未选中
      await _table.updateUsers(false);
      // 步骤2：添加新用户并设为选中
      task = _newTask(append: user, chosen: true);
      ok = await task.save(localUsers);
      // 步骤3：调整内存列表顺序 - 将新用户移到第一个位置
      localUsers.remove(user);
      localUsers.insert(0, user);
    }
    
    // 检查操作结果：失败则记录错误并返回false
    if (!ok) {
      logError('failed to set current user');
      return false;
    }

    // 发送当前用户变更通知
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kLocalUsersUpdated, this, {
      'action': 'set',
      'user': user,
      'users': localUsers,
    });
    return true;
  }

  /// 获取当前选中的用户（自定义方法）
  /// 返回值: 当前用户ID（null表示无本地用户）
  Future<ID?> getCurrentUser() async {
    // 加载所有本地用户列表
    List<ID> localUsers = await getLocalUsers();
    // 返回列表第一个用户（按chosen降序排列，第一个即为选中用户）
    return localUsers.isEmpty ? null : localUsers[0];
  }

}