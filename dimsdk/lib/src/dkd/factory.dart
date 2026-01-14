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


/*
 * 中文解析：
 * 作用：CPU 模块的「通用内容处理器工厂」，是 ContentProcessorFactory 接口的核心实现类，负责 ContentProcessor 的创建、缓存和路由，是 CPU 模块的“处理器调度中心”。
 * 依赖关系：
 * - 依赖 dimp/dkd.dart（Content/Command/GroupCommand 等核心类型）；
 * - 依赖 proc.dart（ContentProcessor/ContentProcessorCreator/ContentProcessorFactory 接口）。
 * 核心类与方法：
 * 1. GeneralContentProcessorFactory（通用处理器工厂）：
 *    - 构造方法：接收 ContentProcessorCreator，作为处理器的实际创建者；
 *    - 核心缓存：_contentProcessors（普通内容处理器缓存，key=msgType）、_commandProcessors（指令处理器缓存，key=cmdName）；
 *    - getContentProcessor：核心路由方法，按“指令优先、普通内容兜底”的逻辑获取处理器：
 *      1) 若为 Command 类型，先按 msgType+cmdName 获取指令处理器；
 *      2) 若为 GroupCommand，兜底尝试获取 group 指令处理器；
 *      3) 非指令类型，调用 getContentProcessorForType 获取普通处理器；
 *    - getContentProcessorForType：按 msgType 获取普通处理器，缓存已创建的处理器避免重复实例化；
 *    - getCommandProcessor：按 msgType+cmdName 获取指令处理器，缓存已创建的处理器；
 * 方法含义：
 * - 采用「缓存+委托创建」模式：工厂不直接创建处理器，而是委托 Creator 创建，自身只负责缓存和路由，符合“单一职责原则”；
 * - 指令处理器的优先级高于普通处理器，且 GroupCommand 有专属兜底逻辑，适配群指令的特殊处理场景；
 * - 缓存机制减少处理器重复创建，提升性能，符合“享元模式”设计思想；
 * - 路由逻辑标准化了“指令/普通内容”的处理器获取流程，保证所有 Content 都能找到对应的处理器。
 */

import 'package:dimsdk/cpu.dart';
import 'package:dimsdk/dimp.dart';

/// General ContentProcessor Factory
/// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
class GeneralContentProcessorFactory implements ContentProcessorFactory{
  GeneralContentProcessorFactory(this.creator);

  /// private:处理器创建者，工厂自身不创建处理器，仅委托该对象创建
  final ContentProcessorCreator creator;

  /// private:普通内容处理器缓存（key=msgType，避免重复创建）
  final Map<String,ContentProcessor> _contentProcessors = {};

  /// private:指令处理器缓存（key=cmdName,避免重复创建）
  final Map<String,ContentProcessor> _commandProcessors = {};

  @override
  ContentProcessor? getContentProcessor(Content content){
    ContentProcessor? cpu;
    String msgType = content.type;
    // 第一步：处理指令类型 Content（优先级高于普通内容）
    if(content is Command){
      String cmd = content.cmd;
      // 先尝试获取该指令专属的处理器
      cpu = getCommandProcessor(msgType,cmd);
      if(cpu != null){
        return cpu;
      }
      // 若指令是群指令，兜底尝试获取group指令处理器
      else if(content is GroupCommand){
        cpu = getCommandProcessor(msgType,'group');
        if(cpu != null){
          return cpu;
        }
      }
    }
    // 第二部：非指令类型，获取普通内容处理器
    return getContentProcessorForType(msgType);
  }

  @override
  ContentProcessor? getContentProcessorForType(String msgType){
    // 先从缓存获取，避免重复创建
    ContentProcessor? cpu = _contentProcessors[msgType];
    if(cpu == null){
      // 缓存未命中，委托Create创建处理器
      cpu = creator.createContentProcessor(msgType);
      if(cpu != null){
        // 创建成功则存入缓存
        _contentProcessors[msgType] = cpu;
      }
    }
    return cpu;
  }

  /// private：获取指令处理器（带缓存）
  ContentProcessor? getCommandProcessor(String msgType,String cmdName){ 
    // 先从缓存获取，避免重复创建
    ContentProcessor? cpu = _commandProcessors[cmdName];
    if(cpu == null){
      // 缓存未命中，委托Create创建处理器
      cpu = creator.createCommandProcessor(msgType,cmdName);
      if(cpu != null){
        // 创建成功则存入缓存
        _commandProcessors[cmdName] = cpu;
      }
    }
    return cpu;
  }
}