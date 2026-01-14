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

import 'package:dim_client/sdk.dart';    // DIM-SDK核心库
import 'package:dim_client/client.dart'; // DIM-SDK客户端基类

import '../models/vestibule.dart'; // 消息暂存模型

/// 共享消息打包器：继承ClientMessagePacker，扩展消息暂存逻辑
/// 核心扩展：
/// 1. 消息打包失败时自动暂存消息（标记错误信息）
class SharedPacker extends ClientMessagePacker {
  /// 构造方法：初始化消息打包器
  /// [facebook] - 身份管理核心
  /// [messenger] - 消息收发器
  SharedPacker(super.facebook, super.messenger);

  // 注释掉的代码：文件消息加密前校验（确保文件已上传）
  // @override
  // Future<SecureMessage?> encryptMessage(InstantMessage iMsg) async {
  //   // make sure visa.key exists before encrypting message
  //
  //   //
  //   //  Check FileContent
  //   //  ~~~~~~~~~~~~~~~~~
  //   //  You must upload file data before packing message.
  //   //
  //   Content content = iMsg.content;
  //   if (content is FileContent && content.data != null) {
  //     ID sender = iMsg.sender;
  //     ID receiver = iMsg.receiver;
  //     ID? group = iMsg.group;
  //     var error = 'You should upload file data before calling '
  //         'sendInstantMessage: $sender -> $receiver ($group)';
  //     logError(error);
  //     assert(false, error);
  //     return null;
  //   }
  //
  //   // the intermediate node(s) can only get the message's signature,
  //   // but cannot know the 'sn' because it cannot decrypt the content,
  //   // this is usually not a problem;
  //   // but sometimes we want to respond a receipt with original sn,
  //   // so I suggest to expose 'sn' here.
  //   iMsg['sn'] = content.sn;
  //
  //   // check receiver & encrypt
  //   return await super.encryptMessage(iMsg);
  // }

  // ===================== 消息暂存增强 =====================
  /// 暂存即时消息（重写父类）
  /// 扩展：标记错误信息并暂存到Vestibule
  @override
  Future<void> suspendInstantMessage(InstantMessage iMsg,Map info) async {
    // 标记消息错误信息
    iMsg['error'] = info;
    // 暂存消息
    Vestibule clerk = Vestibule();
    clerk.suspendInstantMessage(iMsg);
  }

  /// 暂存可靠消息（重写父类）
  /// 扩展：标记错误信息并暂存到Vestibule
  @override
  Future<void> suspendReliableMessage(ReliableMessage rMsg,Map info) async {
    // 标记消息错误信息
    rMsg['error'] = info;
    // 暂存消息
    Vestibule clerk = Vestibule();
    clerk.suspendReliableMessage(rMsg);
  }
}