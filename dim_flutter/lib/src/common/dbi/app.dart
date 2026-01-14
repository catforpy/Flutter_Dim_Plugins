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

import 'package:dim_client/plugins.dart';

/// 应用自定义信息数据库接口
/// 用于存储/获取应用层的自定义键值对数据，支持过期清理
abstract class AppCustomizedInfoDBI {

  ///  获取已存储的自定义内容
  ///
  /// @param key - 缓存键
  /// @param mod - 模块名（可选，用于区分不同模块的相同key）
  /// @return 自定义内容（Mapper类型，键值对结构）
  Future<Mapper?> getAppCustomizedInfo(String key, {String? mod});

  ///  存储自定义内容
  ///
  /// @param content - 自定义内容（键值对结构）
  /// @param key     - 缓存键
  /// @param expires - 过期时间（可选，设置后会自动清理）
  /// @return 操作成功返回true
  Future<bool> saveAppCustomizedInfo(Mapper content,String key,{Duration? expires});

  ///  清理所有已过期的自定义内容
  ///
  /// @return 操作成功返回true
  Future<bool> clearExpiredAppCustomizedInfo();
}