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

// 声明库名称：dim_flutter
library dim_flutter;

// 导出dim_client相关库（对外暴露的API）
export 'package:dim_client/ok.dart';
export 'package:dim_client/pnf.dart' hide NotificationNames; // 导出pnf库，隐藏NotificationNames
// export 'package:dim_client/ws.dart'; // 注释：未导出ws库
export 'package:dim_client/sdk.dart';
export 'package:dim_client/sqlite.dart';
export 'package:dim_client/plugins.dart';

export 'package:dim_client/compat.dart';
export 'package:dim_client/common.dart' hide TimeUtils; // 导出common库，隐藏TimeUtils
export 'package:dim_client/network.dart';
export 'package:dim_client/group.dart';
export 'package:dim_client/client.dart';
export 'package:dim_client/cpu.dart';

// 导出本地src目录下的模块
export 'src/dim_channels.dart';
export 'src/dim_client.dart';
export 'src/dim_common.dart';
export 'src/dim_filesys.dart' hide NotificationNames; // 导出文件系统模块，隐藏NotificationNames
export 'src/dim_models.dart';
export 'src/dim_network.dart';
export 'src/dim_pnf.dart' hide NotificationNames; // 导出PNF模块，隐藏NotificationNames
export 'src/dim_screens.dart';
export 'src/dim_sqlite.dart';
export 'src/dim_ui.dart';
export 'src/dim_utils.dart';
export 'src/dim_video.dart';
export 'src/dim_web3.dart';
export 'src/dim_widgets.dart';

// 导入平台接口
import 'dim_flutter_platform_interface.dart';

/// DimFlutter插件的对外入口类
/// 封装平台接口调用，提供统一的API给上层使用
class DimFlutter {
  /// 获取平台版本信息
  /// 内部调用平台接口实例的getPlatformVersion方法
  /// 返回：平台版本字符串（不同平台返回不同内容）
  Future<String?> getPlatformVersion() {
    return DimFlutterPlatform.instance.getPlatformVersion();
  }
}