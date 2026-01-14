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

import 'package:dimsdk/dimsdk.dart';          // 引入DIM-SDK核心库（提供基础接口/抽象类）
import 'package:dim_plugins/loader.dart';     // 引入DIM插件加载器基础类

import '../../common/compat/entity.dart';     // 引入通用兼容层的实体类（如EntityIDFactory）
import '../../common/compat/loader.dart';     // 引入通用兼容层的加载器基类

import '../facebook.dart';                    // 引入客户端Facebook类（核心身份管理类）


/// 【核心类】库加载器
/// 设计模式：单例思想（通过_loaded标记实现）、组合模式（聚合扩展加载器+插件加载器）
/// 核心职责：统一管理DIM-SDK的扩展和插件加载流程，确保初始化逻辑只执行一次
/// 应用场景：SDK初始化入口，在APP启动时调用run()完成所有核心能力的加载
class LibraryLoader {
  /// 构造方法：初始化扩展加载器和插件加载器（支持外部自定义，默认用通用实现）
  /// 设计思想：依赖注入，提高扩展性（外部可替换自定义加载器）
  /// [extensionLoader]：扩展加载器（加载SDK扩展功能，如基础能力增强）
  /// [pluginLoader]：插件加载器（加载DIM插件，如业务层功能扩展）
  LibraryLoader({ExtensionLoader? extensionLoader, PluginLoader? pluginLoader}) {
    // 优先使用外部传入的加载器，否则使用默认的通用实现（兜底策略）
    this.extensionLoader = extensionLoader ?? CommonExtensionLoader();
    this.pluginLoader = pluginLoader ?? ClientPluginLoader();
  }

  /// 扩展加载器实例（负责加载SDK核心扩展，如基础接口实现、工具类等）
  late final ExtensionLoader extensionLoader;
  /// 插件加载器实例（负责加载DIM业务插件，如ID工厂、加密插件等）
  late final PluginLoader pluginLoader;

  /// 加载状态标记（防止重复加载）
  /// 线程安全说明：Dart单线程模型下无需加锁，确保run()只执行一次初始化
  bool _loaded = false;

  /// 【对外暴露的核心方法】执行加载流程
  /// 特点：单例模式思想（非严格单例，通过状态标记确保只加载一次）
  /// 调用时机：APP启动初始化阶段（如main函数、初始化页）
  void run(){
    if(_loaded){
      // 已加载过，直接返回（避免重复初始化导致的资源冲突/逻辑异常）
      return;
    }else{
      // 标记为已加载，防止重复执行（先标记后执行，避免异步场景下的重复调用）
      _loaded = true;
    }
    // 执行实际的加载逻辑（内部方法，子类可重写扩展）
    load();
  }

  /// 【内部核心方法】执行具体的加载操作
  /// 访问修饰符：protected（Dart中通过命名规范模拟，子类可重写）
  /// 加载顺序：先扩展后插件（插件依赖扩展提供的基础能力）
  void load() {
    // 1. 加载扩展（先加载扩展，为插件提供基础能力，如核心接口实现）
    extensionLoader.load();
    // 2. 加载插件（后加载插件，基于扩展能力扩展业务，如定制化ID工厂）
    pluginLoader.load();
  }
}

/// 【客户端插件加载器】继承通用插件加载器，定制客户端的ID工厂注册逻辑
/// 设计模式：模板方法模式（重写父类的钩子方法registerIDFactory）
/// 核心作用：覆盖通用加载器的ID工厂注册方法，替换为客户端定制的ID工厂
/// 父类依赖：CommonPluginLoader（通用插件加载器，提供基础插件加载逻辑）
class ClientPluginLoader extends CommonPluginLoader {
   /// 【重写方法】注册ID工厂（核心扩展点/钩子方法）
  /// 设计思想：模板方法模式，父类定义加载流程，子类定制关键步骤
  /// 父类行为：CommonPluginLoader中该方法为空/默认实现，子类定制化
  /// 核心效果：替换SDK全局ID工厂，后续所有ID操作都使用客户端定制逻辑
  @override
  void registerIDFactory() {
    // 将SDK全局的ID工厂替换为客户端定制的_IdentifierFactory
    // 全局生效：后续所有ID的生成/创建/解析都会走这个工厂类
    ID.setFactory(_IdentifierFactory());
  }
}

/// 全局ID工厂实例（通用兼容层的实体ID工厂）
/// 作用：作为客户端定制工厂的"底层实现"，提供基础的ID处理能力
/// 设计思想：装饰器模式，客户端工厂在其基础上扩展ANS查询能力
IDFactory _identifierFactory = EntityIDFactory();

/// 【客户端定制ID工厂】实现IDFactory接口，扩展ID解析逻辑
/// 访问控制：私有类（_开头），仅在当前文件内使用，避免外部依赖
/// 核心扩展：在解析ID时优先查询ANS（去中心化命名系统），提升ID识别能力
/// 接口实现：完整实现IDFactory的3个核心方法（生成/创建/解析）
class _IdentifierFactory implements IDFactory {
  /// 【实现方法】生成身份标识ID（基于元数据生成唯一ID）
  /// 核心逻辑：由公钥哈希生成地址，结合网络类型/终端生成完整ID
  /// [meta]：元数据（包含公钥等核心信息，ID生成的核心依据）
  /// [network]：网络类型（如1=主网/2=测试网，区分不同环境的ID）
  /// [terminal]：终端标识（如app/ios/android/pc，区分同一用户的不同设备）
  /// 返回值：生成的唯一身份ID（用户/群组标识）
  /// 设计选择：直接复用通用逻辑，不做定制（保持ID生成规则的统一性）
  @override
  ID generateIdentifier(Meta meta, int? network, {String? terminal}) {
    // 直接复用通用兼容层ID工厂的生成逻辑（通用逻辑已满足需求，无需定制）
    return _identifierFactory.generateIdentifier(meta, network, terminal: terminal);
  }

  /// 【实现方法】创建身份标识ID（已知地址等信息构建ID对象）
  /// 应用场景：已知地址/名称时，快速构建ID对象（如从数据库读取后还原）
  /// [name]：名称（可选，如用户名/群组名，易记标识）
  /// [address]：地址（必填，由公钥哈希生成的唯一标识，ID的核心部分）
  /// [terminal]：终端标识（可选，区分同一用户的不同设备）
  /// 返回值：构建完成的ID对象
  /// 设计选择：直接复用通用逻辑，不做定制（保持ID创建规则的统一性）
  @override
  ID createIdentifier({String? name, required Address address, String? terminal}) {
    // 直接复用通用兼容层ID工厂的创建逻辑（通用逻辑已满足需求，无需定制）
    return _identifierFactory.createIdentifier(name: name, address: address, terminal: terminal);
  }

  /// 【实现方法】解析身份标识ID（核心扩展点，定制化逻辑）
  /// 核心价值：扩展ANS查询，支持易记名称解析为ID（如"alice"→"alice@xxx.com"）
  /// [identifier]：字符串形式的ID（如"alice@xxx.com"、纯地址、ANS名称）
  /// 返回值：解析后的ID对象（null表示解析失败）
  /// 执行流程：ANS查询 → 通用解析（兜底）
  @override
  ID? parseIdentifier(String identifier) {
    // 第一步：优先查询ANS（去中心化命名系统）
    // ANS价值：将易记的名称（如alice）映射为唯一的ID，提升用户体验
    // 容错处理：ClientFacebook.ans可能为null（未初始化），需判空避免空指针
    ID? id = ClientFacebook.ans?.identifier(identifier);
    if (id != null) {
      // ANS查询到匹配的ID，直接返回（优先级最高，覆盖通用解析逻辑）
      return id;
    }
    // 第二步：ANS未查询到（无匹配名称），使用通用兼容层的解析逻辑兜底
    // 兜底逻辑：支持标准格式ID字符串（如地址、name@address）的解析
    return _identifierFactory.parseIdentifier(identifier);
  }
}
