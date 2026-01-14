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

import 'package:dimsdk/dimp.dart';
import 'package:dimsdk/mkm.dart';

/// 机器人用户实体类
/// 适配 DIM 协议中机器人类型的用户身份，继承 BaseUser 复用普通用户核心能力，
/// 同时通过身份校验保证机器人身份的合法性，支持解析所属服务商信息
class Bot extends BaseUser {
  /// 构造方法：初始化机器人用户
  /// @param id - 机器人ID（必须为 EntityType.BOT 类型）
  Bot(super.id) {
    // 强制校验 ID 类型为机器人，确保 Bot 身份合法性
    assert(identifier.type == EntityType.BOT, '机器人ID类型错误: $identifier');
  }

  /// 机器人档案（语义化封装 visa 属性）
  /// 本质是获取机器人的签证文档，提供更贴合业务的调用名称
  Future<Document?> get profile async => await visa;

  /// 获取机器人所属服务商 ID（ICP ID/机器人群组）
  /// 核心逻辑：从机器人档案（签证文档）中解析 provider 字段，转换为 ID 类型
  /// @return 服务商ID/机器人群组ID，无则返回null
  Future<ID?> get provider async {
    // 先获取机器人档案
    Document? doc = await profile;
    // 解析文档中的 provider 字段并转换为 ID
    return ID.parse(doc?.getProperty('provider'));
  }
}