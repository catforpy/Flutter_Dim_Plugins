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

import 'package:dimsdk/dimsdk.dart';    // DIM核心协议库（定义基础命令/消息模型）
import 'package:lnc/log.dart';          // 日志工具（打印不同级别日志：info/error/warning）

import '../../common/dbi/session.dart'; // 会话数据库接口（定义登录命令的存储/读取方法）
import '../../common/protocol/ans.dart'; // ANS（地址命名系统）协议模型（AnsCommand）
import '../../common/protocol/login.dart'; // 登录命令协议模型（LoginCommand）
import '../../group/shared.dart';       // 群组共享管理器（维护群组消息状态）
import '../facebook.dart';              // 客户端Facebook（用户/群组信息核心管理类）
import '../messenger.dart';             // 客户端Messenger（消息收发核心类）

/// ANS命令处理器
/// 设计定位：处理去中心化地址命名系统（ANS）相关命令
/// 核心功能：
/// 1. 区分ANS命令类型（查询/更新）：通过records字段是否为空判断；
/// 2. 处理ANS记录查询：记录日志，无业务处理（查询结果由其他逻辑返回）；
/// 3. 处理ANS记录更新：修复/更新本地ANS记录存储；
/// 设计目的：维护去中心化的地址映射关系（如易记名称→ID、手机号→ID）
class AnsCommandProcessor extends BaseCommandProcessor with Logging {
  /// 构造方法
  /// [facebook] - 账号系统核心实例（提供用户/群组基础信息）
  /// [messenger] - 消息收发核心实例（提供消息处理/发送能力）
  AnsCommandProcessor(super.facebook, super.messenger);

  /// 处理ANS命令的核心方法（覆盖父类抽象方法）
  /// 核心逻辑：判断命令类型（查询/更新）→ 执行对应处理 → 返回空列表（无需回复）
  /// [content] - 待处理的ANS命令内容（需转为AnsCommand类型）
  /// [rMsg] - 包含该命令的可靠消息（已验证签名，确保消息来源合法）
  /// 返回值：空列表（ANS命令无需回复，查询/更新结果通过其他方式反馈）
  @override
  Future<List<Content>> processContent(Content content,ReliableMessage rMsg) async {
    // 断言：开发阶段校验，确保传入的内容是ANSCommand类型，避免类型错误
    assert(content is AnsCommand, 'ans command error: $content');
    // 类型转换：转换为ANSCommand，获取专属方法/字段
    AnsCommand command = content as AnsCommand;
    // 获取ANS记录（key:易记名称/地址，value:对应的ID字符串）
    Map<String,String>? records = command.records;

    if(records == null){
      // 情况1：无records字段 → 表示查询ANS记录
      // 日志记录查询的名称列表，便于调试
      logInfo('ANS: querying ${content.names}');
    }else{
      // 情况2：有records字段 → 表示更新ANS记录
      // 修复/更新ANS记录到本地存储（ClientFacebook.ans是全局ANS管理器）
      // fix()方法：合并新记录到本地，返回更新的记录数量
      int count = await ClientFacebook.ans!.fix(records);
      // 日志记录更新结果，便于追踪数据变更
      logInfo('ANS: update $count record(s), $records');
    }
    return [];
  }
}

/// 登录命令处理器
/// 设计定位：处理用户登录命令，维护登录状态
/// 核心功能：
/// 1. 校验登录命令的合法性（发送者ID匹配）；
/// 2. 将登录命令持久化存储到会话数据库；
/// 3. 记录操作日志（成功/失败）；
/// 设计目的：
/// - 持久化登录状态，支持断线重连时恢复登录信息；
/// - 防止登录命令伪造，确保命令发送者与登录用户一致；
class LoginCommandProcessor extends BaseCommandProcessor with Logging {
  /// 构造方法（继承父类，传入核心依赖）
  LoginCommandProcessor(super.facebook, super.messenger);

  /// 类型转换：将基类Messenger转为客户端专属的ClientMessenger
  /// 目的：获取客户端Messenger的扩展能力（如session会话管理）
  @override
  ClientMessenger? get messenger => super.messenger as ClientMessenger?;

  /// 私有方法：获取会话数据库实例（从messenger的session中提取）
  /// 设计：通过getter封装数据库获取逻辑，便于后续扩展/替换
  // private（Dart通过命名规范模拟private访问修饰符）
  SessionDBI? get database => messenger?.session.database;

  /// 处理登录命令的核心方法（覆盖父类抽象方法）
  /// 核心逻辑：类型校验 → 合法性校验 → 持久化存储 → 日志记录 → 返回空列表
  @override
  Future<List<Content>> processContent(Content content,ReliableMessage rMsg) async {
    // 断言：确保传入的内容是LoginCommand类型，避免类型错误
    assert(content is LoginCommand, 'login command error: $content');
    // 类型转换：转为LoginCommand，获取登录用户ID等专属字段
    LoginCommand command = content as LoginCommand;
    // 获取登录用户ID（命令中声明的登录账号）
    ID sender = command.identifier;
    // 断言：防止登录命令伪造，确保命令中的用户ID与消息发送者ID一致
    assert(rMsg.sender == sender, 'sender not match: $sender, ${rMsg.sender}');

    // 将登录命令保存到会话数据库
    // 非空断言：数据库实例是核心依赖，必须存在（否则程序无法正常运行）
    SessionDBI db = database!;
    // 调用数据库方法保存登录命令（包含用户ID、命令内容、原始消息）
    if(await db.saveLoginCommandMessage(sender, command, rMsg)){
      // 保存成功 → 记录info级别日志，便于追踪用户登录状态
      logInfo('saved login command for user: $sender');
    }else{
      // 保存失败 → 记录error级别日志，便于排查存储问题
      logError('failed to save login command: $sender, $command');
    }
    // 无需回复登录命令（登录结果通过握手命令/状态通知反馈给客户端）
    return [];
  }
}

/// 回执命令处理器
/// 设计定位：处理消息回执命令（已读/送达/发送失败等状态通知）
/// 核心功能：
/// 1. 校验回执命令类型；
/// 2. 更新群组消息的响应时间（已读/送达时间）；
/// 设计目的：
/// - 维护消息状态，支持前端展示“已读”“送达”等状态；
/// - 同步群组消息的响应时间，确保多端状态一致；
class ReceiptCommandProcessor extends BaseCommandProcessor {
  /// 构造方法（继承父类，传入核心依赖）
  ReceiptCommandProcessor(super.facebook, super.messenger);

  /// 处理回执命令的核心方法（覆盖父类抽象方法）
  /// 核心逻辑：类型校验 → 更新群组消息响应时间 → 返回空列表
  @override
  Future<List<Content>> processContent(Content content,ReliableMessage rMsg) async {
    // 断言：确保传入的内容是ReceiptCommand类型，避免类型错误
    assert(content is ReceiptCommand, 'receipt command error: $content');
    // 类型判断：双重校验，确保类型安全
    if(content is ReceiptCommand){
      // 更新群组消息的响应时间（已读/送达时间）
      // SharedGroupManager()：全局群组共享管理器，维护群组消息状态
      // updateRespondTime()：根据回执更新消息的最后响应时间
      SharedGroupManager().delegate.updateRespondTime(content, rMsg.envelope);
    }
    // 无需回复回执命令（回执是消息状态的最终通知，无需再回复）
    return []; 
  }
}