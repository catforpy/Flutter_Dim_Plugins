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

import 'dart:typed_data';

import 'package:object_key/object_key.dart'; // 弱引用列表依赖

import 'tasks.dart'; // 导入DownloadTask/DownloadInfo

/// 下载任务队列（带优先级）
/// 管理不同优先级的下载任务，支持按优先级获取任务、批量移除相同任务
class DownloadQueue{
  /// 优先级列表（已排序：从小到大，URGENT < NORMAL < SLOWER）
  final List<int> _priorities = [];
  /// 任务舰队：优先级 → 任务列表（WeakList避免内存泄漏）
  final Map<int, List<DownloadTask>> _fleets = {};

  /// 移除并处理相同参数的任务（相同URL）
  /// [task] - 已完成的任务
  /// [downData] - 下载到的字节数据（可为null）
  /// 返回值：Future<int> - 处理成功的任务数量
  Future<int> removeTasks(DownloadTask task, Uint8List? downData) async {
    // 获取当前任务的下载参数（URL）
    DownloadInfo? params = task.downloadParams;
    if (params == null) {
      assert(false, 'download task error: $task');
      return -1;
    }
    DownloadInfo? downloadParams;
    int success = 0; // 成功处理的任务数
    List<DownloadTask>? fleet;
    List<DownloadTask> array;

    // 遍历所有优先级
    for (int priority in _priorities) {
      fleet = _fleets[priority];
      if (fleet == null || fleet.isEmpty) {
        // 该优先级无任务，跳过
        continue;
      }
      array = fleet.toList(); // 复制列表，避免遍历中修改原列表

      // 遍历该优先级的所有任务
      for (DownloadTask item in array) {
        // 0. 检查是否为同一任务：直接移除
        if (identical(item, task)) {
          fleet.remove(item);
          success += 1;
          continue;
        }

        // 1. 准备任务参数：检查是否需要下载
        downloadParams = null;
        try {
          if (await item.prepareDownload()) {
            downloadParams = item.downloadParams;
            assert(downloadParams != null, 'download params error: $item');
          }
        } catch (e, st) {
          print('[HTTP] failed to prepare download task: $item, error: $e, $st');
        }
        if (downloadParams != params) {
          // 参数不同（URL不同），跳过
          assert(downloadParams != null, 'download params error: $item');
          continue;
        }

        // 2. 处理相同参数的任务：复用下载数据
        try {
          await item.processResponse(downData);
          success += 1;
        } catch (e, st) {
          print('[HTTP] failed to handle data: ${downData?.length} bytes, $params, error: $e, $st');
        }

        // 3. 从队列移除该任务
        fleet.remove(item);
      }
    }
    return success;
  }

  /// 获取下一个可执行的任务（优先级≤maxPriority）
  /// [maxPriority] - 最大优先级（如URGENT=-7、NORMAL=0、SLOWER=7）
  /// 返回值：DownloadTask? - 待执行任务，无则返回null
  DownloadTask? nextTask(int maxPriority) {
    List<DownloadTask>? fleet;
    // 遍历优先级列表（从小到大，优先处理高优先级）
    for (int priority in _priorities) {
      if (priority > maxPriority) {
        // 优先级超过限制（如当前线程处理NORMAL，跳过SLOWER）
        continue;
        // break; // 可选：优先级有序，后续均超过，直接中断
      }
      fleet = _fleets[priority];
      if (fleet == null || fleet.isEmpty) {
        // 该优先级无任务，跳过
        continue;
      }
      // 移除并返回队列第一个任务（FIFO）
      return fleet.removeAt(0);
    }
    return null;
  }

  /// 添加任务到对应优先级的队列
  /// [task] - 待添加的下载任务
  void addTask(DownloadTask task) {
    int priority = task.priority;
    List<DownloadTask>? fleet = _fleets[priority];
    if (fleet == null) {
      // 该优先级无队列：创建弱引用列表（避免内存泄漏）
      fleet = WeakList();
      _fleets[priority] = fleet;
      // 插入优先级到有序列表
      _insertPriority(priority);
    }
    // 添加任务到队列尾部
    fleet.add(task);
  }

  /// 插入优先级到有序列表（从小到大）
  /// [priority] - 待插入的优先级值
  void _insertPriority(int priority) {
    int index = 0, value;
    // 查找插入位置：找到第一个大于当前优先级的位置
    for (; index < _priorities.length; ++index) {
      value = _priorities[index];
      if (value == priority) {
        // 优先级已存在，无需插入
        return;
      } else if (value > priority) {
        // 找到插入位置
        break;
      }
      // 继续查找（当前值更小）
    }
    // 插入到对应位置，保持列表有序
    _priorities.insert(index, priority);
  }
}