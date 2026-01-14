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

///  @enum MKMEntityType
///
///  @abstract A network ID to indicate what kind the entity is.
///
///  @discussion An address can identify a person, a group of people,
///      a team, even a thing.
///
///      MKMEntityType_User indicates this entity is a person's account.
///      An account should have a public key, which proved by meta data.
///
///      MKMEntityType_Group indicates this entity is a group of people,
///      which should have a founder (also the owner), and some members.
///
///      MKMEntityType_Station indicates this entity is a DIM network station.
///
///      MKMEntityType_ISP indicates this entity is a group for stations.
///
///      MKMEntityType_Bot indicates this entity is a bot user.
///
///      MKMEntityType_Company indicates a company for stations and/or bots.
///
///  Bits:
///      0000 0001 - group flag
///      0000 0010 - node flag
///      0000 0100 - bot flag
///      0000 1000 - CA flag
///      ...         (reserved)
///      0100 0000 - customized flag
///      1000 0000 - broadcast flag
///
///      (All above are just some advices to help choosing numbers :P)
/* 
 * 核心功能：定义MKM框架中所有实体的类型枚举，通过二进制位标识实体属性
 * 设计逻辑：用8位二进制位表示实体类型，每一位对应一个属性（群组/节点/机器人等）
 * 核心作用：区分用户/群组/服务器/机器人/广播等不同实体，是地址/ID类型判断的依据
 */

/// 【枚举接口】MKM实体类型
/// 用8位二进制位定义实体类型，每一位代表一个属性：
/// - 0000 0001：群组标识
/// - 0000 0010：节点标识（服务器）
/// - 0000 0100：机器人标识
/// - 0000 1000：CA认证标识
/// - 0100 0000：自定义标识
/// - 1000 0000：广播标识
abstract interface class EntityType{

  /// 基础类型(0-1位)
  static const USER        = (0x00);    // 0000 0000 - 普通用户
  static const GROUP       = (0x01);    // 0000 0001 - 用户群组(含群组标识位)

  /// 网络节点(2-3位)
  static const STATION     = (0x02);    // 0000 0010 - 服务器节点
  static const ISP         = (0x03);    // 0000 0011 - 服务提供商（服务器群组）

  /// 机器人（4-5位）
  static const BOT         = (0x04);    // 0000 0100 - 业务机器人
  static const ICP         = (0x05);    // 0000 0101 - 内容提供商（机器人群组）

  ///  Management: 6, 7, 8
  // static const SUPERVISOR    = (0x06); // 0000 0110 (Company CEO)
  // static const COMPANY       = (0x07); // 0000 0111 (Super Group for ISP/ICP)
  // static const CA            = (0x08); // 0000 1000 (Certification Authority)

  // ///  Customized: 64, 65
  // static const APP_USER      = (0x40); // 0100 0000 (Application Customized User)
  // static const APP_GROUP     = (0x41); // 0100 0001 (Application Customized Group)

  /// 广播类型(最高位)
  static const ANY        = (0x80);     // 1000 0000 - 任意地址（局部广播）
  static const EVERY      = (0x81);     // 1000 0001 - 所有地址（全局广播）

  /// 判断是否为用户（非群组、非广播）
  static bool isUser(int network) {
    return network & GROUP == USER; // 与群组位做与运算，结果为0则是用户
  }

  /// 判断是否为群组（包含群组标识位）
  static bool isGroup(int network) {
    return network & GROUP == GROUP; // 与群组位做与运算，结果为1则是群组
  }

  /// 判断是否为广播地址（包含广播标识位）
  static bool isBroadcast(int network) {
    return network & ANY == ANY; // 与广播位做与运算，结果为1则是广播
  }

}