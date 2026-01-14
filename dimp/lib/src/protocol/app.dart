/* license: https://mit-license.org
 *
 *  ObjectKey : Object & Key kits
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

import 'package:dimp/dkd.dart';

/// 纯应用层消息内容接口
/// 作用：定义仅面向特定应用的消息结构，用于区分不同APP的专属消息
/// 数据格式：{
///      type : i2s(0xA0),  // 消息类型标识（0xA0=应用专属）
///      sn   : 123,        // 消息序列号（唯一标识）
///
///      app   : "{APP_ID}",  // 应用ID（如："chat.dim.sechat"）
///      extra : info         // 自定义扩展字段
///  }
abstract interface class AppContent implements Content {
  /// 获取应用ID (标识该消息归属的应用)
  String get application;
}

/// 应用自定义消息内容接口（更细粒度）
/// 作用：在AppContent基础上增加“模块/动作”维度，支持应用内多模块的消息区分
/// 数据格式：{
///      type : i2s(0xCC),  // 消息类型标识（0xCC=自定义）
///      sn   : 123,        // 消息序列号
///
///      app   : "{APP_ID}",  // 应用ID（如："chat.dim.sechat"）
///      mod   : "{MODULE}",  // 模块名（如："drift_bottle" 漂流瓶）
///      act   : "{ACTION}",  // 动作名（如："throw" 扔瓶子）
///      extra : info         // 动作参数
///  }
abstract interface class CustomizedContent implements AppContent {
  /// 获取模块名(应用内的子模块标识)
  String get module;

  /// 获取动作名（模块内的具体操作）
  String get action;

  //-------- 工厂方法（创建自定义消息）--------

  /// 创建自定义消息内容
  /// @param type - 消息类型（可选，默认=0xCC）
  /// @param app  - 应用ID（必填）
  /// @param mod  - 模块名（必填）
  /// @param act  - 动作名（必填）
  /// @return 自定义消息内容实例
  static CustomizedContent create({
    String? type,
    required String app,
    required String mod,
    required String act,
  }) => type == null
      ? AppCustomizedContent.from(app: app, mod: mod, act: act)
      : AppCustomizedContent.fromType(type, app: app, mod: mod, act: act);
}
