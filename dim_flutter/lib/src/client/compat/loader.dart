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

import 'package:dim_client/compat.dart';   // DIM-SDK兼容层基础库
import 'package:dim_client/common.dart';

import '../../common/protocol/search.dart';   // DIM-SDK通用接口（命令工厂/扩展加载器）

/// 兼容库加载器：继承DIM-SDK的LibraryLoader，注册自定义兼容层命令工厂
/// 核心作用：扩展DIM-SDK的命令解析能力，适配自定义/兼容版的命令协议
class CompatLibraryLoader extends LibraryLoader{
   /// 构造方法：初始化兼容库加载器，绑定自定义扩展加载器
  CompatLibraryLoader() : super(extensionLoader: _CompatExtensionLoader());
}

/// 私有兼容扩展加载器：继承CommonExtensionLoader，实现命令工厂注册逻辑
/// 核心功能：注册自定义/兼容版的命令解析工厂，让SDK能识别并解析扩展命令
class _CompatExtensionLoader extends CommonExtensionLoader {

  /// 重写命令工厂注册方法：扩展SDK的命令解析能力
  @override
  void registerCommandFactories(){
    // 先执行父类逻辑：注册SDK内置的命令工厂（保证基础命令可用）
    super.registerCommandFactories();

    // ===================== 注册自定义/兼容版命令工厂 =====================
    // 1. 上报命令（在线/离线广播）：注册"broadcast"命令的解析工厂
    //    作用：让SDK能解析"broadcast"类型的命令，映射为BaseReportCommand
    setCommandFactory('broadcast',creator: (dict) => BaseReportCommand(dict));
    // 注：注释掉的代码是备选方案，可按需启用（按具体协议调整）
    // setCommandFactory(ReportCommand.ONLINE, creator: (dict) => BaseReportCommand(dict));
    // setCommandFactory(ReportCommand.OFFLINE, creator: (dict) => BaseReportCommand(dict));

    // 2. 搜索命令：注册搜索相关命令的解析工厂
    //    - SearchCommand.SEARCH：通用搜索命令
    //    - SearchCommand.ONLINE_USERS：在线用户搜索命令
    //    作用：让SDK能解析这两类搜索命令，映射为BaseSearchCommand
    setCommandFactory(SearchCommand.SEARCH,       creator: (dict) => BaseSearchCommand(dict));
    setCommandFactory(SearchCommand.ONLINE_USERS, creator: (dict) => BaseSearchCommand(dict));

    // 3. 存储命令（注释掉，待实现）：联系人/私钥存储相关命令
    //    TODO: 后续可扩展存储命令的解析能力
    // Command.setFactory(StorageCommand.STORAGE, StorageCommand::new);
    // Command.setFactory(StorageCommand.CONTACTS, StorageCommand::new);
    // Command.setFactory(StorageCommand.PRIVATE_KEY, StorageCommand::new);
  }
}

// ===================== 注释掉的插件加载器（待实现） =====================
// 作用：预留地址/元数据工厂注册逻辑，用于扩展ID/元数据的解析规则
// class _PluginLoader extends ClientPluginLoader {
//
//   /// 注册地址工厂：自定义地址解析规则（如兼容不同格式的地址）
//   @override
//   void registerAddressFactory() {
//     /// TODO: 实现自定义地址工厂（继承BaseAddressFactory）
//     /// 作用：让SDK能解析自定义格式的地址ID
//     Address.setFactory(CompatibleAddressFactory());
//   }
//
//   /// 注册元数据工厂：自定义元数据解析规则（如MKM/BTC/ETH链的元数据）
//   @override
//   void registerMetaFactories() {
//     /// TODO: 实现自定义元数据工厂（继承GeneralMetaFactory）
//     /// 作用：适配不同区块链的元数据格式
//     var mkm = CompatibleMetaFactory(Meta.MKM);
//     var btc = CompatibleMetaFactory(Meta.BTC);
//     var eth = CompatibleMetaFactory(Meta.ETH);
//
//     // 注册不同类型的元数据工厂（支持数字/字符串标识）
//     Meta.setFactory('1', mkm);
//     Meta.setFactory('2', btc);
//     Meta.setFactory('4', eth);
//
//     Meta.setFactory('mkm', mkm);
//     Meta.setFactory('btc', btc);
//     Meta.setFactory('eth', eth);
//
//     Meta.setFactory('MKM', mkm);
//     Meta.setFactory('BTC', btc);
//     Meta.setFactory('ETH', eth);
//   }
// }