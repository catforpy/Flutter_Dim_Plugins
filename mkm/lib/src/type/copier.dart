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

import 'package:mkm/type.dart';

/// 数据拷贝工具接口
/// 补充说明：提供对象的「浅拷贝」和「深拷贝」能力，
/// 支持 Mapper/Map/List 类型，其他类型直接返回原对象
abstract interface class Copier {

  /// 浅拷贝对象
  /// 补充说明：
  /// - null → null；
  /// - Mapper → 浅拷贝其内部 Map；
  /// - Map → 浅拷贝（仅复制键值引用）；
  /// - List → 浅拷贝（仅复制元素引用）；
  /// - 其他类型 → 直接返回原对象；
  /// [object] - 待拷贝对象
  static dynamic copy(Object? object){
    if (object == null){
      return null;
    }else if (object is Mapper) {
      return copyMap(object.toMap());
    } else if (object is Map) {
      return copyMap(object);
    } else if (object is List) {
      return copyList(object);
    } else {
      return object;
    }
  }

  /// 深拷贝对象
  /// 补充说明：
  /// - 递归拷贝嵌套的 Mapper/Map/List；
  /// - 基础类型（int/string/bool 等）无深拷贝概念，直接返回；
  /// [object] - 待拷贝对象
  static dynamic deepCopy(Object? object) {
    if (object == null) {
      return null;
    } else if (object is Mapper) {
      return deepCopyMap(object.toMap());
    } else if (object is Map) {
      return deepCopyMap(object);
    } else if (object is List) {
      return deepCopyList(object);
    } else {
      return object;
    }
  }

  /// 浅拷贝 Map
  /// 补充说明：创建新 Map，复制原 Map 的所有键值对（仅复制引用，不递归拷贝值）
  /// [dict] - 待拷贝 Map
  static Map copyMap(Map dict) {
    Map clone = {};
    dict.forEach((key, value) {
      clone[key] = value;
    });
    return clone;
  }

  /// 深拷贝 Map
  /// 补充说明：创建新 Map，递归深拷贝所有值（键保持原引用）
  /// [dict] - 待拷贝 Map
  static Map deepCopyMap(Map dict) {
    Map clone = {};
    dict.forEach((key, value) {
      clone[key] = deepCopy(value);
    });
    return clone;
  }

  /// 浅拷贝 List
  /// 补充说明：创建新 List，复制原 List 的所有元素（仅复制引用，不递归拷贝元素）
  /// [array] - 待拷贝 List
  static List copyList(List array) {
    List clone = [];
    for (var item in array) {
      clone.add(item);
    }
    return clone;
  }

  /// 深拷贝 List
  /// 补充说明：创建新 List，递归深拷贝所有元素
  /// [array] - 待拷贝 List
  static List deepCopyList(List array) {
    List clone = [];
    for (var item in array) {
      clone.add(deepCopy(item));
    }
    return clone;
  }
}