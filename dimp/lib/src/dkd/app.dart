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

/// 自定义应用消息内容类
/// 设计目的：为去中心化IM提供“应用扩展”能力，支持业务方自定义消息类型，
///           通过app/mod/act三个维度区分不同业务场景的自定义消息
/// 核心字段：
///   - app：应用标识（如com.company.product）
///   - mod：模块标识（如payment、chat、profile）
///   - act：操作标识（如pay、query、update）
class AppCustomizedContent extends BaseContent implements CustomizedContent {
  /// 构造方法1：从字典初始化（用于解析网络传输的自定义消息）
  AppCustomizedContent(super.dict);

  /// 构造方法2：从消息类型+app/mod/act初始化（自定义消息类型）
  /// @param msgType - 消息类型（自定义）
  /// @param app - 应用标识
  /// @param mod - 模块标识
  /// @param act - 操作标识
  AppCustomizedContent.fromType(
    String msgType, {
    required String app,
    required String mod,
    required String act,
  }) : super.fromType(msgType) {
    this['app'] = app;
    this['mod'] = mod;
    this['act'] = act;
  }

  /// 构造方法3：默认自定义消息类型 + app/mod/act初始化（最常用）
  /// @param app - 应用标识
  /// @param mod - 模块标识
  /// @param act - 操作标识
  AppCustomizedContent.from({
    required String app,
    required String mod,
    required String act,
  }) : this.fromType(ContentType.CUSTOMIZED, app: app, mod: mod, act: act);

  /// 获取应用标识（空字符串表示未设置）
  @override
  String get application => getString('app') ?? '';

  /// 获取模块标识（空字符串表示未设置）
  @override
  String get module => getString('mod') ?? '';

  /// 获取操作标识（空字符串表示未设置）
  String get action => getString('act') ?? '';
}
