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

/// DIM 服务器所有者（服务提供商）实体类
/// 继承 BaseGroup，将服务商抽象为 ISP 类型的群组，
/// 管理服务器集群，支持服务器配置解析和相等性判断
class ServiceProvider extends BaseGroup {
  /// 构造方法：初始化服务提供商
  /// @param id - ISP 类型的群组ID
  ServiceProvider(super.id) {
    // 强制校验 ID 类型为 ISP，保证服务商身份合法性
    assert(identifier.type == EntityType.ISP, '服务商ID类型错误: $identifier');
  }

  /// 服务商档案
  /// 从文档中筛选最新的通用文档，作为服务商配置源
  Future<Document?> get profile async =>
      DocumentUtils.lastDocument(await documents, '*');

  /// 获取服务商管理的服务器列表
  /// 核心逻辑：从服务商档案中解析 stations 字段，返回服务器配置列表
  /// @return 服务器配置列表（主机/端口等）
  Future<List> get stations async {
    Document? doc = await profile;
    if (doc != null) {
      var stations = doc.getProperty('stations');
      if (stations is List) {
        return stations;
      }
    }
    // 兜底：本地存储加载（TODO：补充本地存储逻辑）
    return [];
  }

  //===== 服务器相等性判断 =====
  /// 判断两台服务器是否为同一台（灵活匹配）
  /// 分层校验逻辑：ID → 主机 → 端口，兼容广播地址/空值/默认端口
  /// @param a - 服务器A
  /// @param b - 服务器B
  /// @return 匹配返回true，否则返回false
  static bool sameStation(Station a, Station b) {
    if (identical(a, b)) {
      // 同一实例直接相等
      return true;
    }
    // 分层校验
    return _checkIdentifiers(a.identifier, b.identifier)
        && _checkHosts(a.host, b.host)
        && _checkPorts(a.port, b.port);
  }
}

/// 服务器ID校验（兼容广播地址）
/// @param a - 服务器A的ID
/// @param b - 服务器B的ID
/// @return 匹配返回true，否则返回false
bool _checkIdentifiers(ID a, ID b){
  if (identical(a, b)) {
    // 同一实例直接相等
    return true;
  } else if (a.isBroadcast || b.isBroadcast) {
    // 广播地址视为匹配
    return true;
  }
  // 普通ID严格相等
  return a == b;
}

/// 服务器主机校验（兼容空值/空字符串）
/// @param a - 服务器A的主机地址
/// @param b - 服务器B的主机地址
/// @return 匹配返回true，否则返回false
bool _checkHosts(String? a, String? b) {
  if (a == null || b == null) {
    // 任一主机为空视为匹配
    return true;
  } else if (a.isEmpty || b.isEmpty) {
    // 任一主机为空字符串视为匹配
    return true;
  }
  // 主机地址严格相等
  return a == b;
}

/// 服务器端口校验（兼容默认端口0）
/// @param a - 服务器A的端口
/// @param b - 服务器B的端口
/// @return 匹配返回true，否则返回false
bool _checkPorts(int a, int b) {
  if (a == 0 || b == 0) {
    // 任一端口为默认值0视为匹配
    return true;
  }
  // 端口严格相等
  return a == b;
}