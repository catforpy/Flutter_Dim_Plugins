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

import 'package:dim_client/ok.dart'; // DIM客户端基础库
import 'package:dim_client/sdk.dart'; // DIM客户端SDK

import '../client/shared.dart'; // 客户端全局变量
import '../common/constants.dart'; // 应用常量
import '../models/config.dart'; // 应用配置模型
import 'language.dart'; // 多语言管理

/*
        翻译内容数据结构 : {
            type : 0xCC,          // 自定义内容类型
            sn   : 123,           // 消息序列号

            app   : "chat.dim.translate",  // 应用标识
            mod   : "translate",           // 模块名称
            act   : "request",             // 操作类型（request/respond）

            tag   : 123,          // 源消息序列号

            text   : "{TEXT}",    // 源文本（request）/ 翻译文本（respond）
            code   : "{LANG_CODE}", // 目标语言编码
            result : {            // 翻译结果
                from        : "{SOURCE_LANGUAGE}", // 源语言
                to          : "{TARGET_LANGUAGE}", // 目标语言
                code        : "{LANG_CODE}",       // 目标语言编码
                text        : "{TEXT}",            // 源文本
                translation : "{TRANSLATION}"      // 翻译文本
            }
        }
 */

/// 翻译结果模型 - 解析翻译响应中的result字段
class TranslateResult extends Dictionary {
  TranslateResult(super.dict); // 继承Dictionary，接收Map数据

  /// 源语言名称
  String? get from => getString('from');

  /// 目标语言名称
  String? get to => getString('to');

  /// 目标语言编码
  String? get code => getString('code');

  /// 源文本
  String? get text => getString('text');

  /// 翻译后的文本
  String? get translation => getString('translation');

  /// 检查翻译结果是否有效
  bool get valid {
    if (from == null || to == null || code == null) {
      // 语言信息不完整，无效
      return false;
    }
    // 兼容处理：AI服务器可能将翻译结果放在text字段
    return translation != null || text != null;
  }
}

/// 翻译内容模型 - 继承自DIM自定义内容，封装翻译请求/响应
class TranslateContent extends AppCustomizedContent {
  TranslateContent(super.dict); // 接收Map数据初始化

  /// 源消息序列号（关联翻译请求和源消息）
  int? get tag => getInt('tag');

  /// 源文本/翻译文本
  String? get text => getString('text');

  /// 目标语言编码（优先从result中获取，否则取顶层code）
  String? get code => result?.code ?? getString('code');

  /// 翻译结果
  TranslateResult? get result {
    Map? info = this['result'];
    return info == null ? null : TranslateResult(info);
  }

  /// 检查翻译是否成功（结果有效）
  bool get success => result?.valid == true;

  /// 是否折叠翻译结果（UI显示控制）
  bool get folded => getBool('folded') ?? false;
  set folded(bool hidden) => this['folded'] = hidden;

  /// 构建翻译请求内容
  /// [text] 源文本 [tag] 源消息序列号 [format] 文本格式
  TranslateContent.query(String text, int tag, {required String? format})
      : super.from(app: Translator.app, mod: Translator.mod, act: 'request') {
    // 设置源文本
    this['text'] = text;
    // 设置源消息序列号（关联翻译请求和源消息）
    if (tag > 0) {
      this['tag'] = tag;
    }
    this['format'] = format;
    this['muted'] = true; // 静音（不提示）
    this['hidden'] = true; // 隐藏（不显示在聊天列表）
    this['code'] = _currentLanguageCode(); // 设置目标语言编码
  }
}

/// 获取当前应用的语言编码 - 优先从语言设置，否则从终端配置
String _currentLanguageCode() {
  // String code = LanguageDataSource().getCurrentLanguageCode();
  String code = languageManager.getCurrentLanguageCode();
  if (code.isEmpty) {
    GlobalVariable shared = GlobalVariable();
    code = shared.terminal.language;
  }
  return code;
}

/// 翻译器管理器 - 单例模式，混合Logging（日志）和Observer（观察者）
class Translator with Logging implements Observer {
  // 单例实现
  factory Translator() => _instance;
  static final Translator _instance = Translator._internal();
  Translator._internal() {
    // 注册通知监听：翻译器警告（用于发现最快的翻译机器人）
    var nc = NotificationCenter();
    nc.addObserver(this, NotificationNames.kTranslatorWarning);
  }

  /// 翻译应用标识
  static const String app = 'chat.dim.translate';
  /// 翻译模块名称
  static const String mod = 'translate';

  /// 翻译缓存：语言编码 -> 源文本 -> 翻译内容
  final Map<String, Map<String, TranslateContent>> _textCache = {};
  /// 翻译缓存：语言编码 -> 源消息序列号 -> 翻译内容
  final Map<String, Map<int, TranslateContent>> _tagCache = {};

  /// 最快响应的翻译机器人ID
  ID? _fastestTranslator;
  /// 翻译器警告消息（用于验证翻译机器人）
  String? _warningMessage;
  /// 最后一次查询翻译机器人的时间（用于限流）
  DateTime? _lastQueryTime;
  /// 查询间隔（秒）- 初始32秒，每次翻倍，最大500秒
  int _queryInterval = 32;

  /// 获取翻译器警告消息
  String? get warning => _warningMessage;

  /// 翻译器是否就绪（已找到最快的翻译机器人）
  bool get ready => _fastestTranslator != null;

  /// 检查内容是否可翻译（仅支持文本消息）
  bool canTranslate(Content content) => content is TextContent;

  /// 观察者回调：接收通知（主要处理翻译器警告）
  @override
  Future<void> onReceiveNotification(Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kTranslatorWarning) {
      // 处理翻译器警告通知
      ID? sender = userInfo?['sender']; // 发送者（翻译机器人ID）
      TranslateContent? content = userInfo?['content']; // 翻译内容
      TranslateResult? result = content?.result; // 翻译结果
      if (sender == null) {
        logError('translator error: $userInfo'); // 日志：发送者为空
      } else {
        var text = result?.translation;
        text ??= result?.text; // 兼容：翻译结果可能在text字段
        _updateTranslator(sender, text); // 更新最快翻译机器人
      }
    }
  }

  /// 更新最快的翻译机器人
  void _updateTranslator(ID sender, String? text) {
    var fastest = _fastestTranslator;
    if (fastest == null) {
      // 首次发现翻译机器人
      fastest = sender;
    } else if (text == null) {
      // 翻译文本为空，记录警告
      logWarning('warning text not found: $sender');
      return;
    } else if (fastest != sender) {
      // 已有最快翻译机器人，忽略其他
      logWarning('fastest translator exists: $fastest, $sender');
      return;
    }
    // 记录日志：更新最快翻译机器人
    logInfo('update fastest translator: $fastest, "$text"');
    _fastestTranslator = fastest;
    _warningMessage = text;
    // 发送通知：翻译器就绪
    var nc = NotificationCenter();
    nc.postNotification(NotificationNames.kTranslatorReady, this, {
      'translator': fastest,
    });
  }

  /// 测试翻译机器人候选列表 - 发送测试消息，发现最快的翻译机器人
  Future<bool> testCandidates() async {
    Config config = Config();
    var bots = config.translators; // 获取配置中的翻译机器人列表
    if (bots.isEmpty) {
      // 无翻译机器人配置
      return false;
    } else if (_fastestTranslator != null) {
      // 已有最快翻译机器人（TODO: 处理警告消息为空的情况）
      return true;
    }
    // 限流检查：最后一次查询时间
    var now = DateTime.now();
    var last = _lastQueryTime;
    if (last != null && now.subtract(Duration(seconds: _queryInterval)).isBefore(last)) {
      // 未到查询间隔，拒绝请求
      logWarning('last query is not expired, call it after $_queryInterval seconds.');
      return false;
    } else {
      // 更新最后查询时间，翻倍查询间隔（最大500秒）
      _lastQueryTime = now;
      if (_queryInterval < 500) {
        _queryInterval <<= 1; // 左移一位 = 乘以2
      }
    }
    // 构建测试翻译请求
    var content = TranslateContent.query('Hi there!', 0, format: null);
    content['mod'] = 'test'; // 标记为测试请求
    logInfo('say hi to translators: $bots, $content'); // 日志：发送测试消息
    GlobalVariable shared = GlobalVariable();
    // 向所有翻译机器人发送测试消息
    for (ID receiver in bots) {
      await shared.emitter.sendContent(content, receiver: receiver);
    }
    return true;
  }

  /// 发送翻译请求 - 向最快的翻译机器人发送翻译请求
  Future<bool> request(String text, int tag, {required String? format}) async {
    ID? receiver = _fastestTranslator;
    if (receiver == null) {
      // 无翻译机器人，记录警告
      logWarning('translator not found');
      return false;
    }
    // 构建翻译请求
    var content = TranslateContent.query(text, tag, format: format);
    logInfo('sending to translator: $receiver, $content'); // 日志：发送翻译请求
    GlobalVariable shared = GlobalVariable();
    // 发送翻译请求给最快的翻译机器人
    await shared.emitter.sendContent(content, receiver: receiver);
    return true;
  }

  /// 从缓存获取翻译内容 - 优先按文本，再按消息序列号
  TranslateContent? fetch(String text, int tag) {
    String code = _currentLanguageCode();
    return _textCache[code]?[text] ?? _tagCache[code]?[tag];
  }

  /// 更新翻译缓存 - 按文本和消息序列号缓存
  bool update(TranslateContent content) {
    String? code = content.code;
    if (code == null || code.isEmpty) {
      // 语言编码为空，断言失败
      assert(false, 'translate content error: $content');
      return false;
    }
    bool ok1 = false, ok2 = false;
    // 按源文本缓存
    String? text = content.result?.text;
    if (text != null && text.isNotEmpty) {
      ok1 = _cacheText(content, text: text, code: code);
    }
    // 按源消息序列号缓存
    int? sn = content.tag;
    if (sn != null && sn > 0) {
      ok2 = _cacheTag(content, tag: sn, code: code);
    }
    // 任一缓存成功即返回true
    return ok1 || ok2;
  }

  /// 按源文本缓存翻译内容
  bool _cacheText(TranslateContent content, {required String text, required String code}) {
    Map<String, TranslateContent>? info = _textCache[code];
    if (info == null) {
      // 语言编码缓存不存在，创建新缓存
      _textCache[code] = {text: content};
      return true;
    } else if (content.success) {
      // 翻译成功，更新缓存
      info[text] = content;
      return true;
    }
    // 翻译未成功，检查旧缓存
    TranslateContent? old = info[text];
    if (old?.success == true) {
      // 旧缓存翻译成功，无需更新
      return false;
    }
    // 旧缓存也未成功，更新为临时记录
    info[text] = content;
    return true;
  }

  /// 按源消息序列号缓存翻译内容
  bool _cacheTag(TranslateContent content, {required int tag, required String code}) {
    Map<int, TranslateContent>? info = _tagCache[code];
    if (info == null) {
      // 语言编码缓存不存在，创建新缓存
      _tagCache[code] = {tag: content};
      return true;
    } else if (content.success) {
      // 翻译成功，更新缓存
      info[tag] = content;
      return true;
    }
    // 翻译未成功，检查旧缓存
    TranslateContent? old = info[tag];
    if (old?.success == true) {
      // 旧缓存翻译成功，无需更新
      return false;
    }
    // 旧缓存也未成功，更新为临时记录
    info[tag] = content;
    return true;
  }
}