import 'package:dim_flutter/src/ui/language.dart';
import 'package:dim_flutter/src/ui/settings.dart';
import 'package:flutter/material.dart';

/// 多语言核心抽象接口
/// 隔离GetX/BLoC的多语言实现，定义通用行为
abstract class LanguageManagerInterface {
  /// 初始化语言配置（带AppSettings参数，和实现类匹配）
  Future<void> init(AppSettings settings);

  /// 设置并持久化语言（code: 如zh_CN、en_US）
  Future<bool> setLanguage(String code);

  /// 获取当前语言编码
  String getCurrentLanguageCode();

  /// 获取当前语言显示名称
  String getCurrentLanguageName();

  /// 解析语言编码为Locale对象
  Locale? parseLocale(String? code);

  /// 修正Locale（处理中文脚本等特殊情况）
  Locale patchLocale(Locale locale);

  // 列表数据源方法（参数名和实现类完全一致）
  int getSectionCount();
  int getItemCount(int section);
  LanguageItem getItem(int sec, int item);
}



