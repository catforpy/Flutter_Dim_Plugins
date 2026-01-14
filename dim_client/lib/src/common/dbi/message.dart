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

import 'package:dim_client/sdk.dart';

/// 加密密钥数据库接口
/// 继承CipherKeyDelegate，负责加密密钥的管理
abstract interface class CipherKeyDBI implements CipherKeyDelegate {

}

/// 群组密钥数据库接口
/// 负责群组密钥的存储和查询
abstract interface class GroupKeysDBI {

  /// 获取指定群组-发送方的群组密钥映射
  /// @param group - 群组ID
  /// @param sender - 发送方ID
  /// @return 密钥映射字典
  Map getGroupKeys({required ID group, required ID sender});

  /// 保存指定群组-发送方的群组密钥映射
  /// @param group - 群组ID
  /// @param sender - 发送方ID
  /// @param keys - 密钥映射字典
  /// @return 操作结果：false=失败
  bool saveGroupKeys({required ID group, required ID sender, required Map keys});
}

/// 消息数据库总接口
/// 整合加密密钥和群组密钥数据库接口，提供统一的消息密钥数据访问入口
abstract interface class MessageDBI implements CipherKeyDBI, GroupKeysDBI {

}