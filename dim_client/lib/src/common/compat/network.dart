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

import 'package:dim_client/plugins.dart';

///  @enum MKMNetworkID
///
///  @abstract 网络类型标识，用于区分实体类型
///
///  @discussion 地址可标识个人、群组、团队甚至物联设备：
///      MKMNetwork_Main - 个人账号（应有公钥，由Meta数据证明）
///      MKMNetwork_Group - 人群组（应有创始人/群主和成员）
///      MKMNetwork_Moments - 个人社交圈（朋友圈）
///      MKMNetwork_Polylogue - 虚拟临时社交圈（多人聊天，<100人）
///      MKMNetwork_Chatroom - 大型持久社交圈（聊天室，≥100人）
///      MKMNetwork_SocialEntity - 社交实体
///      MKMNetwork_Organization - 独立组织
///      MKMNetwork_Company - 公司
///      MKMNetwork_School - 学校
///      MKMNetwork_Government - 政府部门
///      MKMNetwork_Department - 部门
///      MKMNetwork_Thing - IoT设备预留
///
///  二进制位定义：
///      0000 0001 - 独立分支实体
///      0000 0010 - 可包含其他群组的大型组织
///      0000 0100 - 顶级组织
///      0000 1000 - (MAIN) 类人实体
///
///      0001 0000 - 包含成员的群组
///      0010 0000 - 需要管理员的大型组织
///      0100 0000 - 现实世界实体
///      1000 0000 - (IoT) 物联设备
///
class NetworkID {
  // ignore_for_file: constant_identifier_names

  /// BTC主网标识
  static const int BTC_MAIN         = (0x00); // 0000 0000

  /*
     *  个人账号
     */
  /// 个人账号（用户）
  static const int MAIN             = (0x08); // 0000 1000 (Person)

  /*
     *  虚拟群组
     */
  /// 基础群组
  static const int GROUP            = (0x10); // 0001 0000 (Multi-Persons)

  /// 多人聊天（<100人）
  static const int POLYLOGUE        = (0x10); // 0001 0000 (Multi-Persons Chat, N < 100)
  /// 聊天室（≥100人）
  static const int CHATROOM         = (0x30); // 0011 0000 (Multi-Persons Chat, N >= 100)

  /*
     *  网络实体
     */
  /// 服务提供商
  static const int PROVIDER         = (0x76); // 0111 0110 (Service Provider)
  /// 服务器节点
  static const int STATION          = (0x88); // 1000 1000 (Server Node)

  /// 机器人
  static const int BOT              = (0xC8); // 1100 1000
  /// IoT设备
  static const int THING            = (0x80); // 1000 0000 (IoT)

  /// 从网络ID转换实体类型（兼容MKM 0.9.*）
  /// @param type - 网络ID
  /// @return 实体类型
  static int getType(int type) {
    // 兼容MKM 0.9.*版本的类型转换
    switch (type) {
      case MAIN:
        return EntityType.USER;
      case GROUP:
        return EntityType.GROUP;
      case CHATROOM:
        return EntityType.GROUP | CHATROOM;
      case STATION:
        return EntityType.STATION;
      case PROVIDER:
        return EntityType.ISP;
      case BOT:
        return EntityType.BOT;
    }
    return type;
  }

}