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

import 'package:dim_plugins/dim_plugins.dart';

/// 通用命令工厂类
/// 该类实现了 GeneralCommandHelper 和 CommandHelper 接口，负责管理和创建各种命令对象
/// 核心功能是根据命令名称或内容类型，找到对应的命令工厂并解析生成命令对象
class CommandGeneralFactory implements GeneralCommandHelper, CommandHelper {

  /// 存储命令名称到命令工厂的映射表
  /// key: 命令名称(String)
  /// value: 对应的命令工厂(CommandFactory)
  final Map<String, CommandFactory> _commandFactories = {};

  /// 从内容映射中获取命令名称
  /// @param content 包含命令信息的映射对象
  /// @param defaultValue 可选参数，当获取不到命令名称时返回的默认值
  /// @return 解析后的命令名称字符串，若不存在则返回默认值
  @override
  String? getCmd(Map content, [String? defaultValue]) {
    // 从content中取出"command"字段的值
    var cmd = content['command'];
    // 使用转换器将值转换为字符串，若转换失败则返回默认值
    return Converter.getString(cmd, defaultValue);
  }

  //
  //  Command 命令管理相关方法
  //

  /// 注册命令工厂
  /// 将指定的命令名称与对应的命令工厂关联并存储
  /// @param cmd 命令名称
  /// @param factory 处理该命令的工厂实例
  @override
  void setCommandFactory(String cmd, CommandFactory factory) {
    _commandFactories[cmd] = factory;
  }

  /// 获取已注册的命令工厂
  /// 根据命令名称查找对应的命令工厂
  /// @param cmd 命令名称
  /// @return 对应的命令工厂实例，若未注册则返回null
  @override
  CommandFactory? getCommandFactory(String cmd) {
    return _commandFactories[cmd];
  }

  /// 解析命令对象
  /// 根据输入的内容，自动匹配对应的命令工厂并创建命令对象
  /// @param content 命令内容，可以是Command对象、Map或其他类型
  /// @return 解析后的Command对象，解析失败则返回null
  @override
  Command? parseCommand(Object? content) {
    // 1. 空值检查：如果内容为空，直接返回null
    if (content == null) {
      return null;
    } 
    // 2. 类型检查：如果已经是Command对象，直接返回
    else if (content is Command) {
      return content;
    }

    // 3. 将内容转换为Map类型，转换失败则返回null
    Map? info = Wrapper.getMap(content);
    if (info == null) {
      // 断言：调试模式下提示命令内容格式错误
      assert(false, 'command content error: $content');
      return null;
    }

    // 4. 从Map中获取命令名称
    String? cmd = getCmd(info);
    // 断言：调试模式下确保命令名称不为空
    assert(cmd != null, 'command name error: $content');

    // 5. 根据命令名称获取对应的命令工厂
    CommandFactory? factory = cmd == null ? null : getCommandFactory(cmd);

    // 6. 如果未找到对应的工厂，则使用默认工厂解析
    if (factory == null) {
      // 未知命令名称，尝试通过内容类型获取默认命令工厂
      factory = _defaultFactory(info);
      // 断言：调试模式下确保能获取到默认工厂
      assert(factory != null, 'cannot parse command: $content');
    }

    // 7. 使用找到的工厂解析命令并返回
    return factory?.parseCommand(info);
  }

  /// 获取默认命令工厂（静态方法）
  /// 当无法通过命令名称找到工厂时，尝试通过内容类型匹配对应的工厂
  /// @param info 包含命令信息的Map对象
  /// @return 匹配到的默认命令工厂，匹配失败则返回null
  static CommandFactory? _defaultFactory(Map info) {
    // 创建共享消息扩展实例
    var ext = SharedMessageExtensions();
    // 获取通用消息助手和内容助手
    GeneralMessageHelper? helper = ext.helper;
    ContentHelper? contentHelper = ext.contentHelper;

    // 1. 从信息中获取内容类型
    String? type = helper?.getContentType(info);
    
    // 2. 如果获取到内容类型，尝试获取对应的内容工厂
    if (type != null) {
      ContentFactory? factory = contentHelper?.getContentFactory(type);
      // 3. 检查内容工厂是否实现了CommandFactory接口
      if (factory is CommandFactory) {
        // 类型转换并返回
        return factory as CommandFactory;
      }
    }

    // 断言：调试模式下提示无法解析命令
    assert(false, 'cannot parse command: $info');
    return null;
  }

}
