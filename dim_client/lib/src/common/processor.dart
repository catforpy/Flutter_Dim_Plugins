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
import 'package:dim_client/src/common/checker.dart';
import 'package:dimsdk/dimsdk.dart';
import 'package:lnc/log.dart';


/// 通用消息处理器抽象类
/// 继承MessageProcessor，扩展消息内容处理逻辑，
/// 增加发送方文档时间检查，确保用户信息同步
abstract class CommonProcessor extends MessageProcessor with Logging {
  /// 构造方法
  /// [facebook] Facebook实例
  /// [messenger] 信使实例
  CommonProcessor(super.facebook, super.messenger);

  /// 获取实体检查器（从Facebook中获取）
  EntityChecker? get entityChecker {
    var facebook = this.facebook;
    if(facebook is CommonFacebook){
      // 从CommonFacebook中获取实体检查器
      return facebook.entityChecker;
    }
    assert(facebook == null, 'facebook error: $facebook');
    return null;
  }

  /// 创建内容处理器工厂（重写父类方法）
  /// [facebook] Facebook实例
  /// [messenger] 信使实例
  /// 返回：通用内容处理器工厂
  @override
  ContentProcessorFactory createFactory(Facebook facebook, Messenger messenger) {
    // 创建内容处理器创建器（由子类实现）
    var creator = createCreator(facebook, messenger);
    // 创建通用内容处理器工厂
    return GeneralContentProcessorFactory(creator);
  }

  /// 创建内容处理器创建器（需子类实现）
  // 受保护方法
  ContentProcessorCreator createCreator(Facebook facebook, Messenger messenger);

  // 私有方法：检查Visa时间（SDT）
  /// [content] 消息内容
  /// [rMsg] 可靠消息
  /// 返回：true=文档已更新，false=文档未更新
  Future<bool> checkVisaTime(Content content, ReliableMessage rMsg) async{
    var checker = entityChecker;
    if(checker == null){
      assert(false, 'should not happen');
      return false;
    }
    bool docUpdated = false;
    // 获取发送方文档时间（SDT）
    DateTime? lastDocumentTime = rMsg.getDateTime('SDT');
    if(lastDocumentTime != null){
      DateTime now = DateTime.now();
      // 校准时钟：如果文档时间在未来，使用当前时间
      if(lastDocumentTime.isAfter(now)){
        lastDocumentTime = now;
      }
      ID sender = rMsg.sender;
      // 更新最后文档时间
      docUpdated = checker.setLastDocumentTime(lastDocumentTime, sender);
      // 检查是否需要更新文档
      if(docUpdated){
        logInfo('checking for new visa: $sender');
        // 主动获取发送方的文档（触发检查逻辑）
        await facebook?.getDocuments(sender);
      }
    }
    return docUpdated;
  }

  /// 处理消息内容（重写父类方法）
  /// [content] 消息内容
  /// [rMsg] 可靠消息
  /// 返回：响应内容列表
  @override
  Future<List<Content>> processContent(Content content, ReliableMessage rMsg) async{
    // 调用父类方法处理内容
    List<Content> response = await super.processContent(content, rMsg);
    // 检查消息中的发送方文档时间
    await checkVisaTime(content, rMsg);
    return response;
  }
}