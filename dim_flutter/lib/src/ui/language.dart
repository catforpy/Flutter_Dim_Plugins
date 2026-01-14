/* 
 * 版权声明：MIT协议
 * DIM-SDK : 去中心化即时通讯软件开发工具包
 * 作者：Moky (albert.moky@gmail.com)
 * 时间：2023
 * 
 * 功能说明：
 * 1. 基于GetX实现多语言管理核心逻辑
 * 2. 封装语言切换、持久化、Locale解析、翻译表加载等能力
 * 3. 采用接口隔离设计，支持未来无缝切换到BLoC等其他状态管理方案
 * 4. 支持多语言列表展示、系统默认语言适配、中文脚本（Hans/Hant）处理
 */

import 'dart:ui'; // Flutter底层UI库，提供Locale（语言地区）核心类

// 导入多语言核心接口（定义通用行为，隔离具体实现）
import 'package:dim_flutter/src/ui/language_interface.dart';
// 导入导航工具类（用于语言切换后刷新页面/重启App）
import 'package:dim_flutter/src/ui/nav.dart';
// 导入GetX框架（用于状态管理、Locale切换、翻译表管理）
import 'package:get/get.dart';

// 导入本地存储工具类（用于持久化语言编码）
import 'settings.dart';
// 导入各语言翻译表（key-value形式的文本映射）
import 'intl_af_za.dart';   // 南非荷兰语-南非 翻译表
import 'intl_ar_msa.dart';  // 阿拉伯语-现代标准阿拉伯语 翻译表
import 'intl_bn_bd.dart';   // 孟加拉语-孟加拉国 翻译表
import 'intl_de_de.dart';   // 德语-德国 翻译表
import 'intl_en_us.dart';   // 英语-美国 翻译表
import 'intl_es_es.dart';   // 西班牙语-西班牙 翻译表
import 'intl_fr_fr.dart';   // 法语-法国 翻译表
import 'intl_hi_in.dart';   // 印地语-北印度 翻译表
import 'intl_id_id.dart';   // 印尼语-印尼 翻译表
import 'intl_it_it.dart';   // 意大利语-意大利 翻译表
import 'intl_ja_jp.dart';   // 日语-日本 翻译表
import 'intl_ko_kr.dart';   // 韩语-韩国 翻译表
import 'intl_ms_my.dart';   // 马来语-马来西亚 翻译表
import 'intl_nl_nl.dart';   // 荷兰语-荷兰 翻译表
import 'intl_pt_pt.dart';   // 葡萄牙语-葡萄牙 翻译表
import 'intl_ru_ru.dart';   // 俄语-俄罗斯 翻译表
import 'intl_th_th.dart';   // 泰语-泰国 翻译表
import 'intl_tr_tr.dart';   // 土耳其语-土耳其 翻译表
import 'intl_vi_vn.dart';   // 越南语-越南 翻译表
import 'intl_zh_cn.dart';   // 简体中文 翻译表
import 'intl_zh_tw.dart';   // 繁体中文 翻译表

/// 语言项实体类 - 封装单条语言数据（编码/名称/描述）
/// 作用：用于UI展示语言列表、存储语言基础信息
class LanguageItem {
  /// 构造函数
  /// [code] 语言编码（符合ISO标准，如zh_CN、en_US、''表示系统默认）
  /// [name] 语言显示名称（用户可见，如"简体中文"、"English"）
  /// [desc] 语言描述（可选，用于排序/备注，如"Spanish"）
  LanguageItem(this.code, this.name, this.desc);

  final String code; // 语言编码（核心标识，如zh_CN、en_US）
  final String name; // 语言显示名称（UI展示用）
  final String? desc; // 语言描述（可选，用于排序/补充说明）
}

/// 多语言数据源核心类 - 实现LanguageManagerInterface接口
/// 设计模式：单例模式（保证全局唯一实例）
/// 核心能力：
/// 1. 语言配置初始化（关联本地存储）
/// 2. 语言切换+持久化
/// 3. Locale解析与修正（处理中文脚本等特殊场景）
/// 4. 语言列表数据管理
/// 5. GetX翻译表加载
class LanguageDataSource implements LanguageManagerInterface {
  // 单例实现 - 工厂构造函数（对外提供实例）
  factory LanguageDataSource() => _instance;
  // 私有静态实例（全局唯一）
  static final LanguageDataSource _instance = LanguageDataSource._internal();
  // 私有构造函数（禁止外部new）
  LanguageDataSource._internal();

  AppSettings? _settings; // 本地存储实例（用于持久化语言编码）

  /// 支持的语言列表（包含系统默认选项）
  /// 说明：
  /// 1. 第一个元素为系统默认语言（code为空字符串）
  /// 2. 元素顺序会通过desc字段排序（无desc则按添加顺序）
  /// 3. 每个元素的name为展示文本，code为核心标识
  final List<LanguageItem> _items = [
    LanguageItem('', 'System', null), // 系统默认语言（优先级最高）

    // 欧美语言
    LanguageItem('en_US', langEnglish, null),       // 英语（美国）
    LanguageItem('es_ES', langSpanish, 'Spanish'),  // 西班牙语（西班牙）
    LanguageItem('fr_FR', langFrench, 'French'),    // 法语（法国）
    LanguageItem('de_DE', langGerman, 'German'),    // 德语（德国）
    LanguageItem('it_IT', langItalian, 'Italian'),  // 意大利语（意大利）
    LanguageItem('nl_NL', langDutch, 'Dutch'),      // 荷兰语（荷兰）
    LanguageItem('pt_PT', langPortuguese, 'Portuguese'), // 葡萄牙语（葡萄牙）
    LanguageItem('ru_RU', langRussian, 'Russian'),  // 俄语（俄罗斯）
    LanguageItem('ar', langArabic, 'Arabic'),       // 阿拉伯语
    LanguageItem('af_ZA', langAfrikaans, 'Afrikaans'), // 南非荷兰语
    LanguageItem('tr_TR', langTurkish, 'Turkish'),  // 土耳其语（土耳其）

    // 亚洲语言
    LanguageItem('hi_IN', langHindi, 'Hindi'),      // 印地语（印度）
    LanguageItem('bn_BD', langBengali, 'Bengali'),  // 孟加拉语（孟加拉国）
    LanguageItem('ja_JP', langJapanese, 'Japanese'), // 日语（日本）
    LanguageItem('ko_KR', langKorean, 'Korean'),    // 韩语（韩国）
    LanguageItem('ms_MY', langMalaysian, 'Malay'),  // 马来语（马来西亚）
    LanguageItem('th_TH', langThai, 'Thai'),        // 泰语（泰国）
    LanguageItem('id_ID', langIndonesian, 'Indonesian'), // 印尼语（印尼）
    LanguageItem('vi_VN', langVietnamese, 'Vietnamese'), // 越南语（越南）
    LanguageItem('zh_CN', langChinese, 'Chinese'),  // 简体中文（中国）
    LanguageItem('zh_TW', langChineseTraditional, 'Chinese'), // 繁体中文（台湾）
  ]..sort((a, b) { // 按描述字段排序（保证语言列表展示顺序稳定）
    String as = a.desc ?? '';
    String bs = b.desc ?? '';
    return as.compareTo(bs); // 字符串自然排序
  });

  /// 初始化多语言配置（核心初始化方法）
  /// [settings] 本地存储实例（必须提前初始化）
  /// 作用：
  /// 1. 关联本地存储，用于读写语言编码
  /// 2. 加载已持久化的语言编码，初始化Locale
  Future<void> init (AppSettings settings) async {
    _settings = settings; // 绑定本地存储实例
    String code = getCurrentLanguageCode(); // 获取已存储的语言编码（无则为空）
    _updateLanguage(code); // 初始化Locale（应用语言）
  }

  /// 内部方法 - 更新应用Locale（核心逻辑）
  /// [code] 语言编码（如zh_CN、en_US、''）
  /// 流程：
  /// 1. 解析编码为Locale对象
  /// 2. 若解析失败，使用设备系统Locale
  /// 3. 修正Locale（处理中文脚本等特殊场景）
  /// 4. 更新GetX全局Locale（使语言生效）
  void _updateLanguage(String code) {
    Locale? locale = parseLocale(code); // 解析语言编码为Locale
    if (locale == null) {
      // 解析失败 - 使用设备系统默认Locale
      locale = Get.deviceLocale;
      if (locale == null) {
        // 极端情况：设备无Locale（理论上不会发生）
        return;
      }
      // 修正Locale（处理中文Hans/Hant脚本）
      locale = patchLocale(locale);
    }
    // 更新GetX全局Locale - 语言切换核心步骤
    Get.updateLocale(locale);
  }

  /// 实现接口方法 - 设置并持久化语言
  /// [code] 目标语言编码（如zh_CN、en_US、''）
  /// 返回值：是否持久化成功
  /// 流程：
  /// 1. 将语言编码持久化到本地存储
  /// 2. 更新GetX Locale（即时生效）
  /// 3. 触发App更新（刷新页面/重启）
  /// 异常：通过assert断言保证持久化成功（开发环境）
  @override
  Future<bool> setLanguage(String code) async {
    // 持久化语言编码到本地存储（核心：保证重启后生效）
    bool ok = await _settings!.setValue('language', code);
    // 开发环境断言：若持久化失败，直接抛出错误（生产环境可改为日志）
    assert(ok, 'failed to set language: $code'); 
    // 更新Locale（使语言即时生效）
    _updateLanguage(code);
    // 触发App更新（通过nav工具类刷新页面/重启）
    await appTool.forceAppUpdate(); 
    return ok;
  }

  /// 实现接口方法 - 获取当前语言编码
  /// 返回值：
  /// 1. 已持久化的编码（如zh_CN）
  /// 2. 空字符串（无持久化编码，使用系统默认）
  /// 说明：返回值为String?类型，需判断是否为String
  @override
  String getCurrentLanguageCode() {
    var code = _settings?.getValue('language'); // 从本地存储读取
    if (code is String) {
      return code; // 有值则返回
    }
    return ''; // 无值返回空（表示系统默认）
  }

  /// 实现接口方法 - 获取当前语言显示名称
  /// 流程：
  /// 1. 获取当前语言编码
  /// 2. 遍历语言列表，匹配编码
  /// 3. 返回匹配项的name（无匹配则返回空）
  @override
  String getCurrentLanguageName() {
    String code = getCurrentLanguageCode(); // 获取当前编码
    for (var item in _items) {
      if (item.code == code) {
        return item.name; // 匹配成功，返回显示名称
      }
    }
    return ''; // 无匹配（理论上不会发生）
  }

  /// 实现接口方法 - 解析语言编码为Locale对象
  /// [code] 语言编码（支持格式：zh_CN、zh、en_US等）
  /// 返回值：解析后的Locale（null表示解析失败）
  /// 解析规则：
  /// 1. 空字符串 → 返回null（使用系统默认）
  /// 2. 单段编码（如zh）→ Locale(languageCode)
  /// 3. 双段编码（如zh_CN）→ Locale(languageCode, countryCode)
  /// 4. 三段编码（如zh_Hans_CN）→ Locale.fromSubtags（含脚本）
  @override
  Locale? parseLocale(String? code) {
    // 空值/空字符串 → 解析失败
    if (code == null || code.isEmpty) {
      return null;
    }
    // 分割编码（支持_分隔的多段格式）
    List<String> pair = code.split('_');
    String languageCode = pair.first;
    // 断言：语言编码不能为空（开发环境检查）
    assert(languageCode.isNotEmpty, 'language code error: $code');

    // 单段编码（如zh、en）
    if (pair.length == 1) {
      return Locale(languageCode);
    }
    // 双段编码（如zh_CN、en_US）
    String countryCode = pair.last;
    assert(countryCode.isNotEmpty, 'country code error: $code');
    if (pair.length == 2) {
      return Locale(languageCode, countryCode);
    }
    // 三段编码（如zh_Hans_CN）
    String scriptCode = pair[1];
    assert(scriptCode.isNotEmpty, 'script code error: $code');
    // 修正Locale（处理中文脚本）后返回
    return patchLocale(Locale.fromSubtags(
      languageCode: languageCode,
      scriptCode: scriptCode,
      countryCode: countryCode,)
    );
  }

  /// 实现接口方法 - 修正Locale（处理特殊场景）
  /// [locale] 原始Locale对象
  /// 核心处理：
  /// 1. 中文Hans脚本 → 强制转为zh_CN（简体）
  /// 2. 中文Hant脚本 → 强制转为zh_TW（繁体）
  /// 3. 其他Locale → 原样返回
  @override
  Locale patchLocale(Locale locale) {
    var code = locale.scriptCode?.toLowerCase(); // 转为小写，避免大小写问题
    // 处理简体中文（Hans脚本）
    if (code == 'hans') {
      return const Locale('zh', 'CN');
    }
    // 处理繁体中文（Hant脚本）
    else if (code == 'hant') {
      return const Locale('zh', 'TW');
    }
    // 其他Locale无需修正
    return locale;
  }

  // 列表数据源方法 - 获取分区数（固定为1，单分区列表）
  @override
  int getSectionCount() => 1;

  // 列表数据源方法 - 获取指定分区的元素数量
  // [section] 分区索引（固定为0）
  // 返回值：语言列表总长度
  @override
  int getItemCount(int section) => _items.length;

  // 列表数据源方法 - 获取指定位置的语言项
  // [sec] 分区索引（固定为0）
  // [item] 元素索引（0 ~ getItemCount(0)-1）
  // 返回值：对应位置的LanguageItem
  @override
  LanguageItem getItem(int sec, int item) => _items[item];

  /// GetX翻译表 - 静态获取（供GetMaterialApp使用）
  /// 说明：
  /// 1. 整合所有语言的翻译表
  /// 2. key为语言编码（如zh_CN、en_US）
  /// 3. value为对应语言的key-value翻译映射
  static Translations get translations => _Translations();

  // 兼容原有私有方法（已注释，保留供参考）
  // Locale _patchLocale(Locale locale) => patchLocale(locale);
}

/// GetX翻译表实现类 - 整合所有语言的翻译映射
/// 继承GetX的Translations，实现keys方法提供翻译数据
/// 说明：
/// 1. 每个语言编码对应一个翻译表（如'zh_CN'对应intlZhCn）
/// 2. 支持多别名（如'en'和'en_US'指向同一翻译表）
/// 3. 翻译表格式为Map<String, String>（key为文本标识，value为翻译文本）
class _Translations extends Translations {

  @override
  Map<String, Map<String, String>> get keys => {
    // 南非荷兰语
    'af': intlAfZa,
    'af_ZA': intlAfZa,

    // 阿拉伯语
    'ar': intlAr,

    // 孟加拉语
    'bn': intlBnBd,
    'bn_BD': intlBnBd,

    // 德语
    'de': intlDeDe,
    'de_DE': intlDeDe,

    // 英语（兼容美国/英国）
    'en': intlEnUs,
    'en_US': intlEnUs,
    'en_GB': intlEnUs,

    // 西班牙语
    'es': intlEsEs,
    'es_ES': intlEsEs,

    // 法语
    'fr': intlFrFr,
    'fr_FR': intlFrFr,

    // 印地语
    'hi': intlHiIn,
    'hi_IN': intlHiIn,

    // 印尼语
    'id': intlIdId,
    'id_ID': intlIdId,

    // 意大利语
    'it': intlItIt,
    'it_IT': intlItIt,

    // 日语
    'ja': intlJaJp,
    'ja_JP': intlJaJp,

    // 韩语
    'ko': intlKoKr,
    'ko_KR': intlKoKr,

    // 马来语
    'ms': intlMsMy,
    'ms_MY': intlMsMy,

    // 荷兰语
    'nl': intlNlNl,
    'nl_NL': intlNlNl,

    // 葡萄牙语
    'pt': intlPtPt,
    'pt_PT': intlPtPt,

    // 俄语
    'ru': intlRuRu,
    'ru_RU': intlRuRu,

    // 泰语
    'th': intlThTh,
    'th_TH': intlThTh,

    // 土耳其语
    'tr': intlTrTr,
    'tr_TR': intlTrTr,

    // 越南语
    'vi': intlViVN,
    'vi_VN': intlViVN,

    // 中文（简体/繁体）
    'zh': intlZhCn,      // 中文默认使用简体
    'zh_CN': intlZhCn,   // 简体中文
    'zh_TW': intlZhTw,   // 繁体中文
  };
}

/// 全局多语言管理入口（核心对外API）
/// 设计思路：
/// 1. 类型为接口（LanguageManagerInterface），隐藏具体实现
/// 2. 未来切换到BLoC时，只需替换右侧实例（如BlocLanguageDataSource()）
/// 3. 所有业务层调用都通过此入口，无需修改代码
final LanguageManagerInterface languageManager = LanguageDataSource();

/// 辅助方法 - 根据语言编码查找对应的LanguageItem
/// [code] 语言编码（如zh_CN、en_US）
/// 返回值：匹配的LanguageItem（null表示无匹配）
/// 匹配逻辑：
/// 1. 解析编码为Locale
/// 2. 优先精确匹配（完整编码）
/// 3. 其次模糊匹配（语言编码前缀）
LanguageItem? getLanguageItem(String? code) {
  // 解析编码为Locale（获取languageCode/countryCode）
  Locale? locale = languageManager.parseLocale(code);
  if (locale == null) {
    return null; // 解析失败，返回null
  }
  // 移除脚本编码，只保留语言+国家编码（统一匹配格式）
  String? languageCode = locale.languageCode;
  String? countryCode = locale.countryCode;
  if (countryCode == null || countryCode.isEmpty) {
    code = languageCode; // 无国家编码，使用语言编码
  } else {
    code = '${languageCode}_$countryCode'; // 拼接为完整编码
  }
  // 遍历语言列表，查找匹配项
  LanguageItem? candidate; // 模糊匹配候选
  List<String> pair;
  var lds = LanguageDataSource(); // 获取单例实例
  for (LanguageItem item in lds._items) {
    // 精确匹配（优先）
    if (item.code == code) {
      return item;
    }
    // 模糊匹配（语言编码前缀）
    pair = item.code.split('_');
    if (pair.first == languageCode) {
      candidate = item; // 记录候选（后续无精确匹配则返回）
    }
  }
  return candidate; // 返回模糊匹配结果（或null）
}

/// 辅助方法 - 解析语言编码为Locale（全局快捷方法）
/// [code] 语言编码（如zh_CN、en_US）
/// 返回值：解析后的Locale（null表示解析失败）
/// 说明：封装languageManager的parseLocale方法，增加脚本处理
Locale? parseLocale(String? code) {
  if (code == null || code.isEmpty) {
    return null;
  }
  List<String> pair = code.split('_');
  String languageCode = pair.first;
  assert(languageCode.isNotEmpty, 'language code error: $code');
  if (pair.length == 1) {
    return Locale(languageCode);
  }
  String countryCode = pair.last;
  assert(countryCode.isNotEmpty, 'country code error: $code');
  if (pair.length == 2) {
    return Locale(languageCode, countryCode);
  }
  String scriptCode = pair[1];
  assert(scriptCode.isNotEmpty, 'script code error: $code');
  // 修正Locale（处理中文脚本）
  return _patchLocale(Locale.fromSubtags(
    languageCode: languageCode,
    scriptCode: scriptCode,
    countryCode: countryCode,)
  );
}

/// 私有辅助方法 - 修正Locale（处理中文脚本）
/// [locale] 原始Locale对象
/// 返回值：修正后的Locale
/// 核心处理：
/// 1. Hans脚本 → zh_CN（简体中文）
/// 2. Hant脚本 → zh_TW（繁体中文）
/// 3. 其他 → 原样返回
Locale _patchLocale(Locale locale) {
  var code = locale.scriptCode?.toLowerCase();
  if (code == 'hans') {
    return const Locale('zh', 'CN');
  } else if (code == 'hant') {
    return const Locale('zh', 'TW');
  }
  return locale;
}