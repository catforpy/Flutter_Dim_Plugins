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

import 'package:dim_client/group.dart';  // DIM-SDK群组管理
import 'package:dim_client/client.dart'; // DIM-SDK客户端基类

import '../models/config.dart';    // 应用配置模型
import 'compat/loader.dart';       // 兼容库加载器
import 'cpu/text.dart';            // 文本内容处理器

import 'client.dart';     // 客户端核心
import 'database.dart';   // 共享数据库
import 'emitter.dart';    // 共享消息发送器
import 'messenger.dart';  // 共享消息收发器

/// 全局变量单例类：统一管理应用核心实例
/// 核心职责：
/// 1. 按顺序初始化应用核心组件（配置→数据库→身份管理→客户端→发送器）
/// 2. 管理全局共享实例的生命周期
/// 3. 提供核心实例的全局访问入口
class GlobalVariable {
  /// 单例工厂方法
  factory GlobalVariable() => _instance;
  /// 静态单例实例
  static final GlobalVariable _instance = GlobalVariable._internal();
  
  /// 私有构造方法：初始化核心组件
  GlobalVariable._internal() {
    /// Step 1: 初始化应用配置
    config = createConfig();
    /// Step 2: 创建共享数据库
    database = createDatabase();
    /// Step 3: 创建身份管理核心
    facebook = createFacebook(database);
    /// Step 4: 创建客户端核心
    terminal = createClient(facebook, database);
    /// Step 5: 创建消息发送器
    emitter = createEmitter();
    /// Step 6: 设置消息收发器（延迟初始化）
  }

  // ===================== 核心实例成员 =====================
  late final Config config;                // 应用配置
  late final SharedDatabase database;      // 共享数据库

  late final ClientFacebook facebook;      // 身份管理核心
  SharedMessenger? _messenger;             // 消息收发器（延迟初始化）

  late final SharedEmitter emitter;        // 消息发送器
  late final Client terminal;              // 客户端核心

  bool? isBackground;                      // 应用后台状态标记

  // ===================== 消息收发器访问器 =====================
  /// 消息收发器获取器
  SharedMessenger? get messenger => _messenger;
  
  /// 消息收发器设置器（Step 6）
  /// 扩展：同步设置群组管理器/实体检查器的消息收发器
  set messenger(SharedMessenger? transceiver) {
    _messenger = transceiver;
    
    // 设置群组管理器的消息收发器
    SharedGroupManager man = SharedGroupManager();
    man.messenger = transceiver;
    
    // 设置实体检查器的消息收发器
    var checker = facebook.entityChecker;
    if (checker is ClientChecker) {
      checker.messenger = transceiver;
    } else {
      assert(false, 'entity checker error: $checker');
    }
  }

  // ===================== 组件创建方法 =====================
  /// Step 1: 创建应用配置
  static Config createConfig() {
    var loader = CompatLibraryLoader();
    loader.run();       // 加载兼容库
    Config config = Config();
    config.load();      // 加载配置文件
    return config;
  }

  /// Step 2: 创建共享数据库
  static SharedDatabase createDatabase() {
    // 创建数据库实例
    var db = SharedDatabase();
    // 清理过期的服务内容
    ServiceContentHandler(db).clearExpiredContents();
    return db;
  }

  /// Step 3: 创建身份管理核心
  static ClientFacebook createFacebook(SharedDatabase db) {
    var facebook = ClientFacebook(db);
    // 设置文档归档器
    facebook.barrack = ClientArchivist(facebook, db);
    // 设置实体检查器
    facebook.entityChecker = ClientChecker(facebook, db);
    // 设置群组管理器的身份管理核心
    SharedGroupManager man = SharedGroupManager();
    man.facebook = facebook;
    return facebook;
  }

  /// Step 4: 创建客户端核心
  static Client createClient(ClientFacebook facebook, SharedDatabase db) {
    var client = Client(facebook, db);
    client.start();     // 启动客户端
    return client;
  }

  /// Step 5: 创建消息发送器
  static SharedEmitter createEmitter() {
    return SharedEmitter();
  }
  
}
