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

/// 弱引用值映射：实现标准Map接口，Value为弱引用，无强引用时自动被GC回收
/// [K] - Key类型（强引用）
/// [V] - Value类型（弱引用）
class WeakValueMap<K, V> implements Map<K, V> {
  /// 构造函数：初始化空的弱引用值映射
  WeakValueMap() : _inner = {};

  /// 内部存储容器：Key为强引用，Value为元素的弱引用（可null）
  final Map<K, WeakReference<dynamic>?> _inner;

  /// 清理方法：移除所有Value已被GC回收的键值对（target为null的弱引用）
  void purge() => _inner.removeWhere((key, wr) => wr?.target == null);

  /// 清空映射：移除所有键值对
  @override
  void clear() => _inner.clear();

  /// 转换为普通强引用Map
  /// 返回：包含所有有效键值对的普通Map
  Map<K, V> toMap() {
    // 移除空条目（Value已被GC回收的键值对）
    purge();
    // 转换条目为强引用Map
    return _inner.map((key, wr) => MapEntry(key, wr?.target));
  }

  /// 重写字符串格式化：输出所有有效键值对
  @override
  String toString() => toMap().toString();

  /// 类型转换：转换为指定类型的Map
  /// [RK] - 目标Key类型
  /// [RV] - 目标Value类型
  /// 返回：转换后的Map
  @override
  Map<RK, RV> cast<RK, RV>() => toMap().cast();

  /// 判断是否包含指定Value
  /// [value] - 待判断的Value
  /// 返回：是否包含该有效Value
  @override
  bool containsValue(Object? value) => toMap().containsValue(value);

  /// 判断是否包含指定Key（且对应的Value有效）
  /// [key] - 待判断的Key
  /// 返回：Key存在且Value未被GC回收
  @override
  bool containsKey(Object? key) => _inner[key]?.target != null;

  /// 获取指定Key对应的Value
  /// [key] - 目标Key
  /// 返回：有效Value（null表示Key不存在或Value已被回收）
  @override
  V? operator [](Object? key) => _inner[key]?.target;

  /// 设置指定Key的Value：包装为弱引用后存储（null值直接存null）
  /// [key] - 目标Key
  /// [value] - 待存储的Value
  @override
  void operator []=(K key, V value) =>
      _inner[key] = value == null ? null : WeakReference(value);

  /// 获取所有有效键值对的迭代器
  @override
  Iterable<MapEntry<K, V>> get entries => toMap().entries;

  /// 转换键值对为新的Map
  /// [convert] - 转换函数
  /// [K2] - 新Key类型
  /// [V2] - 新Value类型
  /// 返回：转换后的普通Map
  @override
  Map<K2, V2> map<K2, V2>(MapEntry<K2, V2> Function(K key, V value) convert) =>
      toMap().map(convert);

  /// 批量添加键值对
  /// [newEntries] - 待添加的键值对集合
  @override
  void addEntries(Iterable<MapEntry<K, V>> newEntries) {
    for (var entry in newEntries) {
      this[entry.key] = entry.value;
    }
  }

  /// 更新指定Key的Value
  /// [key] - 目标Key
  /// [update] - 更新函数（Value存在时调用）
  /// [ifAbsent] - Value不存在/已回收时的回调（可选）
  /// 返回：更新后的Value
  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) =>
      _inner.update(key, (wr) {
        V val = wr?.target;
        if (val != null) {
          // Value存在则更新
          val = update(val);
        } else if (ifAbsent != null) {
          // Value不存在则创建
          val = ifAbsent();
        }
        // 包装为弱引用返回
        return val == null ? null : WeakReference(val);
      })?.target;

  /// 批量更新所有有效键值对的Value
  /// [update] - 更新函数
  @override
  void updateAll(V Function(K key, V value) update) =>
      _inner.updateAll((key, wr) {
        V val = wr?.target;
        if (val == null) {
          // Value已回收则移除
          return null;
        }
        // 更新Value后包装为弱引用
        val = update(key, val);
        return val == null ? null : WeakReference(val);
      });

  /// 移除所有满足条件的键值对
  /// [test] - 条件判断函数
  @override
  void removeWhere(bool Function(K key, V value) test) =>
      _inner.removeWhere((key, wr) {
        V val = wr?.target;
        // 移除Value已回收的键值对，或满足条件的键值对
        return val == null || test(key, val);
      });

  /// 获取指定Key的Value，不存在则创建并存储
  /// [key] - 目标Key
  /// [ifAbsent] - Value不存在/已回收时的创建函数
  /// 返回：存在的Value或新创建的Value
  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    WeakReference<dynamic>? wr = _inner[key];
    V val = wr?.target;
    if (val == null) {
      // Value不存在则创建
      val = ifAbsent();
      this[key] = val;
    }
    return val;
  }

  /// 批量添加另一个Map的键值对
  /// [other] - 待添加的Map
  @override
  void addAll(Map<K, V> other) => other.forEach((key, value) {
    this[key] = value;
  });

  /// 移除指定Key的键值对
  /// [key] - 目标Key
  /// 返回：被移除的Value（null表示Key不存在或Value已回收）
  @override
  V? remove(Object? key) => _inner.remove(key)?.target;

  /// 遍历所有有效键值对
  /// [action] - 遍历回调函数
  @override
  void forEach(void Function(K key, V value) action) => _inner.forEach((key, wr) {
    V val = wr?.target;
    if (val != null) {
      // 仅遍历Value有效的键值对
      action(key, val);
    }
  });

  /// 获取所有有效Key的迭代器
  @override
  Iterable<K> get keys => toMap().keys;

  /// 获取所有有效Value的迭代器
  @override
  Iterable<V> get values => toMap().values;

  /// 获取有效键值对的数量
  @override
  int get length => toMap().length;

  /// 判断映射是否为空（无有效键值对）
  @override
  bool get isEmpty => toMap().isEmpty;

  /// 判断映射是否非空（有有效键值对）
  @override
  bool get isNotEmpty => toMap().isNotEmpty;

}