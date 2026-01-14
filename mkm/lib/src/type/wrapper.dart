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


import 'package:mkm/src/type/stringer.dart';
import 'package:mkm/type.dart';

/// 包装器工具接口
/// 补充说明：提供「解包装」能力，将 Mapper/Stringer 等封装类型转换为原生类型（Map/String），
/// 支持递归解包嵌套的 Map/List
abstract interface class Wrapper {

  ///  Get inner String - 获取内部封装的字符串
  ///  ~~~~~~~~~~~~~~~~
  ///  Remove first wrapper - 移除第一层包装
  /// 补充说明：
  /// - null → null；
  /// - Stringer → 调用 toString()；
  /// - String → 直接返回；
  /// - 其他类型 → 断言失败，返回 toString()；
  /// [str] - 待解包的对象（String/Stringer/其他）
  static String? getString(Object? str){
    if(str == null){
      return null;
    }else if(str is Stringer){
      return str.toString();
    }else if(str is String){
      return str;
    }else{
      assert(false, 'string error: $str');
      return str.toString();
    }
  }

  ///  Get inner Map - 获取内部封装的 Map
  ///  ~~~~~~~~~~~~~
  ///  Remove first wrapper - 移除第一层包装
  /// 补充说明：
  /// - null → null；
  /// - Mapper → 调用 toMap()；
  /// - Map → 直接返回；
  /// - 其他类型 → 断言失败，返回 null；
  /// [dict] - 待解包的对象（Mapper/Map/其他）
  static Map? getMap(Object? dict) {
    if(dict == null){
      return null;
    }else if(dict is Mapper){
      return dict.toMap();
    }else if(dict is Map){
      return dict;
    }else{
      assert(false, 'map error: $dict');
      return null;
    }
  }

  ///  Unwrap recursively - 递归解包
  ///  ~~~~~~~~~~~~~~~~~~
  ///  Remove all wrappers - 移除所有嵌套包装
  /// 补充说明：
  /// - null → null；
  /// - Mapper → 递归解包其内部 Map；
  /// - Map → 递归解包所有值；
  /// - List → 递归解包所有元素；
  /// - Stringer → 转为 String；
  /// - 其他类型 → 直接返回；
  /// [object] - 待解包的对象（支持嵌套的 Mapper/Map/List/Stringer）
  static dynamic unwrap(Object? object) {
    if (object == null) {
      return null;
    } else if (object is Mapper) {
      return unwrapMap(object.toMap());
    } else if (object is Map) {
      return unwrapMap(object);
    } else if (object is List) {
      return unwrapList(object);
    } else if (object is Stringer) {
      return object.toString();
    } else {
      return object;
    }
  }

  /// Unwrap values for keys in map - 解包 Map 中的所有值
  /// 补充说明：
  /// 1. 若 Map 是 Mapper，先调用 toMap() 转为原生 Map；
  /// 2. 遍历所有键值对，递归解包值；
  /// 3. 返回新的原生 Map（所有值均为原生类型）；
  /// [dict] - 待解包的 Map/Mapper
  static Map unwrapMap(Map dict) {
    if (dict is Mapper) {
      dict = dict.toMap();
    }
    Map result = {};
    dict.forEach((key, value) {
      result[key] = unwrap(value);
    });
    return result;
  }

  /// Unwrap values in the array - 解包 List 中的所有元素
  /// 补充说明：
  /// 1. 遍历所有元素，递归解包每个元素；
  /// 2. 返回新的原生 List（所有元素均为原生类型）；
  /// [array] - 待解包的 List
  static List unwrapList(List array) {
    List result = [];
    for (var item in array) {
      result.add(unwrap(item));
    }
    return result;
  }
}