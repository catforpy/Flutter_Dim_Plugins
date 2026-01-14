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

import 'dart:math';

/// 弱引用列表：实现标准List接口，元素为弱引用，无强引用时自动被GC回收
/// [E] - 列表元素类型（必须继承Object，不能为null）
class WeakList<E extends Object> implements List<E> { 

  /// 构造函数：初始化空的弱引用列表
  WeakList() : _inner = [];

  /// 内部存储容器：存储元素的弱引用
  final List<WeakReference<dynamic>> _inner;

  /// 清理方法：移除所有已被GC回收的元素(target为null的弱引用)
  void purge() => _inner.removeWhere((wr) => wr.target == null);

  /// 清空列表：移除所有元素
  @override
  void clear() => _inner.clear();

  /// 转换为普通强引用列表
  /// [growable] - 是否可扩容（默认true）
  /// 返回：包含所有有效元素的普通List
  @override
  List<E> toList({bool growable = true}){
    // 移除空条目(已被GC回收的元素)
    purge();
    // 转换条目为强引用列表
    List<E> entries = [];
    E? item;
    for(WeakReference<dynamic> wr in _inner){
      item = wr.target;
      if(item == null){
        // 理论上purge后不会出现Null，触发断言提示
        assert(false,'弱引用移除空条目后，理论上应该不会出现这种情况');
      }else{
        entries.add(item);
      }
    }
    return entries;
  }

  /// 转换为普通强引用集合
  /// 返回：包含所有有效元素的普通Set
  @override
  Set<E> toSet() => toList().toSet();

  /// 重写字符串格式化：输出所有有效元素
  @override
  String toString() => toList().toString();

  /// 获取迭代器:遍历所有有效元素
  @override
  Iterator<E> get iterator => toList().iterator;

  /// 获取列表长度（仅包含有效元素）
  @override
  int get length => toList().length;

  /// 设置列表长度：先清理无效元素，再调整内部容器长度
  /// [size] - 目标长度
  @override
  set length(int size){
    purge();
    _inner.length = size;
  }

  /// 判断列表是否为空（仅判断有效元素）
  @override
  bool get isEmpty => toList().isEmpty;

  /// 判断列表是否非空（仅判断有效元素）
  @override
  bool get isNotEmpty => toList().isNotEmpty;

  /// 获取第一个有效元素
  @override
  E get first => toList().first;

  /// 设置第一个元素：替换为新的弱引用
  /// [item] - 新元素
  @override
  set first(E item) => _inner.first = WeakReference(item);

   /// 获取最后一个有效元素
  @override
  E get last => toList().last;

  /// 设置最后一个元素：替换为新的弱引用
  /// [item] - 新元素
  @override
  set last(E item) => _inner.last = WeakReference(item);

  /// 获取唯一的有效元素（列表长度必须为1）
  @override
  E get single => toList().single;

  /// 列表拼接：与普通List拼接规则一致
  /// [other] - 待拼接的列表
  /// 返回：拼接后的普通List
  @override
  List<E> operator +(List<E> other) => toList() + other;

  /// 获取指定索引的元素（仅有效元素）
  /// [index] - 索引位置
  /// 返回：对应位置的有效元素
  @override
  E operator [](int index) => toList()[index];

  /// 设置指定索引的元素：先清理无效元素，再存储为弱引用
  /// [index] - 索引位置
  /// [value] - 新元素
  @override
  void operator []=(int index, E value) {
    purge();
    _inner[index] = WeakReference(value);
  }

  /// 添加元素：包装为弱引用后存入内部容器
  /// [value] - 待添加的元素
  @override
  void add(E value) => _inner.add(WeakReference(value));

  /// 批量添加元素：逐个包装为弱引用后存入
  /// [iterable] - 待添加的元素集合
  @override
  void addAll(Iterable<E> iterable) {
    for(E item in iterable){
      add(item);
    }
  }

  /// 判断是否存在满足条件的元素
  /// [test] - 条件判断函数
  /// 返回：是否存在符合条件的元素
  @override
  bool any(bool Function(E element) test) => toList().any(test);

  /// 转换为索引-元素的Map
  /// 返回：普通的索引映射Map
  @override
  Map<int, E> asMap() => toList().asMap();

  /// 类型转换：转换为指定类型的List
  /// [R] - 目标类型
  /// 返回：转换后的List
  @override
  List<R> cast<R>() => toList().cast<R>();

  /// 判断是否包含指定元素
  /// [element] - 待判断的元素
  /// 返回：是否包含该有效元素
  @override
  bool contains(Object? element) => toList().contains(element);

  /// 获取指定索引的元素
  /// [index] - 索引位置
  /// 返回：对应位置的有效元素
  @override
  E elementAt(int index) => toList().elementAt(index);

  /// 判断所有元素是否都满足条件
  /// [test] - 条件判断函数
  /// 返回：所有元素是否都符合条件
  @override
  bool every(bool Function(E element) test) => toList().every(test);

  /// 展开元素为新的迭代器
  /// [toElements] - 展开函数
  /// [T] - 展开后的元素类型
  /// 返回：展开后的迭代器
  @override
  Iterable<T> expand<T>(Iterable<T> Function(E element) toElements) => toList().expand(toElements);

  /// 填充指定范围的元素
  /// [start] - 起始索引（包含）
  /// [end] - 结束索引（不包含）
  /// [fillValue] - 填充值（可选）
  @override
  void fillRange(int start, int end, [E? fillValue]) {
    purge();
    if(fillValue == null)
    {
      _inner.fillRange(start, end);
    }else{
      _inner.fillRange(start,end ,WeakReference(fillValue));
    }
  }

  /// 查找第一个满足条件的元素
  /// [test] - 条件判断函数
  /// [orElse] - 无符合条件元素时的回调（可选）
  /// 返回：第一个符合条件的元素
  @override
  E firstWhere(bool Function(E element) test, {E Function()? orElse}) => toList().firstWhere(test,orElse: orElse);

  /// 折叠元素为单个值
  /// [initialValue] - 初始值
  /// [combine] - 折叠函数
  /// [T] - 折叠后的类型
  /// 返回：折叠结果
  @override
  T fold<T>(T initialValue, T Function(T previousValue, E element) combine) => toList().fold(initialValue, combine);

  /// 拼接另一个迭代器
  /// [other] - 待拼接的迭代器
  /// 返回：拼接后的迭代器
  @override
  Iterable<E> followedBy(Iterable<E> other) => toList().followedBy(other);

  /// 遍历所有有效元素
  /// [action] - 遍历回调函数
  @override
  void forEach(void Function(E element) action) => toList().forEach(action);

  /// 获取指定范围的子列表
  /// [start] - 起始索引（包含）
  /// [end] - 结束索引（不包含）
  /// 返回：子列表迭代器
  @override
  Iterable<E> getRange(int start, int end) => toList().getRange(start, end);

  /// 查找元素的第一个索引
  /// [element] - 待查找的元素
  /// [start] - 起始查找索引（默认0）
  /// 返回：元素的索引（不存在则返回-1）
  @override
  int indexOf(E element, [int start = 0]) => toList().indexOf(element, start);

  /// 查找第一个满足条件的元素索引
  /// [test] - 条件判断函数
  /// [start] - 起始查找索引（默认0）
  /// 返回：元素的索引（不存在则返回-1）
  @override
  int indexWhere(bool Function(E element) test, [int start = 0]) => toList().indexWhere(test, start);

  /// 插入元素到指定位置
  /// [index] - 插入位置
  /// [element] - 待插入的元素
  @override
  void insert(int index, E element) {
    purge();
    _inner.insert(index, WeakReference(element));
  }

  /// 批量插入元素到指定位置
  /// [index] - 插入起始位置
  /// [iterable] - 待插入的元素集合
  @override
  void insertAll(int index, Iterable<E> iterable) {
    purge();
    for(var item in iterable){
      _inner.insert(index, WeakReference(item));
      index += 1;
    }
  }

  /// 拼接所有元素为字符串
  /// [separator] - 分隔符（默认空字符串）
  /// 返回：拼接后的字符串
  @override
  String join([String separator = ""]) => toList().join(separator);

  /// 查找元素的最后一个索引
  /// [element] - 待查找的元素
  /// [start] - 起始查找索引（可选）
  /// 返回：元素的最后一个索引（不存在则返回-1）
  @override
  int lastIndexOf(E element, [int? start]) => toList().lastIndexOf(element, start);

  /// 查找最后一个满足条件的元素索引
  /// [test] - 条件判断函数
  /// [start] - 起始查找索引（可选）
  /// 返回：元素的最后一个索引（不存在则返回-1）
  @override
  int lastIndexWhere(bool Function(E element) test, [int? start]) => toList().lastIndexWhere(test, start);

  /// 查找最后一个满足条件的元素
  /// [test] - 条件判断函数
  /// [orElse] - 无符合条件元素时的回调（可选）
  /// 返回：最后一个符合条件的元素
  @override
  E lastWhere(bool Function(E element) test, {E Function()? orElse}) => toList().lastWhere(test,orElse: orElse);

  /// 转换元素为新的迭代器
  /// [toElement] - 转换函数
  /// [T] - 转换后的元素类型
  /// 返回：转换后的迭代器
  @override
  Iterable<T> map<T>(T Function(E element) toElement) => toList().map(toElement);

  /// 归约元素为单个值
  /// [combine] - 归约函数
  /// 返回：归约结果
  @override
  E reduce(E Function(E value, E element) combine) => toList().reduce(combine);

  /// 移除第一个指定元素
  /// [value] - 待移除的元素
  /// 返回：是否成功移除
  @override
  bool remove(Object? value) {
    /// 从列表中移除第一个出现的[value]
    for(var wr in _inner){
      if(wr.target == value)
      {
        return _inner.remove(wr);
      }
    }
    return false;
  }

  /// 移除指定索引的元素
  /// [index] - 索引位置
  /// 返回：被移除的元素
  @override
  E removeAt(int index) {
    purge();
    var wr = _inner.removeAt(index);
    return wr.target as E;
  }

  /// 移除最后一个元素
  /// 返回：被移除的元素
  @override
  E removeLast() {
    purge();
    var wr = _inner.removeLast();
    return wr.target;
  }

  /// 移除指定范围的元素
  /// [start] - 起始索引（包含）
  /// [end] - 结束索引（不包含）
  @override
  void removeRange(int start, int end) {
    purge();
    _inner.removeRange(start, end);
  }

  /// 移除所有满足条件的元素
  /// [test] - 条件判断函数
  @override
  void removeWhere(bool Function(E element) test) {
    _inner.removeWhere((element){
      E? item = element.target;
      // 移除已被GC回收的元素，或满足条件的元素
      return item == null || test(item);
    });
  }

  /// 替换指定范围的元素
  /// [start] - 起始索引（包含）
  /// [end] - 结束索引（不包含）
  /// [replacements] - 替换的元素集合
  @override
  void replaceRange(int start, int end, Iterable<E> replacements) {
    purge();
    /// 用[replacements]中的元素替换指定范围的元素
    /// 步骤： 1.移除[start]到[end]的元素；2.在[start]位置插入[replacements]的元素
    _inner.removeRange(start, end);
    int index = start;
    for(var item in replacements){
      _inner.insert(index, WeakReference(item));
      index += 1;
    }
  }

  /// 保留所有满足条件的元素
  /// [test] - 条件判断函数
  @override
  void retainWhere(bool Function(E element) test) => toList().retainWhere(test);

  /// 获取反向迭代器
  /// 返回：反向的有效元素迭代器
  @override
  Iterable<E> get reversed => toList().reversed;

  /// 批量覆盖指定位置的元素
  /// [index] - 起始覆盖位置
  /// [iterable] - 覆盖的元素集合
  @override
  void setAll(int index, Iterable<E> iterable){
    purge();
    /// 用[iterable]的元素覆盖列表中的元素
    /// 从[index]位置开始写入，不增加列表长度
    /// 要求：[index]非负且不超过列表长度；[iterable]元素数量不超过剩余位置
    for (var item in iterable)
    {
      _inner[index] = WeakReference(item);
      index += 1;
    }
  }

  /// 将[iterable]的部分元素写入指定范围
  /// [start] - 列表起始位置（包含）
  /// [end] - 列表结束位置（不包含）
  /// [iterable] - 待写入的元素集合
  /// [skipCount] - 跳过的元素数量（默认0）
  @override
  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]){
    purge();
    /// 将[iterable]的元素（跳过前[skipCount]个）写入列表的[start]到[end]范围
    for(E item in iterable)
    {
     if(skipCount > 0)
     {
      skipCount -= 1;
      continue;
     }else if(start >= end)
     {
      break;
     }
     _inner[start] = WeakReference(item);
     start += 1;
    }
  }

  /// 随机打乱列表元素
  /// [random] - 随机数生成器（可选）
  @override
  void shuffle([Random? random]) => _inner.shuffle(random);

  /// 查找唯一满足条件的元素（列表需仅有一个符合条件的元素）
  /// [test] - 条件判断函数
  /// [orElse] - 无符合条件元素时的回调（可选）
  /// 返回：唯一符合条件的元素
  @override
  E singleWhere(bool Function(E element) test, {E Function()? orElse}) => toList().singleWhere(test,orElse: orElse);

  /// 跳过前[count]个元素
  /// [count] - 跳过的数量
  /// 返回：剩余的有效元素迭代器
  @override
  Iterable<E> skip(int count) => toList().skip(count);

  /// 跳过满足条件的元素，直到第一个不满足条件的元素
  /// [test] - 条件判断函数
  /// 返回：剩余的有效元素迭代器
  @override
  Iterable<E> skipWhile(bool Function(E element) test) => toList().skipWhile(test);

  /// 跳过满足条件的元素，直到第一个不满足条件的元素
  /// [test] - 条件判断函数
  /// 返回：剩余的有效元素迭代器
  @override
  void sort([int Function(E a, E b)? compare]){
    purge();
    if(compare == null){
      // 待实现：默认比较函数？
      // TODO: default compare function?
      _inner.sort();
    }else{
      // 提取弱引用的target后进行比较
      _inner.sort((a,b)=>compare(a.target,b.target));
    }
  }

  /// 获取子列表
  /// [start] - 起始索引（包含）
  /// [end] - 结束索引（可选，默认到末尾）
  /// 返回：子列表（普通List）
  @override
  List<E> sublist(int start, [int? end]) => toList().sublist(start,end);

  /// 获取前[count]个元素
  /// [count] - 获取的数量
  /// 返回：前count个有效元素迭代器
  @override
  Iterable<E> take(int count) => toList().take(count);

  /// 获取满足条件的元素，直到第一个不满足条件的元素
  /// [test] - 条件判断函数
  /// 返回：符合条件的有效元素迭代器
  @override
  Iterable<E> takeWhile(bool Function(E element) test) => toList().takeWhile(test);

  /// 过滤满足条件的元素
  /// [test] - 条件判断函数
  /// 返回：符合条件的有效元素迭代器
  @override
  Iterable<E> where(bool Function(E element) test) => toList().where(test);

  /// 过滤指定类型的元素
  /// [T] - 目标类型
  /// 返回：指定类型的有效元素迭代器
  @override
  Iterable<T> whereType<T>() => toList().whereType<T>();



}