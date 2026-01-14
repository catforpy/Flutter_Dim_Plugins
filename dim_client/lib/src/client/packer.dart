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

import 'package:dimsdk/dimsdk.dart';

import '../common/facebook.dart';
import '../common/packer.dart';

/// 客户端消息打包器
/// 核心功能：处理群组消息的打包/解包，检查群组数据完整性
abstract class ClientMessagePacker extends CommonPacker {
  /// 构造方法
  ClientMessagePacker(super.facebook, super.messenger);

  /// 获取Facebook实例（强制类型转换）
  @override
  CommonFacebook? get facebook => super.facebook as CommonFacebook?;

  // 受保护方法：获取群组成员
  Future<List<ID>> getMembers(ID group) async =>
      await facebook!.getMembers(group);

  /// 检查接收者是否就绪（重载以处理群组）
  @override
  Future<bool> checkReceiver(InstantMessage iMsg) async {
    ID receiver = iMsg.receiver;
    if(receiver.isBroadcast){
      // 广播消息直接通过
      return true;
    }else if (receiver.isUser) {
      // 个人消息检查用户Meta/Document
      return await super.checkReceiver(iMsg);
    }
    //
    //  处理群组接收者
    //
    // 获取群组成员
    List<ID> members = await getMembers(receiver);
    if(members.isEmpty){
      // 群组未就绪，挂起消息
      Map<String,String> error = {
        'message': 'group members not found',
        'group': receiver.toString(),
      };
      suspendInstantMessage(iMsg, error);
      return false;
    }
    //
    //  检查群成员的Visa密钥
    //
    List<ID> waiting = [];
    for(ID item in members){
      if(await getVisaKey(item) == null){
        // 成员未就绪
        waiting.add(item);
      }
    }
    if(waiting.isEmpty){
      // 所有成员密钥就绪
      return true;
    }
    // 部分成员未就绪，挂起消息
    Map<String,Object> error = {
      'message': 'members not ready',
      'group': receiver.toString(),
      'members': ID.revert(waiting),
    };
    suspendInstantMessage(iMsg, error);
    // 返回true以继续流程（部分成员就绪即可发送）
    return waiting.length < members.length;
  }

  // 受保护方法：检查群组是否就绪
  Future<bool> checkGroup(ReliableMessage sMsg) async {
    ID receiver = sMsg.receiver;
    // 获取群组ID
    ID? group = ID.parse(sMsg['group']);
    if(group == null && receiver.isGroup){
      // 接收者为群组时自动填充
      group = receiver;
    }
    if(group == null || group.isBroadcast){
      // 无群组/广播群组直接通过
      return true;
    }
    //
    //  处理群组消息
    //
    List<ID> members = await getMembers(group);
    if(members.isNotEmpty){
      // 群组就绪
      return true;
    }
    // 群组未就绪，挂起消息
    Map<String,String> error = {
      'message': 'group not ready',
      'group': group.toString(),
    };
    suspendReliableMessage(sMsg, error);
    return false;
  }

  /// 验证可靠消息（重载以检查群组）
  @override
  Future<SecureMessage?> verifyMessage(ReliableMessage rMsg) async {
    // 检查群组是否就绪
    if(await checkGroup(rMsg)){
      // 群组就绪，继续验证
    }else{
      logWarning('receiver not ready: ${rMsg.receiver}');
      return null;
    }
    return await super.verifyMessage(rMsg);
  }

  /// 解密安全消息（重载以处理文件内容）
  @override
  Future<InstantMessage?> decryptMessage(SecureMessage sMsg) async {
    InstantMessage? iMsg;
    try{
      // 调用父类解密
      iMsg = await super.decryptMessage(sMsg);
    }catch(e,st){
      String errMsg = e.toString();
      if (errMsg.contains('failed to decrypt message key')) {
        // 解密消息密钥失败（Visa密钥变更）
        logWarning('decrypt message error: $e, $st');
        // 向发送者推送最新Visa
      } else if (errMsg.contains('receiver error')) {
        // 接收者错误（非目标消息）
        logError('decrypt message error: $e, $st');
        return null;
      } else {
        // 其他错误重新抛出
        rethrow;
      }
    }
    if(iMsg == null){
      // 解密失败，推送最新Visa
      await pushVisa(sMsg.sender);
    }else{
      // 处理文件内容
      Content content = iMsg.content;
      if(content is FileContent){
        if(content.password == null && content.url != null){
          // 远程文件内容，保存解密密钥
          SymmetricKey? key = await messenger?.getDecryptKey(sMsg);
          assert(key != null, 'failed to get msg key: '
              '${sMsg.sender} => ${sMsg.receiver}, ${sMsg['group']}');
          // 保存密钥用于后续下载解密
          content.password = key;
        }
      }
    }
    return iMsg;
  }

  // 受保护方法：向联系人推送Visa文档
  Future<bool> pushVisa(ID contact) async {
    // 获取当前用户
    User? user = await facebook?.currentUser;
    if (user == null) {
      assert(false, 'failed to get current user');
      return false;
    }
    // 获取当前用户Visa
    Visa? visa = await user.visa;
    if (visa == null || !visa.isValid) {
      throw Exception('user visa error: $user');
    }
    // 获取实体检查器
    var checker = facebook?.entityChecker;
    if (checker == null) {
      assert(false, 'failed to get entity checker');
      return false;
    }
    // 发送Visa文档
    return await checker.sendVisa(visa, contact);
  }

  // 受保护方法：构建解密失败的提示消息
  Future<InstantMessage?> getFailedMessage(SecureMessage sMsg) async {
    ID sender = sMsg.sender;
    ID? group = sMsg.group;
    String? type = sMsg.type;
    // 忽略命令/历史消息的解密失败
    if (type == ContentType.COMMAND || type == ContentType.HISTORY) {
      logWarning('ignore message unable to decrypt (type=$type) from "$sender"');
      return null;
    }
    // 创建失败提示文本
    Content content = TextContent.create('Failed to decrypt message.');
    content.addAll({
      'template': 'Failed to decrypt message (type=\${type}) from "\${sender}".',
      'replacements': {
        'type': type,
        'sender': sender.toString(),
        'group': group?.toString(),
      }
    });
    // 设置群组ID
    if (group != null) {
      content.group = group;
    }
    // 构建即时消息
    Map info = sMsg.copyMap(false);
    info.remove('data');
    info['content'] = content.toMap();
    return InstantMessage.parse(info);
  }
}