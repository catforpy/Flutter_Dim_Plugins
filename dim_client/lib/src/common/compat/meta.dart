/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2025 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2025 Albert Moky
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

import 'package:dim_client/sdk.dart';

/// 兼容型Meta工厂
/// 扩展BaseMetaFactory，支持解析多种类型的Meta
class CompatibleMetaFactory extends BaseMetaFactory{
  
  /// 构造方法
  /// @param type - Meta类型
  CompatibleMetaFactory(super.type);

  /// 解析Meta字典（重写）
  /// @param meta - Meta字典
  /// @return 解析后的Meta对象（null=无效Meta）
  @override
  Meta? parseMeta(Map meta){
    Meta out;
    // 获取共享账户扩展帮助类
    var ext = SharedAccountExtensions();
    // 获取Meta类型版本
    String? version = ext.helper!.getMetaType(meta);
    // 根据版本创建对应类型的Meta
    switch (version) {
      case 'MKM':
      case 'mkm':
      case '1':
        out = DefaultMeta(meta);
        break;

      case 'BTC':
      case 'btc':
      case '2':
        out = BTCMeta(meta);
        break;

      case 'ETH':
      case 'eth':
      case '4':
        out = ETHMeta(meta);
        break;

      default:
        // 未知Meta类型抛出异常
        throw Exception('unknown meta type: $type');
    }
    // 验证Meta有效性，有效则返回，否则返回null
    return out.isValid ? out : null;
  }
}