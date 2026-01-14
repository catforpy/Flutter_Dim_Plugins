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

/// 群组成员权限表说明（注释原文）：
///
///  /=============+=======+=============+=============+=============+=======\
///  |             | Foun- |    Owner    |    Admin    |    Member   | Other |
///  |             | der   | Wai Nor Fre | Wai Nor Fre | Wai Nor Fre |       |
///  +=============+=======+=============+=============+=============+=======+
///  | 1. found    |  YES  |  -   -   -  |  -   -   -  |  -   -   -  |  -    |
///  | 2. abdicate |   -   |  NO YES  NO |  -   -   -  |  -   -   -  |  -    |
///  +-------------+-------+-------------+-------------+-------------+-------+
///  | 3. invite   |   -   | YES YES YES | YES YES YES |  NO YES  NO |  -    |
///  | 4. expel    |   -   |  NO YES YES |  NO YES  NO |  NO  NO  NO |  -    |
///  | 5. join     |   -   |  -   -   -  |  -   -   -  |  -   -   -  | YES   |
///  | 6. quit     |   -   |  NO  NO  NO |  NO  NO  NO | YES YES  -  |  -    |
///  +-------------+-------+-------------+-------------+-------------+-------+
///  | 7. hire     |   -   |  NO YES YES |  NO  NO  NO |  NO  NO  NO |  -    |
///  | 8. fire     |   -   |  NO YES YES |  NO  NO  NO |  NO  NO  NO |  -    |
///  | 9. resign   |   -   |  -   -   -  | YES YES  -  |  -   -   -  |  -    |
///  +-------------+-------+-------------+-------------+-------------+-------+
///  | 10. speak   |   -   | YES YES YES | YES YES YES | YES YES  NO |  NO   |
///  | 11. history |  1st  |  NO YES YES |  NO  NO  NO |  NO  NO  NO |  NO   |
///  \=============+=======+=============+=============+=============+=======/
///                                (Wai: Waiting, Nor: Normal, Fre: Freezing)
///
/// 角色转换模型说明（注释原文）：
///
///        Founder
///           |      (Freezing) ----+         (Freezing) ------+
///           |        /            |           /              |
///           V       /             V          /               V
///        Owner (Normal)          Member (Normal)         Strangers
///                   \             |  ^   |   \               |
///                    \            |  |   |    \              |
///                  (Waiting) <----+  |   |  (Waiting) <------+
///                     ^              |   |
///                     |      (Freezing)  |
///                     |        /         |
///                   Admin (Normal)       |
///                              \         |
///                            (Waiting) <-+
///
/// 权限位定义说明（注释原文）：
///      0000 0001 - speak（发言权限）
///      0000 0010 - rename（重命名权限）
///      0000 0100 - invite（邀请权限）
///      0000 1000 - expel (admin)（管理员踢人权限）
///
///      0001 0000 - abdicate/hire/fire (owner)（群主让位/雇佣/解雇权限）
///      0010 0000 - write history（写入历史记录权限）
///      0100 0000 - Waiting（等待状态）
///      1000 0000 - Freezing（冻结状态）
///
///      (All above are just some advices to help choosing numbers :P)
///
/// 群组成员类型与状态常量类
/// 定义了不同角色的权限位和状态位组合，用于群组权限控制
class MemberType {

  /// 创始人权限位：0010 0000（仅拥有写入历史记录权限）
  static const int kFounder  = (0x20); 
  /// 群主权限位：0011 1111（拥有所有基础权限+写入历史记录）
  static const int kOwner    = (0x3F); 
  /// 管理员权限位：0000 1111（发言+重命名+邀请+踢人权限）
  static const int kAdmin    = (0x0F); 
  /// 普通成员权限位：0000 0111（发言+重命名+邀请权限）
  static const int kMember   = (0x07); 
  /// 其他用户权限位：0000 0000（无任何权限）
  static const int kOther    = (0x00); 

  /// 冻结状态位：1000 0000（叠加到角色权限位上表示冻结状态）
  static const int kFreezing = (0x80); 
  /// 等待状态位：0100 0000（叠加到角色权限位上表示等待状态）
  static const int kWaiting  = (0x40); 

  /// 群主-等待状态：群主权限 + 等待状态位
  static const int kOwnerWaiting   = (kOwner  | kWaiting);
  /// 群主-冻结状态：群主权限 + 冻结状态位
  static const int kOwnerFreezing  = (kOwner  | kFreezing);
  /// 管理员-等待状态：管理员权限 + 等待状态位
  static const int kAdminWaiting   = (kAdmin  | kWaiting);
  /// 管理员-冻结状态：管理员权限 + 冻结状态位
  static const int kAdminFreezing  = (kAdmin  | kFreezing);
  /// 普通成员-等待状态：普通成员权限 + 等待状态位
  static const int kMemberWaiting  = (kMember | kWaiting);
  /// 普通成员-冻结状态：普通成员权限 + 冻结状态位
  static const int kMemberFreezing = (kMember | kFreezing);

}