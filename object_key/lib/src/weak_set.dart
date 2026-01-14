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

/// 弱引用集合：实现标准Set接口，元素为弱引用，无强引用时自动被GC回收，保证元素唯一性
/// [E] - 集合元素类型（必须继承Object，不能为null）
class WeakSet<E extends Object> implements Set<E> {
  /// 构造函数：初始化空的弱引用集合
  WeakSet() : _inner = {};

  /// 内部存储容器：存储元素的弱引用，保证唯一性
  final Set<WeakReference<dynamic>> _inner;

  /// 清理方法：移除所有已被GC回收的元素（target为null的弱引用）
  void purge() => _inner.removeWhere((wr) => wr.target == null);

  /// 清空集合：移除所有元素
  @override
  void clear() => _inner.clear();

  /// 转换为普通强引用Set
  /// 返回：包含所有有效元素的普通Set
  @override
  Set<E> toSet() {
    // 移除空条目（已被GC回收的元素）
    purge();
    // 转换条目为强引用Set
    Set<E> entries = {};
    E? item;
    for (WeakReference<dynamic> wr in _inner) {
      item = wr.target;
      if (item == null) {
        // 理论上purge后不会出现null，触发断言提示
        assert(false, 'should not happen');
      } else {
        entries.add(item);
      }
    }
    return entries;
  }

  /// 转换为普通强引用List
  /// [growable] - 是否可扩容（默认true）
  /// 返回：包含所有有效元素的普通List
  @override
  List<E> toList({bool growable = true}) => toSet().toList(growable: growable);

  /// 重写字符串格式化：输出所有有效元素
  @override
  String toString() => toSet().toString();

  /// 获取迭代器：遍历所有有效元素
  @override
  Iterator<E> get iterator => toSet().iterator;

  /// 获取集合长度（仅包含有效元素）
  @override
  int get length => toSet().length;

  /// 判断集合是否为空（仅判断有效元素）
  @override
  bool get isEmpty => toSet().isEmpty;

  /// 判断集合是否非空（仅判断有效元素）
  @override
  bool get isNotEmpty => toSet().isNotEmpty;

  /// 获取第一个有效元素
  @override
  E get first => toSet().first;

  /// 获取最后一个有效元素
  @override
  E get last => toSet().last;

  /// 获取唯一的有效元素（集合长度必须为1）
  @override
  E get single => toSet().single;

  /// 查找第一个满足条件的元素
  /// [test] - 条件判断函数
  /// [orElse] - 无符合条件元素时的回调（可选）
  /// 返回：第一个符合条件的元素
  @override
  E firstWhere(bool Function(E element) test, {E Function()? orElse}) =>
      toSet().firstWhere(test, orElse: orElse);

  /// 查找最后一个满足条件的元素
  /// [test] - 条件判断函数
  /// [orElse] - 无符合条件元素时的回调（可选）
  /// 返回：最后一个符合条件的元素
  @override
  E lastWhere(bool Function(E element) test, {E Function()? orElse}) =>
      toSet().lastWhere(test, orElse: orElse);

  /// 查找唯一满足条件的元素（集合需仅有一个符合条件的元素）
  /// [test] - 条件判断函数
  /// [orElse] - 无符合条件元素时的回调（可选）
  /// 返回：唯一符合条件的元素
  @override
  E singleWhere(bool Function(E element) test, {E Function()? orElse}) =>
      toSet().singleWhere(test, orElse: orElse);

  /// 判断是否存在满足条件的元素
  /// [test] - 条件判断函数
  /// 返回：是否存在符合条件的元素
  @override
  bool any(bool Function(E element) test) => toSet().any(test);

  /// 判断所有元素是否都满足条件
  /// [test] - 条件判断函数
  /// 返回：所有元素是否都符合条件
  @override
  bool every(bool Function(E element) test) => toSet().every(test);

  /// 查找指定元素（返回集合中实际存储的元素，用于处理相等但不同实例的情况）
  /// [object] - 待查找的元素
  /// 返回：集合中的有效元素（null表示不存在）
  @override
  E? lookup(Object? object) => toSet().lookup(object);

  /// 判断是否包含指定元素
  /// [value] - 待判断的元素
  /// 返回：是否包含该有效元素
  @override
  bool contains(Object? value) => toSet().contains(value);

  /// 判断是否包含所有指定元素
  /// [other] - 待判断的元素集合
  /// 返回：是否包含所有有效元素
  @override
  bool containsAll(Iterable<Object?> other) => toSet().containsAll(other);

  /// 获取指定索引的元素（按迭代器顺序）
  /// [index] - 索引位置
  /// 返回：对应位置的有效元素
  @override
  E elementAt(int index) => toSet().elementAt(index);

  /// 添加元素：保证唯一性，仅当元素不存在时添加（包装为弱引用）
  /// [value] - 待添加的元素
  /// 返回：是否成功添加（元素不存在则返回true）
  @override
  bool add(E value) => !contains(value) && _inner.add(WeakReference(value));

  /// 批量添加元素：逐个保证唯一性后添加
  /// [elements] - 待添加的元素集合
  @override
  void addAll(Iterable<E> elements) {
    for (var e in elements) {
      add(e);
    }
  }

  /// 移除指定元素
  /// [value] - 待移除的元素
  /// 返回：是否成功移除
  @override
  bool remove(Object? value) {
    for (var wr in _inner) {
      if (wr.target == value) {
        return _inner.remove(wr);
      }
    }
    return false;
  }

  /// 批量移除指定元素
  /// [elements] - 待移除的元素集合
  @override
  void removeAll(Iterable<Object?> elements) {
    Set<dynamic> removing = {};
    E? item;
    for (var e in elements) {
      for (var wr in _inner) {
        item = wr.target;
        // 标记待移除的弱引用（元素匹配或已被回收）
        if (item == e || item == null) {
          removing.add(wr);
        }
      }
    }
    return _inner.removeAll(removing);
  }

  /// 移除所有满足条件的元素
  /// [test] - 条件判断函数
  @override
  void removeWhere(bool Function(E element) test) =>
      _inner.removeWhere((wr) {
        E? item = wr.target;
        // 移除已被GC回收的元素，或满足条件的元素
        return item == null || test(item);
      });

  /// 求差集：返回当前集合有但[other]集合没有的元素
  /// [other] - 对比的集合
  /// 返回：差集（普通Set）
  @override
  Set<E> difference(Set<Object?> other) => toSet().difference(other);

  /// 求交集：返回当前集合和[other]集合都有的元素
  /// [other] - 对比的集合
  /// 返回：交集（普通Set）
  @override
  Set<E> intersection(Set<Object?> other) => toSet().intersection(other);

  /// 遍历所有有效元素
  /// [action] - 遍历回调函数
  @override
  void forEach(void Function(E element) action) => toSet().forEach(action);

  /// 拼接所有元素为字符串
  /// [separator] - 分隔符（默认空字符串）
  /// 返回：拼接后的字符串
  @override
  String join([String separator = ""]) => toSet().join(separator);

  /// 求并集：返回当前集合和[other]集合的所有元素（去重）
  /// [other] - 合并的集合
  /// 返回：并集（普通Set）
  @override
  Set<E> union(Set<E> other) => toSet().union(other);

  /// 类型转换：转换为指定类型的Set
  /// [R] - 目标类型
  /// 返回：转换后的Set
  @override
  Set<R> cast<R>() => toSet().cast();

  /// 展开元素为新的迭代器
  /// [toElements] - 展开函数
  /// [T] - 展开后的元素类型
  /// 返回：展开后的迭代器
  @override
  Iterable<T> expand<T>(Iterable<T> Function(E element) toElements) =>
      toSet().expand(toElements);

  /// 折叠元素为单个值
  /// [initialValue] - 初始值
  /// [combine] - 折叠函数
  /// [T] - 折叠后的类型
  /// 返回：折叠结果
  @override
  T fold<T>(T initialValue, T Function(T previousValue, E element) combine) =>
      toSet().fold(initialValue, combine);

  /// 拼接另一个迭代器
  /// [other] - 待拼接的迭代器
  /// 返回：拼接后的迭代器
  @override
  Iterable<E> followedBy(Iterable<E> other) => toSet().followedBy(other);

  /// 转换元素为新的迭代器
  /// [toElement] - 转换函数
  /// [T] - 转换后的元素类型
  /// 返回：转换后的迭代器
  @override
  Iterable<T> map<T>(T Function(E e) toElement) => toSet().map(toElement);

  /// 归约元素为单个值
  /// [combine] - 归约函数
  /// 返回：归约结果
  @override
  E reduce(E Function(E value, E element) combine) => toSet().reduce(combine);

  /// 保留所有指定元素，移除其他元素
  /// [elements] - 待保留的元素集合
  @override
  void retainAll(Iterable<Object?> elements) => toSet().retainAll(elements);

  /// 保留所有满足条件的元素，移除其他元素
  /// [test] - 条件判断函数
  @override
  void retainWhere(bool Function(E element) test) => toSet().retainWhere(test);

  /// 跳过前[count]个元素
  /// [count] - 跳过的数量
  /// 返回：剩余的有效元素迭代器
  @override
  Iterable<E> skip(int count) => toSet().skip(count);

  /// 跳过满足条件的元素，直到第一个不满足条件的元素
  /// [test] - 条件判断函数
  /// 返回：剩余的有效元素迭代器
  @override
  Iterable<E> skipWhile(bool Function(E value) test) => toSet().skipWhile(test);

  /// 获取前[count]个元素
  /// [count] - 获取的数量
  /// 返回：前count个有效元素迭代器
  @override
  Iterable<E> take(int count) => toSet().take(count);

  /// 获取满足条件的元素，直到第一个不满足条件的元素
  /// [test] - 条件判断函数
  /// 返回：符合条件的有效元素迭代器
  @override
  Iterable<E> takeWhile(bool Function(E value) test) => toSet().takeWhile(test);

  /// 过滤满足条件的元素
  /// [test] - 条件判断函数
  /// 返回：符合条件的有效元素迭代器
  @override
  Iterable<E> where(bool Function(E element) test) => toSet().where(test);

  /// 过滤指定类型的元素
  /// [T] - 目标类型
  /// 返回：指定类型的有效元素迭代器
  @override
  Iterable<T> whereType<T>() => toSet().whereType();
}