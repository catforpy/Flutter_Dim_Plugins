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

import 'package:dkd/dkd.dart';

/// 通用消息助手接口
/// ~~~~~~~~~~~~~~~~~~~~~~
/// 扩展消息处理的通用能力，核心提供消息内容类型的解析能力
/// 注：注释中标记了该接口原本计划实现多个助手接口（ContentHelper/EnvelopeHelper等），
///     实际未直接实现，而是作为通用能力扩展
abstract interface class GeneralMessageHelper /*
    implements ContentHelper, EnvelopeHelper,
        InstantMessageHelper, SecureMessageHelper, ReliableMessageHelper */{

  //
  //  消息类型相关方法
  //

  /// 从内容Map中提取消息类型
  /// [content] - 消息内容的Map/JSON对象
  /// [defaultValue] - 提取失败时返回的默认值（可选）
  /// 返回：消息类型标识字符串（如文本消息返回"0"，命令消息返回"1"），提取失败返回defaultValue
  String? getContentType(Map content, [String? defaultValue]);

}

/// 共享消息扩展管理器（单例）
/// ~~~~~~~~~~~~~~~~~~~~~~
/// 对核心的 MessageExtensions 单例进行封装，提供统一、便捷的访问入口，
/// 同时扩展了通用消息助手（GeneralMessageHelper）的管理能力
class SharedMessageExtensions {
  // 单例模式实现：工厂构造方法 + 静态私有实例
  factory SharedMessageExtensions() => _instance;
  static final SharedMessageExtensions _instance = SharedMessageExtensions._internal();
  // 私有构造方法，禁止外部实例化
  SharedMessageExtensions._internal();

  // ---------------------------------------------------------------------------
  //  代理访问 MessageExtensions 中的各类助手（封装核心助手的读写操作）
  // ---------------------------------------------------------------------------

  /// 内容助手（ContentHelper）的代理访问器
  /// 读取：转发到 MessageExtensions 单例的 contentHelper 属性
  ContentHelper? get contentHelper =>
      MessageExtensions().contentHelper;

  /// 内容助手（ContentHelper）的代理设置器
  /// 设置：转发到 MessageExtensions 单例的 contentHelper 属性
  set contentHelper(ContentHelper? helper) =>
      MessageExtensions().contentHelper = helper;

  /// 信封助手（EnvelopeHelper）的代理访问器
  /// 读取：转发到 MessageExtensions 单例的 envelopeHelper 属性
  EnvelopeHelper? get envelopeHelper =>
      MessageExtensions().envelopeHelper;

  /// 信封助手（EnvelopeHelper）的代理设置器
  /// 设置：转发到 MessageExtensions 单例的 envelopeHelper 属性
  set envelopeHelper(EnvelopeHelper? helper) =>
      MessageExtensions().envelopeHelper = helper;

  /// 即时消息助手（InstantMessageHelper）的代理访问器
  /// 读取：转发到 MessageExtensions 单例的 instantHelper 属性
  InstantMessageHelper? get instantHelper =>
      MessageExtensions().instantHelper;

  /// 即时消息助手（InstantMessageHelper）的代理设置器
  /// 设置：转发到 MessageExtensions 单例的 instantHelper 属性
  set instantHelper(InstantMessageHelper? helper) =>
      MessageExtensions().instantHelper = helper;

  /// 安全消息助手（SecureMessageHelper）的代理访问器
  /// 读取：转发到 MessageExtensions 单例的 secureHelper 属性
  SecureMessageHelper? get secureHelper =>
      MessageExtensions().secureHelper;

  /// 安全消息助手（SecureMessageHelper）的代理设置器
  /// 设置：转发到 MessageExtensions 单例的 secureHelper 属性
  set secureHelper(SecureMessageHelper? helper) =>
      MessageExtensions().secureHelper = helper;

  /// 可靠消息助手（ReliableMessageHelper）的代理访问器
  /// 读取：转发到 MessageExtensions 单例的 reliableHelper 属性
  ReliableMessageHelper? get reliableHelper =>
      MessageExtensions().reliableHelper;

  /// 可靠消息助手（ReliableMessageHelper）的代理设置器
  /// 设置：转发到 MessageExtensions 单例的 reliableHelper 属性
  set reliableHelper(ReliableMessageHelper? helper) =>
      MessageExtensions().reliableHelper = helper;

  // ---------------------------------------------------------------------------
  //  扩展：通用消息助手（新增能力）
  // ---------------------------------------------------------------------------

  /// 通用消息助手实例
  /// 提供消息类型解析等通用能力，独立于核心助手之外的扩展
  GeneralMessageHelper? helper;

}