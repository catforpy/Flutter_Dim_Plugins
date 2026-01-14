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


import 'package:lnc/log.dart';
import 'package:lnc/notification.dart';
import 'package:object_key/object_key.dart';

/// 通知中心（单例）
/// 作用：对外提供统一的通知注册、移除、发送入口，底层委托给BaseCenter实现
class NotificationCenter {
  /// 工厂构造方法：返回单例实例
  factory NotificationCenter() => _instance;
  /// 静态单例实例（私有）
  static final NotificationCenter _instance = NotificationCenter._internal();
  /// 私有构造方法：防止外部实例化
  NotificationCenter._internal();

  /// 底层通知中心实现（核心逻辑载体）
  BaseCenter center = BaseCenter();

  /// 注册观察者（监听指定名称的通知）
  /// [observer]：观察者（需实现Observer接口）
  /// [name]：通知名称（如"user_login"）
  void addObserver(Observer observer, String name) {
    center.addObserver(observer, name);
  }

  /// 移除观察者
  /// [observer]：要移除的观察者
  /// [name]：可选，指定通知名称（不传则移除该观察者所有注册的通知）
  void removeObserver(Observer observer, [String? name]) {
    center.removeObserver(observer, name);
  }

  /// 发送通知（快捷方法，自动封装为Notification对象）
  /// [name]：通知名称
  /// [sender]：发送者
  /// [info]：可选，扩展信息
  Future<void> postNotification(String name, dynamic sender, [Map? info]) async {
    await center.postNotification(name, sender, info);
  }

  /// 发送通知（直接传入Notification对象）
  /// [notification]：通知对象
  Future<void> post(Notification notification) async {
    await center.post(notification);
  }
}

/// 通知中心底层实现类（核心逻辑）
/// 混入Logging：支持日志输出，便于调试
class BaseCenter with Logging {

  /// 观察者映射表：key=通知名称，value=该名称对应的观察者集合（WeakSet避免内存泄漏）
  /// WeakSet特性：当观察者对象被回收时，会自动从集合中移除，不会持有强引用
  final Map<String, Set<Observer>> _observers = {};

  /// 注册观察者（监听指定名称的通知）
  /// [observer]：观察者（需实现Observer接口）
  /// [name]：通知名称
  void addObserver(Observer observer, String name) {
    // 1. 获取该通知名称对应的观察者集合
    Set<Observer>? listeners = _observers[name];
    if (listeners == null) {
      // 2. 集合不存在：创建WeakSet，添加观察者，存入映射表
      listeners = WeakSet();
      listeners.add(observer);
      _observers[name] = listeners;
    } else {
      // 3. 集合已存在：直接添加观察者
      listeners.add(observer);
    }
  }

  /// 移除观察者
  /// [observer]：要移除的观察者
  /// [name]：可选，指定通知名称（不传则移除该观察者所有注册的通知）
  void removeObserver(Observer observer, [String? name]) {
    if (name == null) {
      // 场景1：不传名称 → 移除该观察者在所有通知下的注册
      // 1. 遍历所有通知名称的观察者集合，移除该观察者
      _observers.forEach((key, listeners) {
        listeners.remove(observer);
      });
      // 2. 清理空的观察者集合（避免映射表冗余）
      _observers.removeWhere((key, listeners) => listeners.isEmpty);
    } else {
      // 场景2：传名称 → 仅移除该观察者在指定通知下的注册
      // 1. 获取该通知名称的观察者集合
      Set<Observer>? listeners = _observers[name];
      if (listeners != null && listeners.remove(observer)) {
        // 2. 成功移除观察者后，检查集合是否为空
        if (listeners.isEmpty) {
          // 3. 集合为空则从映射表中移除该通知名称
          _observers.remove(name);
        }
      }
    }
  }

  /// 发送通知（快捷方法，自动封装为Notification对象）
  /// [name]：通知名称
  /// [sender]：发送者
  /// [info]：可选，扩展信息
  Future<void> postNotification(String name, dynamic sender, [Map? info]) async {
    return await post(Notification(name, sender, info));
  }

  /// 发送通知（核心方法）
  /// [notification]：通知对象
  /// 异步执行：确保所有观察者的回调都执行完成，且单个观察者报错不影响其他
  Future<void> post(Notification notification) async {
    // 1. 获取该通知名称的观察者集合（toSet创建副本，避免遍历中集合变化）
    Set<Observer>? listeners = _observers[notification.name]?.toSet();
    if (listeners == null) {
      // 无观察者监听该通知，打印调试日志
      logDebug('no listeners for notification: ${notification.name}');
      return;
    }

    // 2. 收集所有观察者的回调任务（异步）
    List<Future> tasks = [];
    for (Observer item in listeners) {
      try {
        // 为每个观察者创建回调任务，捕获异常（避免单个观察者报错导致整体失败）
        tasks.add(item.onReceiveNotification(notification).onError((error, st) =>
            // 观察者回调报错时，打印错误日志（不中断其他任务）
            Log.error('observer error: $error, $st, $notification')
        ));
      } catch (ex, stackTrace) {
        // 捕获同步异常（如调用回调方法时直接抛出）
        logError('observer error: $ex, $stackTrace, $notification');
      }
    }

    // 3. 等待所有观察者的回调任务执行完成
    await Future.wait(tasks);
  }
}