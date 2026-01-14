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

import 'package:dim_client/compat.dart';
import 'package:dim_client/sdk.dart';
import 'package:dim_client/src/common/utils/cache.dart';

/// 实体ID工厂
/// 扩展IdentifierFactory，支持自定义ID创建和内存优化
class EntityIDFactory extends IdentifierFactory {
  
  /// 内存优化方法：收到内存警告时调用，移除50%缓存的ID对象
  /// @return 剩余缓存对象数量
  int reduceMemory(){
    int finger = 0;
    finger = thanos(identifiers, finger);
    return finger >> 1;
  }

  /// 创建新的ID对象（重写）
  /// @param identifier - ID字符串
  /// @param name - 名称
  /// @param address - 地址
  /// @param terminal - 终端标识
  /// @return 自定义的_EntityID对象
  @override // protected
  ID newID(String identifier, {String? name, required Address address, String? terminal}) {
    // 重写以创建自定义ID对象
    return _EntityID(identifier, name: name, address: address, terminal: terminal);
  }

  /// 解析ID字符串（重写）
  /// @param identifier - ID字符串
  /// @return 解析后的ID对象（null=解析失败）
  @override
  ID? parse(String identifier){
    // 检查广播ID
    int size = identifier.length;
    if(size < 4 || size > 64){
      assert(false, 'ID empty');
      return null;
    }else if(size == 15){
      // 处理“anyone@anywhere”广播ID
      String lower = identifier.toLowerCase();
      if(ID.ANYONE.toString() == lower){
        return ID.ANYONE;
      }
    }else if(size == 19){
      // chuli "everyone@everywhere"、“stations@everywhere"广播ID
      String lower = identifier.toLowerCase();
      if(ID.EVERYONE.toString() == lower ){
        return ID.EVERYONE;
      }
    }else if (size == 13) {
      // 处理"moky@anywhere"创始人ID
      String lower = identifier.toLowerCase();
      if (ID.FOUNDER.toString() == lower) {
        return ID.FOUNDER;
      }
    }
    // 解析普通ID（调用父类方法）
    return super.parse(identifier);
  }
}

/// 实体ID实现类
/// 扩展Identifier，自定义type计算逻辑
class _EntityID extends Identifier {
  /// 构造方法
  /// @param string - ID字符串
  /// @param name - 名称
  /// @param address - 地址
  /// @param terminal - 终端标识
  _EntityID(super.string, {super.name, required super.address, super.terminal});

  /// 获取实体类型（重写）
  /// 兼容MKM 0.9.*版本的网络ID转换
  @override
  int get type{
    String? text = name;
    if(text == null || text.isEmpty){
      // 无名称字段的ID默认为用户类型（如BTC地址）
      return EntityType.USER;
    }
    // 兼容MKM 0.9.*：从地址的网络ID转换实体类型
    return NetworkID.getType(address.network);
  }
}