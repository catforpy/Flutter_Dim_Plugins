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

import 'package:dimsdk/core.dart';

/// 双核心助手类
/// 弱引用持有Facebook（用户/群组管理）和Messenger（消息收发）两大核心实例，
/// 为上层组件提供统一的核心依赖访问入口，同时避免强引用导致的内存泄漏
abstract class TwinsHelper {

  /// 构造方法：初始化双核心弱引用
  /// @param facebook - 用户/群组管理核心
  /// @param messenger - 消息收发核心
  TwinsHelper(Facebook facebook, Messenger messenger)
      : _barrack = WeakReference(facebook),
        _transceiver = WeakReference(messenger);

  /// 弱引用持有Facebook实例（用户/群组管理核心）
  /// 命名为_barrack（营房）对应Facebook的实体管理能力
  final WeakReference<Facebook> _barrack;
  
  /// 弱引用持有Messenger实例（消息收发核心）
  /// 命名为_transceiver（收发器）对应Messenger的消息处理能力
  final WeakReference<Messenger> _transceiver;

  /// 对外提供Facebook实例访问（自动解弱引用）
  /// @return Facebook实例（可能为null，需判空）
  Facebook? get facebook => _barrack.target;
  
  /// 对外提供Messenger实例访问（自动解弱引用）
  /// @return Messenger实例（可能为null，需判空）
  Messenger? get messenger => _transceiver.target;

}