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


import 'package:object_key/object_key.dart';
import 'package:startrek/nio.dart';

/// 键值对映射接口（PairMap）
/// 核心抽象：定义「双Key（remote+local）→ Value」的映射规则，适配网络资源（连接/通道）的地址维度管理
/// 泛型说明：K=地址类型（SocketAddress），V=映射值（Connection/Channel）
abstract interface class PairMap<K, V> {

  /// 获取所有映射值
  /// @return 所有已缓存的Value集合（不可变/副本，避免外部修改内部状态）
  Iterable<V> get items;

  /// 根据地址对获取映射值
  /// @param remote - 远程地址（可选，与local二选一必填）
  /// @param local  - 本地地址（可选，与remote二选一必填）
  /// @return 匹配的Value（null表示无匹配）
  V? getItem({K? remote, K? local});

  /// 设置地址对的映射值
  /// @param remote - 远程地址（可选）
  /// @param local  - 本地地址（可选）
  /// @param value  - 待映射的Value（null表示移除该地址对的映射）
  /// @return 被替换的旧Value（null表示无旧值）
  V? setItem(V? value, {K? remote, K? local});

  /// 移除地址对的映射值
  /// @param remote - 远程地址（可选）
  /// @param local  - 本地地址（可选）
  /// @param value  - 待移除的Value（可选，用于校验）
  /// @return 被移除的Value（null表示无匹配）
  V? removeItem(V? value, {K? remote, K? local});
}


/// 键值对映射抽象实现（核心：多级Map结构）
/// 实现逻辑：用 `Map<K, Map<K, V>>` 实现「双Key映射」，第一层Key=remote/local，第二层Key=local/默认值
abstract class AbstractPairMap<K,V> implements PairMap<K,V>{
  AbstractPairMap(this._defaultKey);

  /// 默认Key（用于匹配「仅指定remote/local」的场景，如 (remote, null) → Value）
  final K _defaultKey;

  /// 核心存储结构：多级Map
  /// 第一层Key：remote地址 / local地址
  /// 第二层Key：local地址 / _defaultKey（当local为null时）
  /// 示例：
  ///   _map[remote1][local1] = conn1  → (remote1, local1) 对应 conn1
  ///   _map[remote1][_defaultKey] = conn2 → (remote1, null) 对应 conn2
  ///   _map[local2][_defaultKey] = conn3 → (null, local2) 对应 conn3
  final Map<K,Map<K,V>> _map = {};

  /// 根据地址对获取映射值（核心匹配逻辑）
  @override
  V? getItem({K? remote,K? local}){
    K? key1,key2;
    if(remote == null)
    {
      // 场景1:仅指定local地址(如UDP绑定本地端口)
      assert(local != null,'local & remote addresses should not empty at the same time');
      key1 = local;
      key2 = null;
    }else{
      // 场景2: 指定remote地址(可选带local)
      key1 = remote;
      key2 = local;
    }

    // 第一步：获取第一层Map(key1对应的二级Map)
    Map<K,V>? table = _map[key1];
    if(table == null)
    {
      return null;
    }

    V? value;
    if(key2 != null)
    {
      // 子场景2.1：指定(remote,local) ->精准匹配
      value = table[key2];
      if(value != null)
      {
        return value;
      }
      // 精准匹配失败 -> 降级匹配该remote下的默认值
      return table[_defaultKey];
    }

    // 子场景2.1：仅指定remote/local ->先匹配默认值
    value = table[_defaultKey];
    if(value != null)
    {
      return value;
    }

    // 默认值匹配失败 -> 取该key1下任意非空value(兜底逻辑)
    for(V? v in table.values)
    {
      if(v != null){
        return v;
      }
    }
    return null;
  }

  ///设置地址对的映射值(核心存储逻辑)
  @override
  V? setItem(V? value,{K? remote,K? local}){
    // 第一步：确定两级key
    K? key1,key2;
    if(remote == null)
    {
      // 场景1：仅指定Local -> key1 = local, key2 = 默认值
      assert(local != null, 'local & remote addresses should not empty at the same time');
      key1 = local;
      key2 = _defaultKey;
    }else if(local == null){
      // 场景2： 仅指定remote -> key1 = remote ,key2 = 默认值
      key1 = remote;
      key2 = _defaultKey;
    }else{
      // 场景3： 指定(remote,local) -> 精准key
      key1 = remote;
      key2 = local;
    }

    // 第二步：操作二级Map
    Map<K,V>? table = _map[key1];
    if(table != null){
      if(value == null){
        // 子场景： value = null -> 移除该key的映射
        return table.remove(key2);
      }else{
        // 子场景：value 非空 -> 覆盖/新增映射
        V? old = table[key2!];
        table[key2] = value;
        return old;
      }
    }else if(value != null)
    {
      // 二级Mapu存在 且value 非空 -> 创建新二级Map并存储
      table = WeakValueMap();   //弱引用Map：避免Value内存泄漏
      table[key2!] = value;
      _map[key1!] = table;
    }
    return null;
  }

  /// 移除地址对的映射值(核心清理逻辑)
  @override
  V? removeItem(V? value,{K? remote,K? local}){
    // 第一步：确定两级Key（逻辑同setItem）
    K? key1,key2;
    if(remote == null){
      assert(local != null, 'local & remote addresses should not empty at the same time');
      key1 = local;
      key2 = _defaultKey;
    }else if(local == null)
    {
      key1 = remote;
      key2 = _defaultKey;
    }else{
      key1 = remote;
      key2 = local;
    }

    // 第二步：移除映射
    Map<K, V>? table = _map[key1];
    if (table == null) {
      return value;
    }
    V? old = table.remove(key2);

    // 第三步：清理空的二级Map（避免内存浪费）
    if (table.isEmpty) {
      _map.remove(key1);
    }

    // 返回移除的值（无则返回入参value，保持接口一致性）
    return old ?? value;
  }

}

/// 哈希型键值对映射（扩展AbstractPairMap）
/// 核心增强：维护Value集合，快速返回所有映射值（items）
class HashPairMap<K, V> extends AbstractPairMap<K, V> {
  HashPairMap(super.any);  // super.any → 传递_defaultKey

  /// 所有Value的缓存集合（避免每次items都遍历多级Map）
  final Set<V> _values = {};

  /// 获取所有映射值（返回副本，避免外部修改）
  @override
  Iterable<V> get items => Set<V>.from(_values);

  /// 重写setItem：同步维护_values集合
  @override
  V? setItem(V? value, {K? remote, K? local}) {
    if (value != null) {
      // 先移除旧值（避免重复）→ 再添加新值
      _values.remove(value);
      _values.add(value);
    }

    // 调用父类逻辑设置映射
    V? old = super.setItem(value, remote: remote, local: local);

    // 清理被替换的旧值
    if (old != null && old != value) {
      _values.remove(old);
    }
    return old;
  }

  /// 重写removeItem：同步维护_values集合
  @override
  V? removeItem(V? value, {K? remote, K? local}) {
    // 调用父类逻辑移除映射
    V? old = super.removeItem(value, remote: remote, local: local);

    // 清理移除的旧值
    if (old != null) {
      _values.remove(old);
    }
    // 清理入参指定的value（兜底）
    if (value != null && value != old) {
      _values.remove(value);
    }
    return old ?? value;
  }

}

/// 地址对映射（专属SocketAddress的HashPairMap）
/// 核心：定制默认Key为「0.0.0.0:0」（任意地址），适配网络地址场景
class AddressPairMap<V> extends HashPairMap<SocketAddress, V> {
  AddressPairMap() : super(anyAddress);  // super传递默认Key=anyAddress

  /// 全局默认地址（0.0.0.0:0）：匹配「未指定具体local/remote」的场景
  static final SocketAddress anyAddress = InetSocketAddress('0.0.0.0', 0);

}