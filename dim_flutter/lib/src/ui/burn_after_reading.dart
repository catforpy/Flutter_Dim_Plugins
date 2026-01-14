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

import 'package:dim_client/ok.dart';
import 'package:dim_client/ok.dart' as lnc;
import 'package:dim_flutter/src/ui/nav.dart';

import '../client/shared.dart';

import '../common/constants.dart';
import '../filesys/local.dart';
import 'settings.dart';

/// 读后即焚选项实体类
/// 封装自动清理的时长（秒）和对应的描述文本
class BurnAfterReadingItem {
  /// 构造函数
  /// [duration]: 自动清理时长（单位：秒）
  /// [description]: 显示描述文本
  BurnAfterReadingItem(this.duration, this.description);

  /// 自动清理时长（秒）
  final int duration;
  /// 显示描述文本（如"Manually"/"Daily"/"Weekly"）
  final String description;
}

/// 读后即焚数据源管理类（单例模式）
/// 负责管理自动清理消息/文件的配置和执行清理操作
class BurnAfterReadingDataSource {
  /// 工厂构造函数：返回单例实例
  factory BurnAfterReadingDataSource() => _instance;
  /// 静态单例实例
  static final BurnAfterReadingDataSource _instance = BurnAfterReadingDataSource._internal();
  /// 私有构造函数：防止外部实例化
  BurnAfterReadingDataSource._internal();

  /// 应用设置实例（用于读写本地配置）
  AppSettings? _settings;

  /// 上次执行清理操作的时间（用于限制清理频率）
  DateTime? _lastBurn;

  /// 清理模式常量 - 手动清理
  static const int kManually = 0;
  /// 清理模式常量 - 每日清理（24小时）
  static const int kDaily = 3600 * 24;
  /// 清理模式常量 - 3天清理（匿名模式）
  static const int kAnon = 3600 * 24 * 3;
  /// 清理模式常量 - 每周清理（7天）
  static const int kWeekly = 3600 * 24 * 7;
  /// 清理模式常量 - 每月清理（30天）
  static const int kMonthly = 3600 * 24 * 30;

  /// 读后即焚选项列表
  final List<BurnAfterReadingItem> _items = [
    BurnAfterReadingItem(kManually, 'Manually'),
    BurnAfterReadingItem(kMonthly, 'Monthly'),
    BurnAfterReadingItem(kWeekly, 'Weakly'),
    BurnAfterReadingItem(kAnon, 'Anon'),
    BurnAfterReadingItem(kDaily, 'Daily'),
  ];

  /// 初始化方法
  /// [settings]: 应用设置实例，用于读写配置
  Future<void> init(AppSettings settings) async {
    _settings = settings;
  }

  /// 设置读后即焚的自动清理时长
  /// [duration]: 清理时长（秒，对应常量值）
  /// 返回值: 是否设置成功
  Future<bool> setBurnafterReading(int duration) async {
    // 更新本地设置
    bool ok = await _settings!.setValue('burn_after_reading', duration);
    // 断言：设置失败时触发断言错误（调试模式下）
    assert(ok, 'failed to set burnAfterReading: $duration');
    // 发送“清理时间更新”通知
    var nc = lnc.NotificationCenter();
    nc.postNotification(NotificationNames.kBurnTimeUpdated, this,{
      'duration' : duration,
    });
    // 发送“设置更新”通知
    nc.postNotification(NotificationNames.kSettingUpdated, this, {
      "category": 'BurnAfterReading',
      'duration': duration,
    });
    return ok;
  }

  /// 获取当前设置的自动清理时长（秒）
  /// 返回值: 默认为kManually（手动清理）
  int getBurnAfterReading() => _settings?.getValue('burn_after_reading') ?? kManually;

  /// 获取当前清理时长对应的描述文本
  String getBurnAfterReadingdescription() {
    //  获取当前清理时长
    int duration = getBurnAfterReading();
    // 遍历预设选项，匹配对应的描述文本
    for(var pair in _items){
      if(pair.duration == duration){
        return pair.description;
      }
    }
    // 未匹配到预设选项：计算并生成自定义描述
    return _calculate(duration);
  }

  /// 执行全量清理操作（清理过期的消息、对话、文件）
  /// 返回值: 是否有数据被清理
  Future<bool> burnAll() async {
    // 获取当前清理时长
    int duration = getBurnAfterReading();
    // 手动模式：不执行清理
    if(duration <= 0){
      Log.warning('manual mode');
      return false;
    }
    // 时长小于60秒：非法值，断言错误
    else if (duration < 60) {
      assert(false, 'burn time error: $duration');
      return false;
    }

    // 获取当前时间
    DateTime now  = DateTime.now();
    // 检查上次清理时间（防止频繁清理）
    DateTime? last = _lastBurn;
    if(last != null){
      // 计算距上次清理的时间差（毫秒）
      int elapsed = now.millisecondsSinceEpoch - last.millisecondsSinceEpoch;
      // 15秒内重复清理：拒绝执行
      if (elapsed < 15000) {
        Log.warning('burn next time: $elapsed');
        return false;
      }
    }
    // 更新上次清理时间为当前时间
    _lastBurn = now;

    // 计算过期事件：当前时间-清理时间
    int millis = now.microsecondsSinceEpoch - duration * 1000;
    DateTime expired = DateTime.fromMicrosecondsSinceEpoch(millis);

    // 1. 清理过期消息
    Log.warning('burning message before: $expired');
    GlobalVariable shared = GlobalVariable();
    int msgCount = await shared.database.burnMessages(expired);
    Log.warning('burn expired messages: $msgCount, $expired');
    // 清理过期对话
    int chatCount = await shared.database.burnConversations(expired);
    Log.warning('burn expired conversations: $chatCount, $expired');
    
    // 2. 清理过期文件（TODO：待完善）
    LocalStorage storage = LocalStorage();
    int fileCount = await storage.burnAll(expired);
    Log.warning('burn expired files: $fileCount, $expired');
    
    // 返回是否有数据被清理（消息/对话/文件任一有清理则返回true）
    return msgCount > 0 || chatCount > 0 || fileCount > 0;
  }

  //
  //  Sections - 适配列表视图的分区数据方法
  //

  /// 获取分区数量（固定为1个分区）
  int getSectionCount() => 1;

  /// 获取指定分区的条目数量（返回读后即焚选项总数）
  int getItemCount(int section) => _items.length;

  /// 获取指定分区和位置的读后即焚选项
  /// [sec]: 分区索引（固定为0）
  /// [item]: 条目索引
  /// 返回值: BurnAfterReadingItem实例
  BurnAfterReadingItem getItem(int sec, int item) => _items[item];
}

/// 计算自定义清理时长的描述文本
/// [duration]: 自定义时长（秒）
/// 返回值: 本地化的描述文本
String _calculate(int duration) {
  // 小于2秒：错误
  if(duration < _seconds){
    return i18nTranslator.translate('Error');
  }
  // 小于2分钟：显示"X秒"
  else if (duration < _minutes) {
    return i18nTranslator.translate('@several seconds',
    params: {
      'several': '$duration',
    });
  } 
  // 小于2小时：显示"X分钟"
  else if (duration < _hours) {
    return i18nTranslator.translate('@several minutes',
    params: {
      'several': '${duration ~/ _minute}',
    });
  } 
  // 小于2天：显示"X小时"
  else if (duration < _days) {
    return i18nTranslator.translate('@several hours',
    params: {
      'several': '${duration ~/ _hour}',
    });
  } 
  // 小于2个月：显示"X天"
  else if (duration < _months) {
    return i18nTranslator.translate('@several days',
    params: {
      'several': '${duration ~/ _day}',
    });
  } 
  // 2个月及以上：显示"X个月"
  else {
    return i18nTranslator.translate('@several days',
    params: {
      'several': '${duration ~/ _month}',
    });
  }
}


// 时间单位常量（秒）
const int _seconds = 2;
const int _minute  = 60;
const int _minutes = 60 * 2;
const int _hour    = 3600;
const int _hours   = 3600 * 2;
const int _day     = 3600 * 24;
const int _days    = 3600 * 24 * 2;
const int _month   = 3600 * 24 * 30;
const int _months  = 3600 * 24 * 61;