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

import 'package:dim_plugins/dim_plugins.dart';

/// 通用ID工厂类
/// 核心作用：
/// 1. 实现IDFactory接口，提供身份ID的生成/创建/解析能力；
/// 2. 内置缓存机制，避免重复创建相同ID对象；
/// 3. 支持ID字符串的解析（格式：name@address/terminal）；
class IdentifierFactory implements IDFactory{
  /// ID缓存池：key=ID字符串，value=ID对象
  /// protected
  final Map<String, ID> identifiers = {};

  /// 生成身份ID（从Meta元数据）
  /// [meta] - 身份元数据
  /// [network] - 网络类型
  /// [terminal] - 终端标识（可选）
  /// 返回值：生成的ID对象
  @override
  ID generateIdentifier(Meta meta,int? network,{String? terminal}){
    // 先生成地址
    Address address = Address.generate(meta,network);
    // 创建ID
    return ID.create(name: meta.seed,address: address,terminal: terminal);
  }

  /// 创建身份ID（从名称/地址/终端）
  /// [name] - 名称（可选）
  /// [address] - 地址（必填）
  /// [terminal] - 终端（可选）
  /// 返回值：创建的ID对象
  @override
  ID createIdentifier({String? name,required Address address,String? terminal}){
    // 拼接ID字符串
    String identifier = Identifier.concat(name: name,address: address,terminal: terminal);
    // 优先从缓存获取
    ID? did = identifiers[identifier];
    if(did == null){
      // 缓存未命中，创建新ID
      did = newID(identifier, name: name, address: address, terminal: terminal);
      // 加入缓存
      identifiers[identifier] = did;
    }
    return did;
  }

  /// 解析ID字符串为ID对象
  /// 补充说明：优先从缓存获取，缓存未命中则解析并缓存；
  /// [identifier] - ID字符串
  /// 返回值：ID对象（解析失败返回null）
  @override
  ID? parseIdentifier(String identifier){
    // 优先从缓存获取
    ID? did = identifiers[identifier];
    if(did == null){
      // 缓存未命中，解析ID
      did = parse(identifier);
      if (did != null) {
        // 解析成功，加入缓存
        identifiers[identifier] = did;
      }
    }
    return did;
  }

  /// 创建新的ID对象（可重写以扩展自定义ID）
  /// [identifier] - ID字符串
  /// [name] - 名称
  /// [address] - 地址
  /// [terminal] - 终端
  /// 返回值：新的ID对象
  // protected
  ID newID(String identifier, {String? name, required Address address, String? terminal}) {
    /// 可重写此方法实现自定义ID
    return Identifier(identifier, name: name, address: address, terminal: terminal);
  }

  /// 解析ID字符串（格式：name@address/terminal）
  /// [identifier] - ID字符串
  /// 返回值：ID对象（解析失败返回null）
  // protected
  ID? parse(String identifier){
    String? name;
    Address? address;
    String? terminal;
    // 第一步：按/分割（分离终端）
    List<String> pair = identifier.split('/');
    assert(pair.first.isNotEmpty, 'ID error: $identifier');
    // 处理终端部分
    if (pair.length == 1) {
      // 无终端
      terminal = null;
    } else {
      // 有终端（格式：xxx/terminal）
      assert(pair.length == 2, 'ID error: $identifier');
      terminal = pair.last;
      assert(terminal.isNotEmpty, 'ID.terminal error: $identifier');
    }
    // 第二步：按@分割（分离名称和地址）
    pair = pair.first.split('@');
    assert(pair.first.isNotEmpty, 'ID error: $identifier');
    if (pair.length == 1) {
      // 无名称（格式：address）
      name = null;
      address = Address.parse(pair.last);
    } else if (pair.length == 2) {
      // 有名称（格式：name@address）
      name = pair.first;
      address = Address.parse(pair.last);
    } else {
      // 格式错误（包含多个@）
      assert(false, 'ID error: $identifier');
      return null;
    }
    // 校验地址是否解析成功
    if (address == null) {
      assert(false, 'cannot get address from ID: $identifier');
      return null;
    }
    // 创建ID对象
    return newID(identifier, name: name, address: address, terminal: terminal);
  }
}