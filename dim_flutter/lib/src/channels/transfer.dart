/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
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

import 'manager.dart';

/// 文件传输通道：封装Flutter与原生的文件路径交互
/// 核心功能：获取原生的缓存目录/临时目录，用于文件存储（如音频/图片/文件传输）
class FileTransferChannel extends SafeChannel {
  /// 构造方法：初始化文件传输通道，绑定通道名称
  /// [name] - 原生通道名称（对应ChannelNames.fileTransfer）
  FileTransferChannel(super.name);

  // ===================== 缓存目录（持久化） =====================
  String? _cachesDirectory; // 缓存目录缓存（避免重复调用原生）

  /// 获取原生缓存目录（持久化存储，App卸载才会删除）
  /// 返回：目录路径（null表示获取失败）
  Future<String?> get cachesDirectory async{
    String? dir = _cachesDirectory;
    // 懒加载：首次调用才获取，后续直接返回缓存值
    if(dir == null){
      dir = await invoke(ChannelMethods.getCachesDirectory,null);
      _cachesDirectory = dir;
    }
    return dir;
  }

  // ===================== 临时目录（非持久化） =====================
  String? _temporaryDirectory; // 临时目录缓存
  /// 获取原生临时目录（临时存储，系统可能自动清理）
  /// 返回：目录路径（null表示获取失败）
  Future<String?> get temporaryDirectory async {
    String? dir = _temporaryDirectory;
    // 懒加载：首次调用才获取，后续直接返回缓存值
    if (dir == null) {
      dir = await invoke(ChannelMethods.getTemporaryDirectory, null);
      _temporaryDirectory = dir; // 缓存目录路径
    }
    return dir;
  }
}