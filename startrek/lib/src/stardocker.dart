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
import 'dart:io'; // 基础IO库（SocketException等）
import 'dart:typed_data'; // 字节数组（Uint8List）

import 'net/connection.dart'; // 底层网络连接抽象（TCP/UDP等连接的统一封装）
import 'nio/exception.dart'; // 框架自定义IO异常类
import 'port/docker.dart'; // 消息管理核心：Dock（码头），管理待发送/待接收的消息
import 'port/ship.dart'; // 消息载体：Ship（Departure=待发送消息，Arrival=待接收消息）
import 'type/pair.dart'; // 地址对封装（远程地址/本地地址）
import 'dock.dart'; // Dock（码头）接口定义

/// Star Trek框架核心传输抽象类
/// 作用：封装网络连接，实现可靠的异步消息传输（分片、确认、重试、异常处理）
abstract class StarPorter extends AddressPairObject implements Porter {
  /// 构造方法
  /// [remote]：远程地址（对端地址）
  /// [local]：本地地址（本端绑定地址）
  StarPorter({super.remote, super.local}) {
    // 初始化消息管理的“码头”（Dock），负责存储待发送/待接收的消息
    _dock = createDock();
  }

  /// 消息管理核心：Dock（码头），用于存储待发送的消息、组装接收的分片消息
  late final Dock _dock;

  /// 底层网络连接的弱引用（避免内存泄漏）
  WeakReference<Connection>? _connectionRef;

  /// 事件回调代理的弱引用（上层业务通过该代理接收传输事件）
  WeakReference<PorterDelegate>? _delegateRef;

  /// 上一次未发送完成的待发送消息（用于断点续发）
  Departure? _lastOutgo;

  /// 上一次未发送完成的消息分片（用于断点续发）
  List<Uint8List> _lastFragments = [];

  // 【受保护方法】创建消息管理的Dock（码头）
  // 子类可重写该方法，自定义Dock实现（比如自定义消息存储规则）
  Dock createDock() => LockedDock(); // 默认创建线程安全的LockedDock

  // 【代理管理】获取传输事件回调代理
  PorterDelegate? get delegate => _delegateRef?.target;
  // 设置传输事件回调代理（使用弱引用，避免内存泄漏）
  set delegate(PorterDelegate? keeper) =>
      _delegateRef = keeper == null ? null : WeakReference(keeper);

  // ---------------------------------------------------------------------------
  //  网络连接管理
  // ---------------------------------------------------------------------------

  /// 获取当前绑定的底层网络连接
  Connection? get connection => _connectionRef?.target;

  // 【受保护方法】设置/替换底层网络连接
  // [conn]：新的网络连接（null表示关闭连接）
  Future<void> setConnection(Connection? conn) async {
    // 1. 取出旧连接
    Connection? old = _connectionRef?.target;
    // 2. 绑定新连接（弱引用）
    if (conn != null) {
      _connectionRef = WeakReference(conn);
    }
    // 3. 关闭旧连接（避免连接泄露）
    if (old == null || identical(old, conn)) {
      // 无旧连接 或 新旧连接是同一个，无需处理
    } else {
      await old.close();
    }
  }

  // ---------------------------------------------------------------------------
  //  连接状态判断
  // ---------------------------------------------------------------------------

  /// 判断当前传输端口是否已关闭
  @override
  bool get isClosed {
    if (_connectionRef == null) {
      // 连接引用为空，说明还在初始化阶段，未关闭
      return false;
    }
    // 底层连接的isClosed为false时，才表示未关闭
    return connection?.isClosed != false;
  }

  /// 判断当前传输端口是否存活（连接可用）
  @override
  bool get isAlive => connection?.isAlive == true;

  /// 获取当前传输端口的状态（封装为PorterStatus枚举）
  @override
  PorterStatus get status => PorterStatus.getStatus(connection?.state);

  /// 重写toString，便于日志打印（显示地址和连接信息）
  @override
  String toString() {
    String clazz = className;
    return '<$clazz remote="$remoteAddress" local="$localAddress">\n\t'
        '$connection\n</$clazz>';
  }

  // ---------------------------------------------------------------------------
  //  消息发送
  // ---------------------------------------------------------------------------

  /// 提交待发送的消息（Ship）到码头，等待发送
  /// [ship]：待发送的消息载体（Departure）
  /// 返回：是否成功提交到码头
  @override
  Future<bool> sendShip(Departure ship) async => _dock.addDeparture(ship);

  // ---------------------------------------------------------------------------
  //  消息接收处理
  // ---------------------------------------------------------------------------

  /// 处理底层连接接收到的原始字节数据
  /// [data]：底层连接读取到的原始字节数组
  @override
  Future<void> processReceived(Uint8List data) async {
    // 1. 将原始字节数据解析为待接收消息载体（Arrival）列表
    List<Arrival> ships = getArrivals(data);
    if (ships.isEmpty) {
      // 解析不到完整的消息片段，等待后续数据（粘包/拆包场景）
      return;
    }
    // 获取回调代理（上层业务处理消息）
    PorterDelegate? keeper = delegate;
    Arrival? income;
    // 2. 遍历解析出的待接收消息，逐个处理
    for (Arrival item in ships) {
      // 检查并组装消息（处理分片、响应确认）
      income = await checkArrival(item);
      if (income == null) {
        // 消息分片不完整，等待后续分片
        continue;
      }
      // 3. 回调上层业务：处理组装完成的完整消息
      await keeper?.onPorterReceived(income, this);
    }
  }

  /// 【抽象方法】将原始字节数据解析为待接收消息载体（Arrival）列表
  /// 子类必须实现：根据协议规则解析原始数据（处理粘包/拆包、分片）
  /// [data]：底层接收的原始字节数组
  /// 返回：解析出的待接收消息列表
  List<Arrival> getArrivals(Uint8List data);

  /// 【抽象方法】检查待接收消息，确认是否组装完成
  /// 子类必须实现：处理消息分片组装、响应确认等逻辑
  /// [income]：待检查的接收消息载体
  /// 返回：组装完成的完整消息（null表示分片不完整）
  Future<Arrival?> checkArrival(Arrival income);

  /// 检查接收的消息是否是待发送消息的响应（通过SN序列号匹配）
  /// [income]：包含响应信息的接收消息载体
  /// 返回：匹配到的已完成发送的消息（Departure）
  Future<Departure?> checkResponse(Arrival income) async {
    // 根据SN序列号，检查码头中是否有对应的待发送消息
    Departure? linked = _dock.checkResponse(income);
    if (linked == null) {
      // 未找到匹配的待发送消息，或消息未全部发送完成
      return null;
    }
    // 匹配到响应：消息已成功送达，回调上层业务
    await delegate?.onPorterSent(linked, this);
    return linked;
  }

  /// 组装接收的消息分片，生成完整的消息
  /// [income]：待组装的消息分片（Arrival）
  /// 返回：组装完成的完整消息（null表示分片不全）
  Arrival? assembleArrival(Arrival income) => _dock.assembleArrival(income);

  // ---------------------------------------------------------------------------
  //  消息发送调度
  // ---------------------------------------------------------------------------

  /// 从码头获取下一个待发送的消息（处理超时、优先级）
  /// [now]：当前时间（用于判断超时）
  /// 返回：下一个待发送的消息（null表示无待发送消息）
  Departure? getNextDeparture(DateTime now) => _dock.getNextDeparture(now);

  /// 清理码头中超时的消息（待发送/待接收）
  /// [now]：当前时间（默认取系统当前时间）
  /// 返回：清理的消息数量
  @override
  int purge([DateTime? now]) => _dock.purge(now);

  /// 关闭传输端口（释放连接、清理资源）
  @override
  Future<void> close() async => await setConnection(null);

  // ---------------------------------------------------------------------------
  //  核心处理逻辑（发送调度）
  // ---------------------------------------------------------------------------

  /// 核心处理方法：调度发送待发送的消息（框架循环调用）
  /// 返回：是否有处理过消息（true=继续调度，false=无消息可发，可休眠）
  @override
  Future<bool> process() async {
    // 1. 获取当前可用的底层连接
    Connection? conn = connection;
    if (conn == null) {
      // 无可用连接，等待连接建立
      return false;
    } else if (!conn.isVacant) {
      // 连接不可写（缓冲区满/正在发送），等待连接就绪
      return false;
    }

    // 2. 获取待发送的消息和分片（优先处理上一次未发完的）
    Departure? outgo = _lastOutgo;
    List<Uint8List> fragments = _lastFragments;
    if (outgo != null && fragments.isNotEmpty) {
      // 有上一次未发完的消息分片，取出继续发送
      _lastOutgo = null;
      _lastFragments = [];
    } else {
      // 无残留分片，从码头获取下一个待发送消息
      DateTime now = DateTime.now();
      outgo = getNextDeparture(now);
      if (outgo == null) {
        // 码头无待发送消息，返回false让调度线程休眠
        return false;
      } else if (outgo.getStatus(now) == ShipStatus.failed) {
        // 消息超时失败，回调上层业务
        await delegate?.onPorterFailed(IOError('Request timeout'), outgo, this);
        // 返回true，继续处理下一个消息
        return true;
      } else {
        // 获取消息的分片列表（大数据包分片发送）
        fragments = outgo.fragments;
        if (fragments.isEmpty) {
          // 该消息的所有分片已发送完成，返回true处理下一个
          return true;
        }
      }
    }

    // 3. 发送消息分片
    IOError error;
    int index = 0, sent = 0;
    try {
      // 遍历分片逐个发送
      for (Uint8List fra in fragments) {
        // 调用底层连接发送分片数据
        sent = await conn.sendData(fra);
        if (sent < fra.length) {
          // 发送长度不足（缓冲区满），中断发送，保留剩余分片
          break;
        } else {
          // 断言：分片应完整发送（调试用，生产环境可移除）
          assert(
            sent == fra.length,
            'length of fragment sent error: $sent, ${fra.length}',
          );
          index += 1; // 已发送分片计数+1
          sent = 0; // 清空发送长度计数器
        }
      }
      // 检查分片发送结果
      if (index < fragments.length) {
        // 部分分片未发送，抛出异常
        throw SocketException(
          'only $index/${fragments.length} fragments sent.',
        );
      } else {
        // 所有分片发送完成
        if (outgo.isImportant) {
          // 重要消息：需要等待对端响应，暂不回调onPorterSent
        } else {
          // 非重要消息：直接回调上层，通知发送完成
          await delegate?.onPorterSent(outgo, this);
        }
        return true;
      }
    } on IOException catch (ex) {
      // 捕获发送过程中的IO异常（连接断开/超时等）
      error = IOError(ex);
    }

    // 4. 处理发送失败：移除已发送的分片，保留未发送的
    for (; index > 0; --index) {
      fragments.removeAt(0); // 移除已发送的分片
    }
    // 处理最后一个分片的部分发送（比如发了一半中断）
    if (sent > 0) {
      Uint8List last = fragments.removeAt(0);
      // 保留未发送的部分，下次继续发送
      fragments.insert(0, last.sublist(sent));
    }

    // 5. 存储未发送完成的消息和分片，供下次续发
    _lastOutgo = outgo;
    _lastFragments = fragments;

    // 6. 回调上层业务：通知发送异常
    await delegate?.onPorterError(error, outgo, this);
    return false;
  }
}
