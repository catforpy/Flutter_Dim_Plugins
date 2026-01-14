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

// 忽略“常量标识符应使用大写”的lint警告
// ignore_for_file: constant_identifier_names

/// 消息内容类型枚举
/// 作用：定义DIMP协议所有消息内容的类型常量，是“消息类型标识”的核心定义
/// 设计思路：用8位二进制位标识不同类型特征，便于扩展和识别
/// 位定义：
///      0000 0001 - 包含可读文本
///      0000 0010 - 可视觉展示（图片/视频）
///      0000 0100 - 可听觉播放（音频）
///      0000 1000 - 机器人专用，非人类可读
///
///      0001 0000 - 内容主体在外部（如CDN链接）
///      0010 0000 - 包含第三方内容（如网页）
///      0100 0000 - 包含数字资产（如转账）
///      1000 0000 - 系统消息，非人类发送
abstract interface class ContentType {
  /// 未定义类型
  static const ANY       = '${0x00}'; // 0000 0000

  /// 文本消息
  static const TEXT      = '${0x01}'; // 0000 0001

  /// 文件相关类型
  static const FILE      = '${0x10}'; // 0001 0000（通用文件）
  static const IMAGE     = '${0x12}'; // 0001 0010（图片）
  static const AUDIO     = '${0x14}'; // 0001 0100（音频）
  static const VIDEO     = '${0x16}'; // 0001 0110（视频）

  /// 网页消息
  static const PAGE      = '${0x20}'; // 0010 0000

  /// 名片消息
  static const NAME_CARD = '${0x33}'; // 0011 0011

  /// 引用回复消息
  static const QUOTE     = '${0x37}'; // 0011 0111

  /// 资产相关类型
  static const MONEY         = '${0x40}'; // 0100 0000（金额）
  static const TRANSFER      = '${0x41}'; // 0100 0001（转账）
  static const LUCKY_MONEY   = '${0x42}'; // 0100 0010（红包）
  static const CLAIM_PAYMENT = '${0x48}'; // 0100 1000（收款）
  static const SPLIT_BILL    = '${0x49}'; // 0100 1001（分账）

  /// 命令相关类型
  static const COMMAND       = '${0x88}'; // 1000 1000（通用命令）
  static const HISTORY       = '${0x89}'; // 1000 1001（历史命令/群组命令）

  /// 应用相关类型
  static const APPLICATION   = '${0xA0}'; // 1010 0000（纯应用消息）
  static const ARRAY         = '${0xCA}'; // 1100 1010（内容数组）
  static const CUSTOMIZED    = '${0xCC}'; // 1100 1100（自定义应用消息）
  static const COMBINE_FORWARD = '${0xCF}'; // 1100 1111（组合转发）

  /// 密件转发消息
  static const FORWARD       = '${0xFF}'; // 1111 1111
}