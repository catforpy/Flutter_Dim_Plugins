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

/// 通知观察者接口
/// 作用：所有需要接收通知的类都需实现此接口，重写`onReceiveNotification`方法
abstract interface class Observer {

  /// 接收通知的回调方法（异步）
  /// [notification]：收到的通知对象
  Future<void> onReceiveNotification(Notification notification);
}


/// 通知数据模型
/// 作用：封装通知的核心信息（名称、发送者、扩展信息），混入Logging支持日志输出
class Notification with Logging {
  /// 构造方法
  /// [name]：通知名称（唯一标识，如"user_login"）
  /// [sender]：通知发送者（任意类型，标识谁发送了这个通知）
  /// [userInfo]：扩展信息（可选，携带通知的附加数据）
  Notification(this.name, this.sender, this.userInfo);

  /// 通知名称（核心标识，用于匹配观察者）
  final String name;
  /// 通知发送者
  final dynamic sender;
  /// 扩展信息（附加数据）
  final Map? userInfo;

  /// 重写toString：格式化输出通知信息（便于日志调试）
  @override
  String toString() {
    String clazz = className;
    return '<$clazz name="$name">\n\t<sender>$sender</sender>\n'
        '\t<info>$userInfo</info>\n</$clazz>';
  }
}