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

import 'package:stargate/startrek.dart';

/// 通道池（核心：管理Channel的缓存）
/// 继承自AddressPairMap：按远程/本地地址对存储Channel
class ChannelPool extends AddressPairMap<Channel>{
  
  /// 设置Channel（重写父类方法）
  /// 核心逻辑：先移除旧Channel，再设置新Channel
  @override
  Channel? setItem(Channel? value, {SocketAddress? remote, SocketAddress? local}) {
    // 移除缓存的Channel
    Channel? cached = super.removeItem(value, remote: remote, local: local);
    // 注释：原代码计划关闭旧Channel，暂未实现
    // if (cached == null || identical(cached, value)) {} else {
    //   /*await */cached.close();
    // }
    // 设置新Channel
    Channel? old = super.setItem(value, remote: remote, local: local);
    // 断言：旧值必须为null（避免重复设置）
    assert(old == null, 'should not happen');
    return cached;
  }


}


/// 通用Hub（连接管理器抽象类）
/// 核心职责：
/// 1. 管理Channel的创建/获取/移除；
/// 2. 封装ChannelPool，实现Channel的缓存管理；
/// 3. 定义打开Socket Channel的核心接口；
abstract class CommonHub extends BaseHub{
  CommonHub() {
    // 初始化通道池
    _channelPool = createChannelPool();
  }

  /// 通道池（存储Channel）
  late final AddressPairMap<Channel> _channelPool;

  /// 创建通道池（扩展点：可自定义ChannelPool）
  // protected
  AddressPairMap<Channel> createChannelPool() => ChannelPool();

  //
  //  Channel管理（核心接口）
  //

  /// 创建Channel（抽象方法：子类实现具体的Channel类型）
  /// [remote] - 远程地址
  /// [local] - 本地地址
  // protected
  Channel createChannel({required SocketAddress remote, SocketAddress? local});

  /// 获取所有Channel（重写父类方法）
  @override // protected
  Iterable<Channel> get allChannels => _channelPool.items;

  /// 获取Channel（按地址对）
  // protected
  Channel? getChannel({required SocketAddress remote, SocketAddress? local}) =>
      _channelPool.getItem(remote: remote, local: local);

  /// 设置Channel（缓存到池）
  // protected
  Channel? setChannel(Channel channel, {required SocketAddress remote, SocketAddress? local}) =>
      _channelPool.setItem(channel, remote: remote, local: local);

  /// 移除Channel（从重写父类方法）
  @override // protected
  Channel? removeChannel(Channel? channel, {SocketAddress? remote, SocketAddress? local}) =>
      _channelPool.removeItem(channel, remote: remote, local: local);

  //
  //  打开Socket Channel（核心）
  //

  /// 打开Channel（重写父类方法）
  @override
  Future<Channel?> open({SocketAddress? remote, SocketAddress? local}) async {
    // 前置检查：远程地址不能为空
    if(remote == null){
      assert(false, 'remote address empty');
      return null;
    }
    //
    //  0. 检查缓存的Channel
    //
    Channel? channel = getChannel(remote: remote, local: local);
    if (channel == null/* || channel.isClosed*/) {
      // 无缓存Channel → 打印日志
      logInfo('channel not open: $remote -> $local, $channel');
    } else {
      // 检查本地地址
      if (local == null) {
        // 本地地址为空 → 复用缓存Channel
        logInfo('reuse channel: $remote');
        return channel;
      }
      SocketAddress? address = channel.localAddress;
      if (address == null || address == local) {
        // 本地地址匹配 → 复用缓存Channel
        logInfo('reuse channel: $remote -> $address');
        return channel;
      }
    }
    //
    //  1. 创建新Channel并缓存
    //
    channel = createChannel(remote: remote, local: local);
    local ??= channel.localAddress;
    // 缓存Channel
    var cached = setChannel(channel, remote: remote, local: local);
    // 关闭旧的缓存Channel
    if (cached == null || identical(cached, channel)) {} else {
      await cached.close();
    }
    //
    //  2. 为Channel创建SocketChannel
    //
    if (channel is BaseChannel) {
      SocketChannel? socket = await createSocketChannel(remote: remote, local: local);
      if (socket == null) {
        // 创建失败 → 移除Channel，返回null
        assert(false, 'failed to prepare socket: $local -> $remote');
        removeChannel(channel, remote: remote, local: local);
        channel = null;
      } else {
        // 创建成功 → 设置Socket到Channel
        logInfo('set socket to channel: $remote -> $local, $socket');
        await CommonHub.setSocket(socket, channel);
      }
    }
    return channel;
  }

  //
  //  Socket管理
  //

  /// 创建SocketChannel（抽象方法：子类实现具体的Socket类型）
  Future<SocketChannel?> createSocketChannel({required SocketAddress remote, SocketAddress? local});

  /// 为Channel设置Socket（静态方法）
  // protected
  static Future<bool> setSocket(SocketChannel socket, BaseChannel channel) async {
    try {
      await channel.setSocket(socket);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 打印信息日志
  // protected
  void logInfo(String msg) {
    print('[WS]         | $msg');
  }
}