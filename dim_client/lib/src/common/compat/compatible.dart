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

// TODO: 待所有服务器/客户端升级完成后移除
import 'package:dim_client/common.dart';
import 'package:dim_client/plugins.dart';
import 'package:dim_client/sdk.dart';

// TODO: 待所有服务器/客户端升级完成后移除
/// 基础数据兼容处理接口
abstract interface class Compatible {

  /// 修复消息中的Meta附件字段
  /// @param rMsg - 可靠消息对象
  static void fixMetaAttachment(ReliableMessage rMsg) {
    Map? meta = rMsg['meta'];
    if (meta != null) {
      fixMetaVersion(meta);
    }
  }

  /// 修复消息中的Visa文档附件字段
  /// @param rMsg - 可靠消息对象
  static void fixVisaAttachment(ReliableMessage rMsg) {
    Map? visa = rMsg['visa'];
    if (visa != null) {
      fixDocument(visa);
    }
  }

}

/// 修复Meta中的版本/类型字段映射（'type' <-> 'version'）
/// @param meta - Meta字典
void fixMetaVersion(Map meta) {
  dynamic type = meta['type'];
  if (type == null) {
    // 'type'不存在时从'version'复制
    type = meta['version'];
  } else if (type is String && !meta.containsKey('algorithm')) {
    // 兼容处理：字符串类型的type，长度>2时视为algorithm
    if (type.length > 2) {
      meta['algorithm'] = type;
    }
  }
  // 转换为数字版本号
  int version = MetaVersion.parseInt(type, 0);
  if (version > 0) {
    meta['type'] = version;
    meta['version'] = version;
  }
}

/// 修复文档中的ID字段映射（'ID' <-> 'did'）
/// @param document - 文档字典
/// @return 修复后的文档字典
Map fixDocument(Map document) {
  fixDid(document);
  return document;
}

/// 修复命令中的指令字段映射（'cmd' <-> 'command'）
/// @param content - 命令内容字典
void fixCmd(Map content) {
  String? cmd = content['command'];
  if (cmd == null) {
    // 'command'不存在时从'cmd'复制
    cmd = content['cmd'];
    if (cmd != null) {
      content['command'] = cmd;
    } else {
      assert(false, 'command error: $content');
    }
  } else if (content.containsKey('cmd')) {
    // 验证两个字段值是否一致
    assert(content['cmd'] == cmd, 'command error: $content');
  } else {
    // 'cmd'不存在时从'command'复制
    content['cmd'] = cmd;
  }
}

/// 修复ID字段映射（'ID' <-> 'did'）
/// @param content - 内容字典
void fixDid(Map content) {
  String? did = content['did'];
  if (did == null) {
    // 'did'不存在时从'ID'复制
    did = content['ID'];
    if (did != null) {
      content['did'] = did;
    }
  } else if (content.containsKey('ID')) {
    // 验证两个字段值是否一致
    assert(content['ID'] == did, 'did error: $content');
  } else {
    // 'ID'不存在时从'did'复制
    content['ID'] = did;
  }
}

/// 修复文件内容中的密码字段映射（'key' <-> 'password'）
/// @param content - 文件内容字典
void fixFileContent(Map content) {
  var pwd = content['key'];
  if (pwd != null) {
    // 兼容新版本：key -> password
    content['password'] = pwd;
  } else {
    // 兼容旧版本：password -> key
    pwd = content['password'];
    if (pwd != null) {
      content['key'] = pwd;
    }
  }
}

/// 文件类型常量列表（用于判断是否需要修复密码字段）
const fileTypes = [
  ContentType.FILE, 'file',
  ContentType.IMAGE, 'image',
  ContentType.AUDIO, 'audio',
  ContentType.VIDEO, 'video',
];

// TODO: 待所有服务器/客户端升级完成后移除
/// 入站消息内容兼容处理接口
abstract interface class CompatibleIncoming {

  /// 修复入站消息内容的兼容字段
  /// @param content - 消息内容字典
  static void fixContent(Map content) {
    // 获取内容类型
    String type = Converter.getString(content['type']) ?? '';

    // 文件类型内容：修复密码字段
    if (fileTypes.contains(type)) {
      fixFileContent(content);
      return;
    }

    // 名片类型内容：修复did字段
    if (ContentType.NAME_CARD == type || type == 'card') {
      fixDid(content);
      return;
    }

    // 命令类型内容：修复cmd字段
    if (ContentType.COMMAND == type || type == 'command') {
      fixCmd(content);
    }

    // 获取命令名称
    String? cmd = Converter.getString(content['command']);
    if (cmd == null || cmd.isEmpty) {
      return;
    }

    // 登录命令：修复did字段
    if (LoginCommand.LOGIN == cmd) {
      fixDid(content);
      return;
    }

    // 文档命令：修复命令名称和字段
    if (Command.DOCUMENTS == cmd || cmd == 'document') {
      _fixDocs(content);
    }

    // Meta/文档命令：修复did和meta版本
    if (Command.META == cmd || Command.DOCUMENTS == cmd || cmd == 'document') {
      fixDid(content);
      Map? meta = content['meta'];
      if (meta != null) {
        fixMetaVersion(meta);
      }
    }

  }

  /// 修复文档命令字段（'document' -> 'documents'）
  /// @param content - 命令内容字典
  static void _fixDocs(Map content) {
    // 命令名称：'document' -> 'documents'
    String? cmd = content['command'];
    if (cmd == 'document') {
      content['command'] = 'documents';
    }
    // 字段：'document' -> 'documents'
    Map? doc = content['document'];
    if (doc != null) {
      content['documents'] = [fixDocument(doc)];
      content.remove('document');
    }
  }

}

/// 将内容类型从字符串转换为数字
/// @param content - 内容字典
void fixType(Map content) {
  var type = content['type'];
  if (type is String) {
    int? number = Converter.getInt(type);
    if (number != null && number >= 0) {
      content['type'] = number;
    }
  }
}

// TODO: 待所有服务器/客户端升级完成后移除
/// 出站消息内容兼容处理接口
abstract interface class CompatibleOutgoing {

  /// 修复出站消息内容的兼容字段
  /// @param content - 消息内容对象
  static void fixContent(Content content) {
    // 修复内容类型（字符串转数字）
    fixType(content.toMap());

    // 文件内容：修复密码字段
    if (content is FileContent) {
      fixFileContent(content.toMap());
      return;
    }

    // 名片内容：修复did字段
    if (content is NameCard) {
      fixDid(content.toMap());
      return;
    }

    // 命令内容：修复cmd字段
    if (content is Command) {
      fixCmd(content.toMap());
    }

    // 回执命令：兼容v2.0版本
    if (content is ReceiptCommand) {
      fixReceiptCommand(content.toMap());
      return;
    }

    // 登录命令：修复did、station、provider字段
    if (content is LoginCommand) {
      fixDid(content.toMap());
      var station = content['station'];
      if (station is Map) {
        fixDid(station);
      }
      var provider = content['provider'];
      if (provider is Map) {
        fixDid(provider);
      }
      return;
    }

    // 文档命令：修复命令名称和字段
    if (content is DocumentCommand) {
      _fixDocs(content);
    }

    // Meta命令：修复did和meta版本
    if (content is MetaCommand) {
      fixDid(content.toMap());
      Map? meta = content['meta'];
      if (meta != null) {
        fixMetaVersion(meta);
      }
    }

  }

  /// 修复文档命令字段（'documents' -> 'document'）
  /// @param content - 文档命令对象
  static void _fixDocs(DocumentCommand content) {
    // 命令名称：'documents' -> 'document'
    String cmd = content.cmd;
    if (cmd == 'documents') {
      content['cmd'] = 'document';
      content['command'] = 'document';
    }
    // 字段：'documents' -> 'document'
    List? array = content['documents'];
    if (array != null) {
      List<Document> docs = Document.convert(array);
      Document? last = DocumentUtils.lastDocument(docs);
      if (last != null) {
        content['document'] = fixDocument(last.toMap());
      }
      if (docs.length == 1) {
        content.remove('documents');
      }
    }
    // 修复document字段的did
    Object? document = content['document'];
    if (document is Map) {
      fixDid(document);
    }
  }

}

/// 修复回执命令（兼容v2.0版本）
/// @param content - 回执命令字典
void fixReceiptCommand(Map content) {
  // TODO: 兼容v2.0版本的回执命令处理
}