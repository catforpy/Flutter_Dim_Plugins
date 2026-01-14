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

import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// 通用比较器接口
/// 补充说明：提供对象、Map、List（含各类TypedList）的深度相等性判断能力，
/// 解决 Dart 原生 `==` 仅判断引用/浅层值的问题
abstract interface class Comparator{

  /// 判断两个对象是否「不同」（深度比较）
  /// 补充说明：
  /// - null 与非 null 视为不同；
  /// - 同一对象（identical）视为相同；
  /// - Map/List 会递归比较内部元素；
  /// - 其他类型使用原生 `!=` 判断
  static bool different(dynamic a, dynamic b){
    if(a == null){
      return b != null;
    }else if(b == null){
      return true;
    }else if(identical(a, b)){
      // 同一对象
      return false;
    }else if(a is Map){
      // 检查键值对
      return !(b is Map && mapEquals(a, b));
    }else if(a is List){
      // 检查列表项
      return !(b is List && listEquals(a, b));
    }else{
      // 其他类型
      return a != b;
    }
  }

  /// 判断两个 Map 是否相等（深度比较）
  /// 补充说明：
  /// 1. 同一对象直接返回 true；
  /// 2. 长度不同直接返回 false；
  /// 3. 遍历所有键，递归比较对应的值（使用 different 方法）；
  /// 4. 仅检查 a 中存在的键（若 b 有额外键，因长度不同已提前返回 false）
  static bool mapEquals<K, V>(Map<K, V> a, Map<K, V> b){
    if(identical(a, b)){
      // 同一对象
      return true;
    }else if(a.length != b.length){
      // 长度不同
      return false;
    }
    for(K key in a.keys){
      // 检查值
      if(different(a[key], b[key])){
        return false;
      }
    }
    return true;
  }

  /// 判断两个 List 是否相等（深度比较）
  /// 补充说明：
  /// 1. 对 TypedList（如 Uint8List/Int32List 等）使用 Arrays.equals 逐元素比较；
  /// 2. 普通 List 先判断是否同一对象/长度是否一致，再递归比较每个元素；
  /// 3. TypedList 比较时会严格校验类型（如 Uint8List 与 Int8List 视为不同）
  static bool listEquals<T>(List<T> a, List<T> b){
    // byte-字节类型
    if(a is Uint8List){
      return b is Uint8List && Arrays.equals(a, b);
    }else if(a is Int8List){
      return b is Int8List && Arrays.equals(a, b);
    }
    // short-短整型
    if(a is Uint16List){
      return b is Uint16List && Arrays.equals(a, b);
    }else if(a is Int16List){
      return b is Int16List && Arrays.equals(a, b);
    }
    // int-整型
    if(a is Uint32List){
      return b is Uint32List && Arrays.equals(a, b);
    }else if(a is Int32List){
      return b is Int32List && Arrays.equals(a, b);
    }
    // long-长整型
    if(a is Uint64List){
      return b is Uint64List && Arrays.equals(a, b);
    }else if(a is Int64List){
      return b is Int64List && Arrays.equals(a, b);
    }
    // float-单精度浮点型
    if(a is Float32List){
      return b is Float32List && Arrays.equals(a, b);
    }else if(a is Float64List){
      return b is Float64List && Arrays.equals(a, b);
    }
    // others-其他类型List
    if(identical(a, b)){
      // 同一个对象
      return true;
    }else if(a.length != b.length){
      return false;
    }
    for(int index = 0; index < a.length; ++index){
      // check elements - 检查元素
      if(different(a[index], b[index])){
        return false;
      }
    }
    return true;
  }
}

/// 数组工具类
/// 补充说明：专注于 TypedList/普通 List 的「浅层」逐元素比较，
/// 区别于 Comparator.listEquals 的递归深度比较
abstract interface class Arrays {
  /// 判断两个 List 是否相等（浅层比较）
  /// 补充说明：
  /// 1. 同一对象直接返回 true；
  /// 2. 长度不同直接返回 false；
  /// 3. 逐元素使用原生 `!=` 比较（非递归）；
  /// 4. 主要用于 TypedList 的快速比较（无嵌套元素）
  static bool equals<T>(List<T> a, List<T> b){
    if(identical(a, b)){
      // 同一个对象
      return true;
    }else if(a.length != b.length){
      // 长度不同
      return false;
    }
    for(int index = 0; index < a.length; index++){
      // 检查值
      if(a[index] != b[index]){
        return false;
      }
    }
    return true;
  }
}