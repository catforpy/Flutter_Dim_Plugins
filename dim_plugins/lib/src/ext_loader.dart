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

import 'package:dimp/dimp.dart';  // DIM核心协议库

import 'dkd/cmd_fact.dart';       // 命令工厂相关
import 'dkd/factory.dart';        // DKD消息工厂相关

import 'ext/account.dart';        // 账号扩展
import 'ext/command.dart';        // 命令扩展
import 'ext/crypto.dart';         // 加密扩展
import 'ext/format.dart';         // 格式扩展
import 'ext/message.dart';        // 消息扩展


/// 核心扩展加载器
/// 核心作用：
/// 1. 统一注册DIM-SDK的所有核心工厂和辅助类；
/// 2. 初始化消息/内容/命令的解析器和创建器；
/// 3. 提供可扩展的注册接口，支持自定义内容/命令类型；
/// 设计模式：工厂模式 + 注册器模式，实现组件解耦和扩展；
class ExtensionLoader{

  /// 注册所有核心工厂（入口方法）
  void load(){
    // 1.注册核心辅助类（加密、格式、账号、消息、命令）
    registerCoreHelpers();

    // 2. 注册消息工厂（信封、即时消息、安全消息、可靠消息）
    registerMessageFactories();

    // 3. 注册内容工厂（文本、文件、图片、命令等）
    registerContentFactories();
    // 4. 注册命令工厂（元数据、文档、群组等命令）
    registerCommandFactories();
  }

  /// 注册核心辅助类（加密/格式/账号/消息/命令）
  // protected
  void registerCoreHelpers(){
    // 1.加密相关辅助类（对称/非对称秘钥工厂）
    registerCryptoHelpers();
    // 2. 格式相关辅助类（PNF/TED编码解码）
    registerFormatHelpers();

    // 3. 账号相关辅助类（地址/ID/元数据/文档工厂）
    registerAccountHelpers();

    // 4. 消息相关辅助类（信封/内容/安全消息工厂）
    registerMessageHelpers();
    // 5. 命令相关辅助类（命令解析/创建工厂）
    registerCommandHelpers();
  }

  /// 注册加密辅助类
  void registerCryptoHelpers(){
    // 创建通用加密秘钥工厂（支持对称/非对称秘钥的创建/解析）
    var cryptoHelper = CryptoKeyGeneralFactory();
    // 获取加密扩展单例
    var ext = SharedCryptoExtensions();
    // 注册对称密钥辅助类
    ext.symmetricHelper = cryptoHelper;
    // 注册私钥辅助类
    ext.privateHelper   = cryptoHelper;
    // 注册公钥辅助类
    ext.publicHelper    = cryptoHelper;
    // 注册通用加密辅助类
    ext.helper          = cryptoHelper;
  }

  /// 注册格式辅助类（PNF/TED）
  void registerFormatHelpers() {
    // 创建通用格式工厂（支持PNF/TED的编码/解码）
    var formatHelper = FormatGeneralFactory();
    // 获取格式扩展单例
    var ext = SharedFormatExtensions();
    // 注册PNF（可抑制网络文件）辅助类
    ext.pnfHelper      = formatHelper;
    // 注册TED（可传输数据）辅助类
    ext.tedHelper      = formatHelper;
    // 注册通用格式辅助类
    ext.helper         = formatHelper;
  }

  /// 注册账号辅助类（地址/ID/元数据/文档）
  void registerAccountHelpers(){
    // 创建通用账号工厂（支持地址/ID/元数据/文档的创建/解析）
    var accountHelper = AccountGeneralFactory();
    // 获取账号扩展单例
    var ext = SharedAccountExtensions();
    // 注册地址辅助类
    ext.addressHelper     = accountHelper;
    // 注册ID辅助类
    ext.idHelper          = accountHelper;  
    // 注册元数据辅助类
    ext.MetaHelper        = accountHelper;
    // 注册文档辅助类
    ext.docHelper         = accountHelper;
    // 注册通用账号辅助类
    ext.helper            = accountHelper;
  }

  /// 注册消息辅助类（信封/内容/安全消息）
  void registerMessageHelpers() {
    // 创建通用消息工厂（支持各类消息的创建/解析）
    var msgHelper = MessageGeneralFactory();
    // 获取消息扩展单例
    var ext = SharedMessageExtensions();
    // 注册内容辅助类
    ext.contentHelper     = msgHelper;
    // 注册信封辅助类
    ext.envelopeHelper    = msgHelper;
    // 注册即时消息辅助类
    ext.instantHelper     = msgHelper;
    // 注册安全消息辅助类
    ext.secureHelper      = msgHelper;
    // 注册可靠消息辅助类
    ext.reliableHelper    = msgHelper;
    // 注册通用消息辅助类
    ext.helper            = msgHelper;
  }

  /// 注册命令辅助类
  void registerCommandHelpers(){
    // 创建通用命令工厂（支持各类命令的创建/解析）
    var cmdHelper = CommandGeneralFactory();
    // 获取命令扩展单元
    var ext = SharedCommandExtensions();
    // 注册命令辅助类
    ext.cmdHelper        = cmdHelper;
    // 注册通用命令辅助类
    ext.helper           = cmdHelper;
  }

  /// 注册消息工厂（信封/各类消息）
  // protected
  void registerMessageFactories() {
    // 创建消息工厂实例
    MessageFactory factory = MessageFactory();

    // 注册信封工厂（所有消息的信封都由该工厂创建/解析）
    Envelope.setFactory(factory);

    // 注册即时消息工厂（未加密的原始消息）
    InstantMessage.setFactory(factory);
    // 注册安全消息工厂（加密消息）
    SecureMessage.setFactory(factory);
    // 注册可靠消息工厂（可靠消息）
    ReliableMessage.setFactory(factory);
  }

  /// 注册核心内容工厂（文本/文件/图片/命令等）
  // protected
  void registerContentFactories() {
    // ========== 基础内容类型 ==========
    // 文本消息
    setContentFactory(ContentType.TEXT,'text',creator:(dict) => BaseTextContent(dict));

    // 文件消息（基础类型）
    setContentFactory(ContentType.FILE, 'file', creator: (dict) => BaseFileContent(dict));
    // 图片消息（文件子类）
    setContentFactory(ContentType.IMAGE, 'image', creator: (dict) => ImageFileContent(dict));
    // 音频消息（文件子类）
    setContentFactory(ContentType.AUDIO, 'audio', creator: (dict) => AudioFileContent(dict));
    // 视频消息（文件子类）
    setContentFactory(ContentType.VIDEO, 'video', creator: (dict) => VideoFileContent(dict));

    // 网页消息
    setContentFactory(ContentType.PAGE, 'page', creator: (dict) => WebPageContent(dict));

    // 名片消息
    setContentFactory(ContentType.NAME_CARD, 'card', creator: (dict) => NameCardContent(dict));

    // 引用消息（回复/引用其他消息）
    setContentFactory(ContentType.QUOTE, 'quote', creator: (dict) => BaseQuoteContent(dict));

    // 金钱消息（基础类型）
    setContentFactory(ContentType.MONEY, 'money', creator: (dict) => BaseMoneyContent(dict));
    // 转账消息（金钱子类）
    setContentFactory(ContentType.TRANSFER, 'transfer', creator: (dict) => TransferMoneyContent(dict));
    // ... 可扩展其他金钱相关类型

    // 命令消息（基础类型）
    setContentFactory(ContentType.COMMAND, 'command', factory: GeneralCommandFactory());

    // 历史命令消息（获取历史消息）
    setContentFactory(ContentType.HISTORY, 'history', factory: HistoryCommandFactory());

    // 内容数组（多条内容组合）
    setContentFactory(ContentType.ARRAY, 'array', creator: (dict) => ListContent(dict));

    // 合并转发消息
    setContentFactory(ContentType.COMBINE_FORWARD, 'combine', creator: (dict) => CombineForwardContent(dict));

    // 绝密消息（转发加密消息）
    setContentFactory(ContentType.FORWARD, 'forward', creator: (dict) => SecretContent(dict));

    // 未知内容类型（兜底）
    setContentFactory(ContentType.ANY, '*', creator: (dict) => BaseContent(dict));

    // 注册自定义内容工厂（应用层扩展）
    registerCustomizedFactories();
  }

  /// 注册自定义内容工厂（应用层扩展点）
  // protected
  void registerCustomizedFactories() {
    // 应用自定义内容
    setContentFactory(ContentType.CUSTOMIZED, 'customized', creator: (dict) => AppCustomizedContent(dict));
    //setContentFactory(ContentType.APPLICATION, 'application', creator: (dict) => AppCustomizedContent(dict));
  }

  /// 注册内容工厂（核心工具方法）
  /// [msgType] - 内容类型标识（如ContentType.TEXT）
  /// [alias] - 类型别名（如'text'）
  /// [factory] - 内容工厂实例（可选）
  /// [creator] - 内容创建器（可选）
  // protected
  void setContentFactory(String msgType, String alias, {ContentFactory? factory, ContentCreator? creator}) {
    // 注册工厂实例
    if (factory != null) {
      Content.setFactory(msgType, factory);
      Content.setFactory(alias, factory);
    }
    // 注册创建器（包装为ContentParser）
    if (creator != null) {
      Content.setFactory(msgType, ContentParser(creator));
      Content.setFactory(alias, ContentParser(creator));
    }
  }
  
  /// 注册命令工厂（核心工具方法）
  /// [cmd] - 命令类型标识（如Command.META）
  /// [factory] - 命令工厂实例（可选）
  /// [creator] - 命令创建器（可选）
  // protected
  void setCommandFactory(String cmd, {CommandFactory? factory, CommandCreator? creator}) {
    // 注册工厂实例
    if (factory != null) {
      Command.setFactory(cmd, factory);
    }
    // 注册创建器（包装为CommandParser）
    if (creator != null) {
      Command.setFactory(cmd, CommandParser(creator));
    }
  }

  /// 注册核心命令工厂（元数据/文档/群组等命令）
  // protected
  void registerCommandFactories() {
    // ========== 基础命令类型 ==========
    // 元数据命令（更新/获取身份元数据）
    setCommandFactory(Command.META, creator: (dict) => BaseMetaCommand(dict));

    // 文档命令（更新/获取身份文档）
    setCommandFactory(Command.DOCUMENTS, creator: (dict) => BaseDocumentCommand(dict));

    // 回执命令（消息已读/送达回执）
    setCommandFactory(Command.RECEIPT, creator: (dict) => BaseReceiptCommand(dict));

    // ========== 群组命令 ==========
    // 通用群组命令工厂
    setCommandFactory('group', factory: GroupCommandFactory());
    // 邀请入群命令
    setCommandFactory(GroupCommand.INVITE,  creator: (dict) => InviteGroupCommand(dict));
    /// 'expel'已废弃（使用'reset'替代）
    setCommandFactory(GroupCommand.EXPEL,   creator: (dict) => ExpelGroupCommand(dict));
    // 加入群组命令
    setCommandFactory(GroupCommand.JOIN,    creator: (dict) => JoinGroupCommand(dict));
    // 退出群组命令
    setCommandFactory(GroupCommand.QUIT,    creator: (dict) => QuitGroupCommand(dict));
    /// 'query'已废弃
    //setCommandFactory(GroupCommand.QUERY, creator: (dict) => QueryGroupCommand(dict));
    // 重置群组命令（更新群成员/群信息）
    setCommandFactory(GroupCommand.RESET,   creator: (dict) => ResetGroupCommand(dict));
    
    // ========== 群管理员命令 ==========
    // 任命管理员命令
    setCommandFactory(GroupCommand.HIRE,    creator: (dict) => HireGroupCommand(dict));
    // 解除管理员命令
    setCommandFactory(GroupCommand.FIRE,    creator: (dict) => FireGroupCommand(dict));
    // 管理员辞职命令
    setCommandFactory(GroupCommand.RESIGN,  creator: (dict) => ResignGroupCommand(dict));
  }
}

/// 内容创建器类型定义
/// 入参：包含内容属性的Map
/// 返回值：内容对象（失败返回null）
typedef ContentCreator = Content? Function(Map dict);

/// 命令创建器类型定义
/// 入参：包含命令属性的Map
/// 返回值：命令对象（失败返回null）
typedef CommandCreator = Command? Function(Map dict);

/// 内容解析器（包装ContentCreator为ContentFactory）
/// 核心作用：适配Creator和Factory接口，简化内容创建器的注册
class ContentParser implements ContentFactory {
  ContentParser(this._builder);
  final ContentCreator _builder;

  @override
  Content? parseContent(Map content) {
    // 校验必选字段：sn（序列号）
    if (content['sn'] == null) {
      // 内容序列号不能为空
      assert(false, 'content error: $content');
      return null;
    }
    // 调用创建器生成内容对象
    return _builder(content);
  }
}

/// 命令解析器（包装CommandCreator为CommandFactory）
/// 核心作用：适配Creator和Factory接口，简化命令创建器的注册
class CommandParser implements CommandFactory {
  CommandParser(this._builder);
  final CommandCreator _builder;

  @override
  Command? parseCommand(Map content) {
    // 校验必选字段：sn（序列号）、command（命令类型）
    if (content['sn'] == null || content['command'] == null) {
      // 命令序列号/类型不能为空
      assert(false, 'command error: $content');
      return null;
    }
    // 调用创建器生成命令对象
    return _builder(content);
  }
}