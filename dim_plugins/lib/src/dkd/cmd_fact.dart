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

/// 通用命令工厂
/// 核心作用：
/// 1. 实现 ContentFactory + CommandFactory 接口，作为命令解析的「默认工厂」；
/// 2. 支持根据命令类型动态匹配专属工厂，匹配失败则使用自身解析；
/// 3. 对群组命令做特殊兼容（即使命令类型不匹配，只要含 group 字段就用群组工厂）
class GeneralCommandFactory implements ContentFactory, CommandFactory {

  /// 解析命令内容（核心入口）
  /// 补充说明：
  /// - 先从全局扩展管理器获取命令辅助器，提取命令类型；
  /// - 根据命令类型获取专属工厂，优先使用专属工厂解析；
  /// - 若无专属工厂，且内容含 group 字段 → 使用群组命令工厂；
  /// - 最终兜底使用当前工厂解析；
  /// [content] - 命令内容的原始Map
  /// 返回值：解析后的 Content/Command 对象（失败返回null）
  @override
  Content? parseContent(Map content) {
    // 获取全局命令扩展管理器单例
    var ext = SharedCommandExtensions();
    GeneralCommandHelper? helper = ext.helper;
    CommandHelper? cmdHelper = ext.cmdHelper;
    
    // 1. 从Map中提取命令类型（如 'group'/'history'/'profile' 等）
    String? cmd = helper?.getCmd(content);
    // 2. 根据命令类型获取专属工厂
    CommandFactory? factory = cmd == null ? null : cmdHelper?.getCommandFactory(cmd);
    
    if (factory == null) {
      // 3. 无专属工厂时，检查是否为群组命令（含 group 字段）
      if (content.containsKey('group')/* && cmd != 'group'*/) {
        factory = cmdHelper?.getCommandFactory('group');
      }
      // 4. 最终兜底使用当前工厂
      factory ??= this;
    }
    // 5. 使用匹配到的工厂解析命令
    return factory.parseCommand(content);
  }

  /// 解析基础命令（兜底实现）
  /// 补充说明：
  /// - 校验命令必备字段：sn（序列号）、command（命令类型）；
  /// - 校验失败会触发断言，并返回null；
  /// - 校验通过则创建基础命令对象 BaseCommand；
  /// [content] - 命令内容的原始Map
  /// 返回值：BaseCommand 实例（失败返回null）
  @override
  Command? parseCommand(Map content) {
    // 检查必备字段：sn（序列号）、command（命令类型）
    if (content['sn'] == null || content['command'] == null) {
      // content.sn should not be empty - 命令序列号不能为空
      // content.command should not be empty - 命令类型不能为空
      assert(false, 'command error: $content');
      return null;
    }
    // 创建基础命令对象
    return BaseCommand(content);
  }

}

/// 历史命令工厂
/// 核心作用：
/// 1. 继承通用命令工厂，重写 parseCommand 方法；
/// 2. 针对历史命令增加额外校验：必须包含 time（时间戳）字段；
/// 3. 校验通过则创建 BaseHistoryCommand（带时间的命令）
class HistoryCommandFactory extends GeneralCommandFactory {

  /// 解析历史命令（增强校验）
  /// 补充说明：
  /// - 在通用命令的基础上，增加 time 字段校验；
  /// - 历史命令必须包含时间戳，用于追溯操作时间；
  /// [content] - 历史命令的原始Map
  /// 返回值：BaseHistoryCommand 实例（失败返回null）
  @override
  Command? parseCommand(Map content) {
    // 检查必备字段：sn、command、time（历史命令新增）
    if (content['sn'] == null || content['command'] == null || content['time'] == null) {
      // content.sn should not be empty - 序列号不能为空
      // content.command should not be empty - 命令类型不能为空
      // content.time should not be empty - 时间戳不能为空
      assert(false, 'command error: $content');
      return null;
    }
    // 创建带时间的历史命令对象
    return BaseHistoryCommand(content);
  }

}

/// 群组命令工厂
/// 核心作用：
/// 1. 继承历史命令工厂，同时重写 parseContent + parseCommand；
/// 2. parseContent：强制优先使用群组命令工厂解析（忽略其他命令类型）；
/// 3. parseCommand：增加 group 字段校验，创建 BaseGroupCommand（群组命令）
class GroupCommandFactory extends HistoryCommandFactory {

  /// 解析群组命令（强制匹配）
  /// 补充说明：
  /// - 覆盖通用工厂的逻辑，不依赖命令类型匹配，直接使用当前工厂解析；
  /// - 确保所有含 group 字段的命令都走群组命令解析逻辑；
  /// [content] - 群组命令的原始Map
  /// 返回值：解析后的群组命令对象
  @override
  Content? parseContent(Map content) {
    var ext = SharedCommandExtensions();
    GeneralCommandHelper? helper = ext.helper;
    CommandHelper? cmdHelper = ext.cmdHelper;
    
    // 1. 提取命令类型（仅做参考）
    String? cmd = helper?.getCmd(content);
    // 2. 尝试获取专属工厂
    CommandFactory? factory = cmd == null ? null : cmdHelper?.getCommandFactory(cmd);
    // 3. 强制兜底使用当前群组工厂（区别于通用工厂的逻辑）
    factory ??= this;
    
    return factory.parseCommand(content);
  }

  /// 解析群组命令（最终校验）
  /// 补充说明：
  /// - 在历史命令基础上，增加 group 字段（群组ID）校验；
  /// - 群组命令必须关联具体的群组，否则解析失败；
  /// [content] - 群组命令的原始Map
  /// 返回值：BaseGroupCommand 实例（失败返回null）
  @override
  Command? parseCommand(Map content) {
    // 检查必备字段：sn、command、group（群组命令新增）
    if (content['sn'] == null || content['command'] == null || content['group'] == null) {
      // content.sn should not be empty - 序列号不能为空
      // content.command should not be empty - 命令类型不能为空
      // content.group should not be empty - 群组ID不能为空
      assert(false, 'group command error: $content');
      return null;
    }
    // 创建群组命令对象
    return BaseGroupCommand(content);
  }

}