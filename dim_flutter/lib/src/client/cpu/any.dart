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

import 'dart:io';

import 'package:dim_client/sdk.dart';    // DIM-SDK核心库（消息/内容/处理器）
import 'package:dim_client/group.dart';  // DIM-SDK群组相关库

/// 通用内容处理器：处理所有未被特殊处理器接管的消息类型
/// 核心功能：
/// 1. 识别不同类型的消息（文本/图片/音频/视频/文件等）
/// 2. 生成统一的已读回执文本
/// 3. 群组消息交由群机器人处理，避免重复回执
class AnyContentProcessor extends BaseContentProcessor {
  /// 构造方法：初始化处理器，传入Facebook（身份管理）和Messenger（消息发送器）
  AnyContentProcessor(super.facebook, super.messenger);

   /// 核心处理方法：解析消息类型，生成回执
  /// [content] - 待处理的消息内容
  /// [rMsg] - 可靠消息对象（包含发送者/信封等元信息）
  /// 返回：回执消息列表（空列表表示无需回执）
  @override
  Future<List<Content>> processContent(Content content,ReliableMessage rMsg) async {
    String text;    // 回执文本

    // ===================== 第一步：识别消息类型，生成对应回执文本 =====================
    // 1. 文件类消息（图片/音频/视频/其他文件）
    if(content is FileContent){
      if(content is ImageContent){
        text = "Image received";            // 图片消息
      }else if(content is AudioContent){
        text = "Voice message received";    // 音频信息
      }else if(content is VideoContent){
        text = "Movie received";            // 视频消息
      }else{
        text = "File received";             // 其他文件消息
      }
    }
    // 2. 文本消息
    else if(content is TextContent){
      text = "Text message received";
    }
    // 3. 网页消息
    else if(content is PageContent){
      text = "Web page received";
    }
    // 4.名片消息
    else if(content is NameCard){
      text = "Name card received";
    }
    // 5.引用消息（回复/引用其他消息）
    else if(content is QuoteContent){
      text = "Quote message received";
    }
    // 6. 金钱相关消息（收款/分账/红包/转账）
    else if (content is MoneyContent) {
      if (content.type == ContentType.CLAIM_PAYMENT) {
        text = "Claim payment received"; // 收款消息
      } else if (content.type == ContentType.SPLIT_BILL) {
        text = "Split bill received";     // 分账消息
      } else if (content.type == ContentType.LUCKY_MONEY) {
        text = "Lucky money received";    // 红包消息
      } else if (content is TransferContent) {
        text = "Transfer money message received"; // 转账消息
      } else {
        text = "Unrecognized money message"; // 未知金钱消息
      }
    }
    // 7. 其他未识别消息：交给父类处理
    else {
      return await super.processContent(content, rMsg);
    }

    // ===================== 第二步：群组消息特殊处理 =====================
    var group = content.group; // 获取消息所属群组ID
    if (group != null && rMsg.containsKey('group')) {
      // 群组ID公开的场景：
      // - 正常由群机器人转发消息
      // - 机器人会在消息送达后回复发送者，因此这里无需重复回执
      SharedGroupManager man = SharedGroupManager();
      List<ID> bots = await man.getAssistants(group); // 获取群机器人列表
      if (bots.isNotEmpty) {
        return []; // 交由群机器人处理，返回空列表（无需回执）
      }
    }

    // ===================== 第三步：生成并返回回执消息 =====================
    return respondReceipt(text, content: content, envelope: rMsg.envelope);
  }
}