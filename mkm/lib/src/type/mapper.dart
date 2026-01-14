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

/// 映射器接口（扩展 Map<String, dynamic>）
/// 补充说明：
/// 1. 封装 Map 的类型安全读写（String/bool/int/double/DateTime）；
/// 2. 支持 Mapper/Stringer 类型的嵌套存储；
/// 3. 提供 Map 拷贝能力；
/// 4. 实现 == 和 hashCode，支持深度相等判断
abstract interface class Mapper implements Map<String, dynamic> {

  /// 获取字符串类型值
  /// [key] - 键
  /// [defaultValue] - 键不存在/转换失败时的默认值
  String? getString(String key, [String? defaultValue]);

  /// 获取布尔类型值
  /// [key] - 键
  /// [defaultValue] - 键不存在/转换失败时的默认值
  bool?     getBool(String key, [bool?   defaultValue]);

  /// 获取整型值
  /// [key] - 键
  /// [defaultValue] - 键不存在/转换失败时的默认值
  int?       getInt(String key, [int?    defaultValue]);

  /// 获取浮点型值
  /// [key] - 键
  /// [defaultValue] - 键不存在/转换失败时的默认值
  double? getDouble(String key, [double? defaultValue]);

  /// 获取 DateTime 类型值
  /// [key] - 键（对应值为秒级时间戳）
  /// [defaultValue] - 键不存在/转换失败时的默认值
  DateTime? getDateTime(String key, [DateTime? defaultValue]);

  /// 设置 DateTime 类型值
  /// 补充说明：将 DateTime 转换为秒级时间戳（double 类型）存储
  /// [key] - 键
  /// [time] - DateTime 值（null 则移除该键）
  void setDateTime(String key, DateTime? time);

  /// 设置 Stringer 类型值
  /// 补充说明：存储 Stringer 的 toString() 结果
  /// [key] - 键
  /// [stringer] - Stringer 对象（null 则移除该键）
  void setString(String key, Stringer? stringer);

  /// 设置 Mapper 类型值
  /// 补充说明：存储 Mapper 的 toMap() 结果（嵌套 Map）
  /// [key] - 键
  /// [mapper] - Mapper 对象（null 则移除该键）
  void setMap(String key, Mapper? mapper);

  ///  Get inner map - 获取内部存储的 Map
  ///
  /// @return Map - 内部原始 Map
  Map toMap();

  ///  Copy inner map - 拷贝内部 Map
  ///
  /// @param deepCopy - deep copy - 是否深拷贝
  /// @return Map - 拷贝后的 Map
  Map copyMap([bool deepCopy = false]);
}

/// 字典实现类（Mapper 接口的默认实现）
/// 补充说明：
/// 1. 内部封装一个 Map 作为存储载体；
/// 2. 所有读写操作均基于内部 Map；
/// 3. 实现 == 时会深度比较内部 Map；
/// 4. 完整实现 Map<String, dynamic> 接口，可直接当作 Map 使用
class Dictionary implements Mapper {
  /// 内部存储的原始 Map
  final Map _map;

  /// 构造函数
  /// 补充说明：
  /// - 无参数 → 空 Map；
  /// - 参数为 Mapper → 使用其 toMap() 结果；
  /// - 其他 Map → 直接使用；
  /// [dict] - 初始 Map/Mapper（可选）
  Dictionary([Map? dict])
      : _map = dict == null ? {}
      : dict is Mapper ? dict.toMap()
      : dict;

  @override
  String? getString(String key,[String? defaultValue]) => 
        Converter.getString(_map[key],defaultValue);

  @override
  bool? getBool(String key, [bool? defaultValue]) =>
      Converter.getBool(_map[key], defaultValue);

  @override
  int? getInt(String key, [int? defaultValue]) =>
      Converter.getInt(_map[key], defaultValue);

  @override
  double? getDouble(String key, [double? defaultValue]) =>
      Converter.getDouble(_map[key], defaultValue);

  @override
  DateTime? getDateTime(String key, [DateTime? defaultValue]) =>
      Converter.getDateTime(_map[key], defaultValue);
  
  @override
  void setDateTime(String key, DateTime? time) {
    if(time == null) {
      _map.remove(key);
    }else{
      _map[key] = time.millisecondsSinceEpoch / 1000.0;   //毫秒转秒（浮点型）
    }
  }

  @override
  void setString(String key, Stringer? stringer) {
    if (stringer == null) {
      _map.remove(key);
    } else {
      _map[key] = stringer.toString();
    }
  }

  @override
  void setMap(String key, Mapper? mapper) {
    if (mapper == null) {
      _map.remove(key);
    } else {
      _map[key] = mapper.toMap();
    }
  }

  @override
  Map toMap() => _map;

  @override
  Map copyMap([bool deepCopy = false]) {
    if (deepCopy) {
      return Copier.deepCopyMap(_map);
    } else {
      return Copier.copyMap(_map);
    }
  }

  @override
  String toString() => _map.toString();

  @override
  bool operator ==(Object other) {
    if(other is Mapper){
      if(identical(this, other)){
        // 同一对象
        return true;
      }
      // 比较内部map
      other = other.toMap();
    }
    return other is Map && Comparator.mapEquals(other, _map);
  }

  @override
  int get hashCode => _map.hashCode;

  ///
  ///   Map<String, dynamic> 接口实现
  /// 补充说明：所有 Map 接口方法均委托给内部 _map 实现
  ///
  
  @override
  Map<RK, RV> cast<RK, RV>() => _map.cast();

  @override
  bool containsValue(dynamic value) => _map.containsValue(value);

  @override
  bool containsKey(Object? key) => _map.containsKey(key);

  @override
  dynamic operator [](Object? key) => _map[key];

  @override
  void operator []=(String key, dynamic value) => _map[key] = value;

  @override
  Iterable<MapEntry<String, dynamic>> get entries => _map.entries.cast();

  @override
  Map<K2, V2> map<K2, V2>
      (MapEntry<K2, V2> Function(String key, dynamic value) convert) =>
      _map.map((key, value) => convert(key, value));

  @override
  void addEntries(Iterable<MapEntry<String, dynamic>> newEntries) =>
      _map.addEntries(newEntries);

  @override
  dynamic update(String key, Function(dynamic value) update,
      {Function()? ifAbsent}) =>
      _map.update(key, update, ifAbsent: ifAbsent);

  @override
  void updateAll(Function(String key, dynamic value) update) =>
      _map.updateAll((key, value) => update(key, value));

  @override
  void removeWhere(bool Function(String key, dynamic value) test) =>
      _map.removeWhere((key, value) => test(key, value));

  @override
  dynamic putIfAbsent(String key, Function() ifAbsent) =>
      _map.putIfAbsent(key, ifAbsent);

  @override
  void addAll(Map other) => _map.addAll(other);

  @override
  dynamic remove(Object? key) => _map.remove(key);

  @override
  void clear() => _map.clear();

  @override
  void forEach(void Function(String key, dynamic value) action) =>
      _map.forEach((key, value) => action(key, value));

  @override
  Iterable<String> get keys => _map.keys.cast();

  @override
  Iterable get values => _map.values;

  @override
  int get length => _map.length;

  @override
  bool get isEmpty => _map.isEmpty;

  @override
  bool get isNotEmpty => _map.isNotEmpty;

}