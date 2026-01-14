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

import 'helper/sqlite.dart';

///
///  存储元数据、文档、用户、联系人、群组成员
///
///     文件路径: '/data/data/chat.dim.sechat/databases/mkm.db'
///


/// 实体数据库连接器：管理mkm.db的创建和升级
class EntityDatabase extends DatabaseConnector{
  /// 构造方法：初始化数据库配置
  EntityDatabase() : super(name: dbName,version: dbVersion,
  onCreate: (db, version) {
    // 1.创建元数据表（meta）
    DatabaseConnector.createTable(db, tMeta, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "did VARCHAR(64) NOT NULL UNIQUE",   // 实体ID（唯一）
      "type INTEGER NOT NULL",             // 类型
      "pub_key TEXT NOT NULL",             // 公钥
      "seed VARCHAR(32)",                  // 种子
      "fingerprint VARCHAR(172)",          // 指纹
    ]);
    // 为did字段创建索引
    DatabaseConnector.createIndex(db, tMeta, 
    name: 'meta_id_index', fields: ['did']);

    // 2.创建文档表(document)
    DatabaseConnector.createTable(db, tDocument, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
          "did VARCHAR(64) NOT NULL",          // 实体ID
          "type VARCHAR(16)",                  // 文档类型
          "data TEXT NOT NULL",                // 文档内容
          "signature VARCHAR(172) NOT NULL",   // 签名
    ]);
    // 为did字段创建索引
    DatabaseConnector.createIndex(db, tDocument, 
    name: 'doc_id_index', fields: ['did']);

    // 3.创建本地用户表（local user）
    DatabaseConnector.createTable(db, tLocalUser, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "uid VARCHAR(64) NOT NULL UNIQUE",   // 用户ID（唯一）
      "chosen BIT", 
    ]);

    // 4. 创建联系人表
    _createContactTable(db);

    // 5. 创建备注表
    _createRemarkTable(db);
    // 6. 创建黑名单表
    _createBlockedTable(db);
    // 7. 创建静音列表表
    _createMutedTable(db);
  },
  onUpgrade: (db, oldVersion, newVersion) {
    if (oldVersion < 5) {
      _createRemarkTable(db);
      _createBlockedTable(db);
      _createMutedTable(db);
    }
  });

  // 创建联系人表
  static void _createContactTable(Database db){
    DatabaseConnector.createTable(db, tContact, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "uid VARCHAR(64) NOT NULL",               // 用户ID
      "contact VARCHAR(64) NOT NULL",           // 联系人ID
    ]);
    // 为uid字段创建索引
    DatabaseConnector.createIndex(db, tContact,
     name: 'user_id_index', fields: ['uid']);
  }

  // 创建备注表
  static void _createRemarkTable(Database db) {
    DatabaseConnector.createTable(db, tRemark, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "uid VARCHAR(64) NOT NULL",    // 用户ID（所属用户）
      "contact VARCHAR(64) NOT NULL",// 联系人ID（要备注的人）
      "alias VARCHAR(32)",           // 别名（给联系人起的昵称）
      "description TEXT",            // 描述（对联系人的备注说明）
    ]);
    // 为uid字段创建索引
    DatabaseConnector.createIndex(db, tRemark,
        name: 'user_id_index', fields: ['uid']);
  }

  // 创建黑名单表
  static void _createBlockedTable(Database db) {
    DatabaseConnector.createTable(db, tBlocked, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "uid VARCHAR(64) NOT NULL",    // 用户ID
      "blocked VARCHAR(64) NOT NULL",// 被拉黑的联系人ID
    ]);
    // 为uid字段创建索引
    DatabaseConnector.createIndex(db, tBlocked,
        name: 'user_id_index', fields: ['uid']);
  }

  // 创建静音列表表
  static void _createMutedTable(Database db) {
    DatabaseConnector.createTable(db, tMuted, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "uid VARCHAR(64) NOT NULL",    // 用户ID
      "muted VARCHAR(64) NOT NULL",  // 静音的联系人ID
    ]);
    // 为uid字段创建索引
    DatabaseConnector.createIndex(db, tMuted,
        name: 'user_id_index', fields: ['uid']);
  }

  /// 数据库文件名
  static const String dbName = 'mkm.db';
  /// 数据库版本号
  static const int dbVersion = 5;

  /// 表名常量
  static const String tMeta       = 't_meta';         //元数据表
  static const String tDocument   = 't_document';     //文档表

  static const String tLocalUser  = 't_local_user';   //本地用户表
  static const String tContact    = 't_contact';      //联系人表

  static const String tRemark     = 't_remark';       //备注表
  static const String tBlocked    = 't_blocked';      //黑名单表
  static const String tMuted      = 't_muted';        //静音列表表
}

///
///  存储群组信息
///
///     文件路径: '/data/data/chat.dim.sechat/databases/group.db'
///


/// 群组数据库连接器：管理group.db的创建和升级
class GroupDatabase extends DatabaseConnector {
  /// 构造方法：初始化数据库配置
  GroupDatabase() : super(name: dbName, version: dbVersion,
      onCreate: (db, version) {
        // // 重置群组命令表（已注释）
        // DatabaseConnector.createTable(db, tResetGroup, fields: [
        //   "id INTEGER PRIMARY KEY AUTOINCREMENT",
        //   "gid VARCHAR(64) NOT NULL",
        //   "cmd TEXT NOT NULL",
        //   "msg TEXT NOT NULL",
        // ]);
        // DatabaseConnector.createIndex(db, tResetGroup,
        //     name: 'gid_index', fields: ['gid']);
        
        // 1. 创建群组成员表
        _createMemberTable(db);
        // 2. 创建群组管理员表
        _createAdminTable(db);
        // 3. 创建群组历史命令表
        _createHistoryTable(db);
      }, onUpgrade: (db, oldVersion, newVersion) {
        // 版本升级：v2及以上添加成员/管理员/历史命令表
        if (oldVersion < 2) {
          _createMemberTable(db);
          _createAdminTable(db);
          _createHistoryTable(db);
        }
      });

  // 创建群组成员表
  static void _createMemberTable(Database db) {
    DatabaseConnector.createTable(db, tMember, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "gid VARCHAR(64) NOT NULL",    // 群组ID
      "member VARCHAR(64) NOT NULL", // 成员ID
    ]);
    // 为gid字段创建索引
    DatabaseConnector.createIndex(db, tMember,
        name: 'group_id_index', fields: ['gid']);
  }

  // 创建群组管理员表
  static void _createAdminTable(Database db) {
    DatabaseConnector.createTable(db, tAdmin, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "gid VARCHAR(64) NOT NULL",    // 群组ID
      "admin VARCHAR(64) NOT NULL",  // 管理员ID
    ]);
    // 为gid字段创建索引
    DatabaseConnector.createIndex(db, tAdmin,
        name: 'group_id_index', fields: ['gid']);
  }

  // 创建群组历史命令表
  static void _createHistoryTable(Database db) {
    DatabaseConnector.createTable(db, tHistory, fields: [
      "id INTEGER PRIMARY KEY AUTOINCREMENT",
      "gid VARCHAR(64) NOT NULL",    // 群组ID
      "cmd VARCHAR(32) NOT NULL",    // 命令名称
      "time INTEGER NOT NULL",       // 命令时间（秒）
      "content TEXT NOT NULL",       // 命令内容
      "message TEXT NOT NULL",       // 消息内容
    ]);
    // 为gid字段创建索引
    DatabaseConnector.createIndex(db, tHistory,
        name: 'gid_index', fields: ['gid']);
  }

  /// 数据库文件名
  static const String dbName = 'group.db';
  /// 数据库版本号
  static const int dbVersion = 2;

  /// 表名常量
  static const String tAdmin         = 't_admin';    // 管理员表
  static const String tMember        = 't_member';   // 成员表

  static const String tHistory       = 't_history';  // 历史命令表

  // static const String tResetGroup = 't_reset_group'; // 重置群组表（已注释）
}