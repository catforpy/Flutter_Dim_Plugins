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

/* license: https://mit-license.org
 *
 *  Star Trek: Interstellar Transport
 *
 *                               Written in 2024 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2024 Albert Moky
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
import 'dart:typed_data';        // 字节数组（Uint8List）

import 'net/connection.dart';    // 底层网络连接抽象
import 'net/state.dart';         // 连接状态枚举（ConnectionState）
import 'nio/address.dart';       // 网络地址封装（SocketAddress）
import 'nio/exception.dart';     // 框架自定义IO异常
import 'port/docker.dart';       // Porter（传输端口）接口
import 'port/gate.dart';         // Gate（网关）接口
import 'port/ship.dart';         // 消息载体（Departure/Arrival）
import 'type/mapping.dart';      // 地址对映射（AddressPairMap）

import 'stardocker.dart';        // StarPorter（具体的传输端口实现）


/// 传输端口（Porter）缓存池
/// 核心：基于「本地地址+远程地址」的键值对，管理所有Porter实例的增删查
class PorterPool extends AddressPairMap<Porter> {

  /// 重写：设置Porter到缓存池（覆盖父类逻辑，增加旧Porter清理）
  /// [value]：要存入的Porter实例
  /// [remote]：远程地址（键的一部分）
  /// [local]：本地地址（键的一部分）
  /// 返回：被替换掉的旧Porter实例
  @override
  Porter? setItem(Porter? value, {SocketAddress? remote, SocketAddress? local}) {
    // 1. 先移除缓存中已有的同名Porter（避免重复）
    Porter? cached = super.removeItem(value, remote: remote, local: local);
    // （注：注释部分是旧逻辑，原本要关闭旧Porter，现在暂时注释）
    // if (cached == null || identical(cached, value)) {} else {
    //   /*await */cached.close();
    // }
    // 2. 将新Porter存入缓存池
    Porter? old = super.setItem(value, remote: remote, local: local);
    // 断言：理论上旧值应为null（因为第一步已移除），防止逻辑错误
    assert(old == null, 'should not happen');
    // 返回被移除的旧Porter
    return cached;
  }

  // （注：注释的removeItem是旧逻辑，原本移除时会关闭Porter，现在暂时注释）
  // @override
  // Porter? removeItem(Porter? value, {SocketAddress? remote, SocketAddress? local}) {
  //   Porter? cached = super.removeItem(value, remote: remote, local: local);
  //   if (cached == null || identical(cached, value)) {} else {
  //     /*await */cached.close();
  //   }
  //   if (value == null) {} else {
  //     /*await */value.close();
  //   }
  //   return cached;
  // }

}


/// Star Trek框架的核心网关抽象类
/// 作用：
/// 1. 作为底层连接（Connection）和上层业务的中间层；
/// 2. 管理所有Porter实例（通过PorterPool）；
/// 3. 转发发送请求、处理连接事件、调度Porter的消息发送/清理。
abstract class StarGate implements Gate, ConnectionDelegate {
  /// 构造方法：初始化Porter缓存池
  StarGate() {
    _porterPool = createPorterPool();
  }

  /// 【受保护方法】创建Porter缓存池（子类可重写，自定义池实现）
  /// 返回：默认创建PorterPool实例
  AddressPairMap<Porter> createPorterPool() => PorterPool();

  /// Porter缓存池实例（核心：管理所有Porter）
  late final AddressPairMap<Porter> _porterPool;
  /// 传输事件回调代理的弱引用（上层业务通过该代理接收事件）
  WeakReference<PorterDelegate>? _delegateRef;

  /// 获取传输事件回调代理
  PorterDelegate? get delegate => _delegateRef?.target;
  /// 设置传输事件回调代理（弱引用避免内存泄漏）
  set delegate(PorterDelegate? keeper) =>
      _delegateRef = keeper == null ? null : WeakReference(keeper);

  // ---------------------------------------------------------------------------
  //  实现Gate接口：上层业务发送原始字节数据
  // ---------------------------------------------------------------------------

  /// 发送原始字节数据到指定地址
  /// [payload]：要发送的原始字节数组
  /// [remote]：必填，远程目标地址
  /// [local]：可选，本地绑定地址
  /// 返回：是否发送成功
  @override
  Future<bool> sendData(Uint8List payload, {required SocketAddress remote, SocketAddress? local}) async {
    // 1. 根据地址对获取对应的Porter实例
    Porter? worker = getPorter(remote: remote, local: local);
    if (worker == null) {
      // 断言：未找到Porter（开发期提示，生产环境可移除）
      assert(false, 'porter not found: $local -> $remote');
      return false;
    } else if (!worker.isAlive) {
      // 断言：Porter未存活（连接不可用）
      assert(false, 'porter not alive: $local -> $remote');
      return false;
    }
    // 2. 转发给Porter发送数据
    return await worker.sendData(payload);
  }

  /// 发送封装后的消息载体（Departure）到指定地址
  /// [outgo]：待发送的消息载体（已封装分片、序列号等）
  /// [remote]：必填，远程目标地址
  /// [local]：可选，本地绑定地址
  /// 返回：是否成功提交到Porter的发送队列
  @override
  Future<bool> sendShip(Departure outgo, {required SocketAddress remote, SocketAddress? local}) async {
    // 1. 根据地址对获取对应的Porter实例
    Porter? worker = getPorter(remote: remote, local: local);
    if (worker == null) {
      assert(false, 'porter not found: $local -> $remote');
      return false;
    } else if (!worker.isAlive) {
      assert(false, 'porter not alive: $local -> $remote');
      return false;
    }
    // 2. 转发给Porter提交消息（入队等待发送）
    return await worker.sendShip(outgo);
  }

  // ---------------------------------------------------------------------------
  //  Porter管理：创建/获取/设置/移除
  // ---------------------------------------------------------------------------

  /// 【抽象方法】创建新的Porter实例（子类必须实现）
  /// 用于为新的连接/新的地址对创建对应的传输端口
  /// [remote]：远程地址
  /// [local]：本地地址
  /// 返回：新创建的Porter实例
  Porter createPorter({required SocketAddress remote, SocketAddress? local});

  /// 获取缓存池中所有的Porter实例
  /// 返回：Porter实例的可遍历集合
  Iterable<Porter> allPorters() => _porterPool.items;

  /// 根据地址对获取缓存中的Porter实例
  /// [remote]：必填，远程地址
  /// [local]：可选，本地地址
  /// 返回：匹配的Porter（null表示未找到）
  Porter? getPorter({required SocketAddress remote, SocketAddress? local}) =>
      _porterPool.getItem(remote: remote, local: local);

  /// 将Porter实例存入缓存池
  /// [porter]：要存入的Porter
  /// [remote]：必填，远程地址（键）
  /// [local]：可选，本地地址（键）
  /// 返回：被替换的旧Porter实例
  Porter? setPorter(Porter porter, {required SocketAddress remote, SocketAddress? local}) =>
      _porterPool.setItem(porter, remote: remote, local: local);

  /// 从缓存池移除指定地址对的Porter实例
  /// [porter]：要移除的Porter（可选，主要靠地址匹配）
  /// [remote]：必填，远程地址
  /// [local]：可选，本地地址
  /// 返回：被移除的Porter实例
  Porter? removePorter(Porter? porter, {required SocketAddress remote, SocketAddress? local}) =>
      _porterPool.removeItem(porter, remote: remote, local: local);

  /// 核心方法：为连接绑定/创建对应的Porter（码头停靠逻辑）
  /// [connection]：底层网络连接
  /// [newPorter]：是否允许创建新Porter（false则只查不创建）
  /// 返回：绑定后的Porter实例（null表示失败）
  Future<Porter?> dock(Connection connection, bool newPorter) async {
    // 0. 前置检查：获取连接的地址信息
    SocketAddress? remote = connection.remoteAddress;
    SocketAddress? local = connection.localAddress;
    if (remote == null) {
      // 远程地址不能为空（断言：开发期提示）
      assert(false, 'remote address should not empty');
      return null;
    }
    Porter? worker, cached;

    // 1. 尝试从缓存池获取已有Porter
    worker = getPorter(remote: remote, local: local);
    if (worker != null) {
      // 找到已有Porter，直接返回
      return worker;
    } else if (!newPorter) {
      // 不允许创建新Porter，返回null
      return null;
    }

    // 2. 创建新的Porter实例（调用子类实现的createPorter）
    worker = createPorter(remote: remote, local: local);
    // 将新Porter存入缓存池（返回被替换的旧Porter）
    cached = setPorter(worker, remote: remote, local: local);
    // 如果有旧Porter且不是当前新Porter，关闭旧Porter（避免连接泄露）
    if (cached == null || identical(cached, worker)) {} else {
      await cached.close();
    }

    // 3. 为新Porter绑定底层连接
    if (worker is StarPorter) {
      // StarPorter是具体实现，调用其setConnection绑定连接
      await worker.setConnection(connection);
    } else {
      // 断言：Porter类型错误（开发期提示）
      assert(false, 'porter error: $remote, $worker');
    }

    return worker;
  }

  // ---------------------------------------------------------------------------
  //  核心调度：驱动所有Porter处理消息发送、清理超时资源
  // ---------------------------------------------------------------------------

  /// 实现Gate接口：框架循环调用的核心处理方法
  /// 作用：1. 驱动所有Porter发送消息；2. 清理超时/关闭的Porter
  /// 返回：是否有Porter在处理消息（true=继续调度，false=可休眠）
  @override
  Future<bool> process() async {
    // 获取所有Porter实例
    Iterable<Porter> dockers = allPorters();
    // 1. 驱动所有Porter处理消息发送
    int count = await drivePorters(dockers);
    // 2. 清理超时/关闭的Porter、超时消息
    await cleanupPorters(dockers);
    // 返回是否有活跃的Porter（count>0表示有Porter在处理消息）
    return count > 0;
  }

  /// 【受保护方法】驱动所有Porter处理消息发送（异步批量处理）
  /// [porters]：待驱动的Porter集合
  /// 返回：活跃的Porter数量（正在处理消息的数量）
  Future<int> drivePorters(Iterable<Porter> porters) async {
    int count = 0;
    List<Future<bool>> futures = [];
    Future<bool> task;

    // 1. 为每个Porter创建发送任务（调用Porter的process方法）
    for (Porter worker in porters) {
      task = worker.process();
      futures.add(task);
    }

    // 2. 等待所有Porter的发送任务完成
    List<bool> results = await Future.wait(futures);

    // 3. 统计活跃的Porter数量（返回true表示该Porter有消息处理）
    for (bool busy in results) {
      if (busy) {
        count += 1;
      }
    }

    return count;
  }

  /// 【受保护方法】清理Porter资源（超时消息、关闭的Porter）
  /// [porters]：待清理的Porter集合
  Future<void> cleanupPorters(Iterable<Porter> porters) async {
    DateTime now = DateTime.now();
    Porter? cached;

    // 遍历所有Porter，逐个清理
    for (Porter worker in porters) {
      if (!worker.isClosed) {
        // Porter未关闭：清理其内部超时的消息（待发送/待接收）
        worker.purge(now);
        continue;
      }

      // Porter已关闭：从缓存池移除，并关闭资源
      cached = removePorter(worker, remote: worker.remoteAddress!, local: worker.localAddress);
      if (cached == null || identical(cached, worker)) {} else {
        await cached.close();
      }
    }
  }

  /// 【受保护方法】发送心跳包到指定连接（保活）
  /// [connection]：需要保活的底层连接
  Future<void> heartbeat(Connection connection) async {
    SocketAddress remote = connection.remoteAddress!;
    SocketAddress? local = connection.localAddress;
    // 获取该连接对应的Porter，调用其heartbeat方法发送心跳
    Porter? worker = getPorter(remote: remote, local: local);
    await worker?.heartbeat();
  }

  // ---------------------------------------------------------------------------
  //  实现ConnectionDelegate：监听底层连接的事件
  // ---------------------------------------------------------------------------

  /// 连接状态变化回调
  /// [previous]：旧状态
  /// [current]：新状态
  /// [connection]：状态变化的连接
  @override
  Future<void> onConnectionStateChanged(ConnectionState? previous, ConnectionState? current, Connection connection) async {
    // 1. 将连接状态转换为Porter状态枚举
    PorterStatus s1 = PorterStatus.getStatus(previous);
    PorterStatus s2 = PorterStatus.getStatus(current);

    // 2. 状态变化时的回调逻辑
    if (s1 != s2) {
      // 是否需要创建新Porter：状态不是error时，允许创建
      bool notFinished = s2 != PorterStatus.error;
      // 为连接绑定/创建Porter
      Porter? worker = await dock(connection, notFinished);
      if (worker == null) {
        // 连接已关闭且Porter已移除，无需处理
        return;
      }
      // 回调上层业务：Porter状态变化
      await delegate?.onPorterStatusChanged(s1, s2, worker);
    }

    // 3. 连接过期时发送心跳包（保活）
    if (current?.index == ConnectionStateOrder.expired.index) {
      await heartbeat(connection);
    }
  }

  /// 连接接收到数据的回调
  /// [data]：接收到的原始字节数据
  /// [connection]：接收数据的连接
  @override
  Future<void> onConnectionReceived(Uint8List data, Connection connection) async {
    // 为连接绑定/创建Porter（允许创建新Porter）
    Porter? worker = await dock(connection, true);
    if (worker == null) {
      // 断言：创建Porter失败（开发期提示）
      assert(false, 'failed to create porter: $connection');
    } else {
      // 转发数据到Porter处理（解析、组装、回调上层）
      await worker.processReceived(data);
    }
  }

  /// 连接发送数据成功的回调（框架暂忽略该事件）
  @override
  Future<void> onConnectionSent(int sent, Uint8List data, Connection connection) async {
    // ignore event for sending success
  }

  /// 连接发送数据失败的回调（框架暂忽略该事件）
  @override
  Future<void> onConnectionFailed(IOError error, Uint8List data, Connection connection) async {
    // ignore event for sending failed
  }

  /// 连接接收数据出错的回调（框架暂忽略该事件）
  @override
  Future<void> onConnectionError(IOError error, Connection connection) async {
    // ignore event for receiving error
  }

}