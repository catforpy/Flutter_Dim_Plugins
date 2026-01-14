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

// import 'package:get/get.dart';

import 'package:dim_client/ok.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/common.dart';
import 'package:dim_flutter/src/dim_ui.dart';

import 'chat.dart';
import 'chat_group.dart';
import 'msg_tmpl.dart';

/// 消息构建器抽象类：负责将消息内容转换为可读文本
/// 混入 Logging 用于日志输出，子类需实现 getName 方法获取ID对应的名称
abstract class MessageBuilder with Logging {

  // 保护方法：由子类实现，根据ID获取对应的名称（联系人/群名称）
  String getName(ID identifier);

  // 保护方法：将ID集合转换为名称字符串（逗号分隔）
  String getNames(Iterable<ID> members){
    List<String> names = [];
    for(var item in members){
      names.add(getName(item));
    }
    return names.join(', ');
  } 

  /// 检查消息内容是否应该隐藏（不显示在聊天列表/界面）
  /// [content] 消息内容
  /// [sender] 发送者ID
  /// 返回是否隐藏
  bool isHiddenContent(Content content, ID sender) {
    if(
      content is InviteCommand ||  // 邀请命令
        content is ExpelCommand ||   // 踢出命令
        content is JoinCommand ||    // 加入命令
        content is QuitCommand) {    // 退出命令
    // 检查群成员身份（飞群成员则隐藏群命令）
    ID? group = content.group;
    if(group == null){
      assert(false, 'group command error: $content');
      return false;
    }
    var chat = GroupInfo.fromID(group);
    if (chat == null) {
        assert(false, 'group not found: $group');
        return false;
      }
      return !chat.isMember;
    }
    // 命令类消息也需要隐藏
    return isCommand(content, sender);
  }

  /// 检查消息内容是否是命令类型
  /// [content] 消息内容
  /// [sender] 发送者ID
  /// 返回是否为命令
  bool isCommand(Content content, ID sender) {
    // 包含command字段则为命令
    if(content.containsKey('command')){
      return true;
    }
    // 检查文本内容是否是系统回执
    String? text = content['text'];
    if(text != null){
      // 检查文本回执关键词
      if(_checkText(text, [
        'Document not accept',
        'Document not change',
        'Document receive',
        'Failed to decrypt message',
      ])){
        return true;
      }
    }
    // TODO: 其他命令场景？
    // 直接判断是否是Command类型
    return content is Command;
  }

  /// 检查文本是否以指定前缀开头
  /// [text] 待检查文本
  /// [array] 前缀列表
  /// 返回是否匹配
  bool _checkText(String text,List<String> array){
    for(String prefix in array){
      if(text.startsWith(prefix)){
        return true;
      }
    }
    return false;
  }

  /// 获取消息的可读文本（核心方法）
  /// [content] 消息内容
  /// [sender] 发送者ID
  /// 返回格式化后的文本
  String getText(Content content, ID sender) {
    try{
      // 优先处理模板消息
      var template = content['template'];             // 通常为key 
      var replacements = content['replacements'];     // 通常为Map的键值对
      if(template is String && replacements is Map){
        return _getTempText(template, replacements);
      }
      // 处理命令消息
      if(content is Command){
        return _getCommandText(content,sender);
      }
      // 处理普通内容消息
      return _getContentText(content);
    }catch (e, st) {
      logError('content error: $e, $content, $st');
      return e.toString();
    }
  }

  /// 处理模板消息文本（替换模板中的变量）
  /// [template] 模板字符串
  /// [replacements] 替换变量Map
  /// 返回替换后的文本
  String _getTempText(String template, Map replacements) {
    logInfo('template: $template');
    replacements.forEach((key, value) {
      // 将ID类变量替换为对应的名称
      if(key == 'ID' || key == 'did' ||
         key == 'sender' || key == 'receiver' ||
        key == 'group' || key == 'gid'){
        ID? identifier = ID.parse(value);
        if(identifier != null){
          value = getName(identifier);
        }
      }
      // 替换模板变量中的变量
      template = MessageTemplate.replaceTemplate(template, key: key, value: value);
    });
    return template;
  }

  /// 处理普通内容消息的文本格式化
  /// [content] 消息内容
  /// 返回格式化后的文本
  String _getContentText(Content content) {
    // 优先使用已缓存的text字段
    String? text = content['text'];
    if(text != null){
      return text;
    }
    // 按内容类型格式化
    if(content is TextContent){
      // 文本内容
      text = content.text;
    }else if(content is FileContent){
      // 文件内容（图片/音频/视频/普通文件）
      if(content is ImageContent){
        text = '[Image:${content.filename}]';
      }else if (content is AudioContent) {
        text = '[Voice:${content.filename}]';
      } else if (content is VideoContent) {
        text = '[Movie:${content.filename}]';
      } else {
        text = '[File:${content.filename}]';
      }
    }else if (content is PageContent) {
      // 网页内容
      text = '[URL:${content.title}]';
    } else if (content is NameCard) {
      // 名片内容
      text = '[NameCard:${content.name}]';
    } else if (content is CustomizedContent) {
      // 自定义内容
      var app = content.application;
      var mod = content.module;
      var act = content.action;
      text = '[Customized:app=$app,mod=$mod,act=$act]';
      // if (content['format'] == null) {
      //   text = '## Customized Content\n'
      //       '* app = "$app"\n'
      //       '* mod = "$mod"\n'
      //       '* act = "$act"\n';
      //   content['format'] = 'markdown';
      // }
    } else {
      // 不支持的消息类型
      text = "Current version doesn't support this message type: ${content.type}.";
    }
    // 缓存格式化后的文本到content中
    content['text'] = text;
    return text;
  }

  /// 处理命令消息的文本格式化
  /// [content] 命令内容
  /// [sender] 发送者ID
  /// 返回格式化后的文本
  String _getCommandText(Command content, ID sender) {
    // 优先使用已缓存的text字段
    String? text = content['text'];
    if (text != null) {
      return text;
    }
    // 按命令类型格式化
    if (content is GroupCommand) {
      // 群命令
      text = _getGroupCommandText(content, sender);
    // } else if (content is HistoryCommand) {
    //   // TODO: process history command
    } else if (content is LoginCommand) {
      // 登录命令
      text = _getLoginCommandText(content, sender);
    } else {
      // 不支持的命令类型
      text = "Current version doesn't support this command: ${content.cmd}.";
    }
    // 缓存格式化后的文本到content中
    content['text'] = text;
    return text;
  }

  //-------- 系统命令处理

  /// 处理登录命令文本格式化
  /// [content] 登录命令
  /// [sender] 发送者ID
  /// 返回格式化后的文本
  String _getLoginCommandText(LoginCommand content, ID sender) {
    ID identifier = content.identifier;
    String name = getName(identifier);
    var station = content.station;
    return '$name login: $station';
  }

  //...

  //-------- 群命令处理

  /// 处理群命令文本格式化
  /// [content] 群命令
  /// [sender] 发送者ID
  /// 返回格式化后的文本
  String _getGroupCommandText(GroupCommand content, ID sender) {
    if (content is ResetCommand) {
      return _getResetCommandText(content, sender);
    } else if (content is InviteCommand) {
      return _getInviteCommandText(content, sender);
    } else if (content is ExpelCommand) {
      return _getExpelCommandText(content, sender);
    } else if (content is JoinCommand) {
      return _getJoinCommandText(content, sender);
    } else if (content is QuitCommand) {
      return _getQuitCommandText(content, sender);
    }
    // 不支持的群命令
    return i18nTranslator.translate('Unsupported group command: @cmd',
      params: {
        'cmd': content.cmd,
      });
  }

  /// 处理重置群命令文本格式化
  /// [content] 重置群命令
  /// [sender] 发送者ID
  /// 返回格式化后的文本
  String _getResetCommandText(ResetCommand content, ID sender) {
    String commander = getName(sender);
    return i18nTranslator.translate('"@commander" reset group',
      params: {
        'commander': commander,
      });
  }

  /// 处理加入群命令文本格式化
  /// [content] 加入群命令
  /// [sender] 发送者ID
  /// 返回格式化后的文本
  String _getJoinCommandText(JoinCommand content, ID sender) {
    String commander = getName(sender);
    return i18nTranslator.translate('"@commander" join group',
      params: {
        'commander': commander,
      });
  }

  /// 处理退出群命令文本格式化
  /// [content] 退出群命令
  /// [sender] 发送者ID
  /// 返回格式化后的文本
  String _getQuitCommandText(QuitCommand content, ID sender) {
    String commander = getName(sender);
    return i18nTranslator.translate('"@commander" left group',
      params: {
        'commander': commander,
      });
  }

  /// 处理邀请群命令文本格式化
  /// [content] 邀请群命令
  /// [sender] 发送者ID
  /// 返回格式化后的文本
  String _getInviteCommandText(InviteCommand content, ID sender) {
    String commander = getName(sender);
    var someone = content.member;
    var members = content.members;
    if (members == null || members.isEmpty) {
      assert(someone != null, 'failed to get group member: $content');
      members = null;
    } else if (members.length == 1) {
      someone = members[0];
      members = null;
    } else {
      assert(someone == null, 'group member error: $content');
      someone = null;
    }
    if (members != null) {
      return i18nTranslator.translate('"@commander" invite "@members"',
        params: {
          'commander': commander,
          'members': getNames(members),
        });
    } else if (someone != null) {
      return i18nTranslator.translate('"@commander" invite "@member"',
        params: {
          'commander': commander,
          'member': getName(someone),
        });
    } else {
      assert(false, 'should not happen: $content');
      return i18nTranslator.translate('Invite command error');
    }
  }

  /// 处理踢出群命令文本格式化
  /// [content] 踢出群命令
  /// [sender] 发送者ID
  /// 返回格式化后的文本
  String _getExpelCommandText(ExpelCommand content, ID sender) {
    String commander = getName(sender);
    var someone = content.member;
    var members = content.members;
    if (members == null || members.isEmpty) {
      assert(someone != null, 'failed to get group member: $content');
      members = null;
    } else if (members.length == 1) {
      someone = members[0];
      members = null;
    } else {
      assert(someone == null, 'group member error: $content');
      someone = null;
    }
    if (members != null) {
      return i18nTranslator.translate('"@commander" expel "@members"',
        params: {
          'commander': commander,
          'members': getNames(members),
        });
    } else if (someone != null) {
      return i18nTranslator.translate('"@commander" expel "@member"',
        params: {
          'commander': commander,
          'member': getName(someone),
        });
    } else {
      assert(false, 'should not happen: $content');
      return i18nTranslator.translate('Expel command error');
    }
  }
}

/// 默认消息构建器（单例）：实现getName方法，从会话中获取名称
class DefaultMessageBuilder extends MessageBuilder {
  factory DefaultMessageBuilder() => _instance;
  static final DefaultMessageBuilder _instance = DefaultMessageBuilder._internal();
  DefaultMessageBuilder._internal();

  @override
  String getName(ID identifier) {
    // 从ID创建会话实例，获取名称
    Conversation? chat = Conversation.fromID(identifier);
    if (chat == null) {
      logWarning('failed to get conversation: $identifier');
      // 会话不存在则返回匿名名称
      return Anonymous.getName(identifier);
    }
    return chat.name;
  }

}
