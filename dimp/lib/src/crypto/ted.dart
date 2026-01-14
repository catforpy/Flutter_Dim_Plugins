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

import 'package:dimp/dimp.dart';

///  可传输数据封装结构：{
///
///     algorithm : "base64",    // 编码算法（base64/base58/hex）
///     data      : "...",      // 二进制数据的编码字符串
///     ...
///  }
///
///  支持的编码格式（解析/序列化）：
///     0. 纯编码字符串 → "{BASE64_ENCODE}"
///     1. 算法+编码字符串 → "base64,{BASE64_ENCODE}"
///     2. MIME类型+算法+编码字符串 → "data:image/png;base64,{BASE64_ENCODE}"
///  设计目的：封装二进制数据的标准化编码/解码逻辑，适配IM中各类二进制数据（密钥/文件/消息体）的传输
class BaseDataWrapper extends Dictionary {
  /// 构造方法：初始化可传输数据字典
  BaseDataWrapper([super.dict]);

  /// 缓存：二进制数据（避免重复编码/解码）
  Uint8List? _data;

  // 注：原代码中注释的isEmpty/isNotEmpty方法，保留注释逻辑，不影响核心功能

  ///
  /// 转为字符串（适配格式0/1）
  /// 逻辑：无算法 → 纯编码字符串；有算法 → "算法,编码字符串"
  /// @return 编码后的字符串（空字符串表示无数据）
  ///
  @override
  String toString(){
    String? text = getString('data');
    if(text == null)
    {
      return '';
    }
    String? alg = getString('algorithm');
    if(alg == null || alg == EncodeAlgorithms.DEFAULT){
      alg = '';
    }
    if(alg.isEmpty){
      // 格式0：纯编码字符串
      return text;
    }else{
      // 格式1：算法+编码字符串
      return '$alg:$text';
    }
  }

  ///
  /// 带MIME类型的编码（适配格式2）
  /// 用于图片/视频等媒体文件的标准化传输（如HTML的data URI格式）
  /// @param mimeType - MIME类型（如image/png、video/mp4等）
  /// @return 带MIME类型的编码字符串（空字符串表示无数据）
  /// 
  String encode(String mimeType){
    assert(!mimeType.contains(' '), 'MIME类型错误: $mimeType');
    // 获取编码后的字符串
    String? text = getString('data');
    if(text == null)
    {
      return '';
    }
    String alg = algorithm;
    // 格式2：data:{MIME};{算法},{编码字符串}
    return 'data:$mimeType;$alg,$text';
  }

  ///
  /// 获取编码算法
  /// 逻辑：优先取字典中的algorithm -> 无用则默认算法(base64)
  /// @return 编码算法名称(base64/base5//hex)
  /// 
  String get algorithm{
    String? alg = getString('algorithm');
    if(alg == null || alg.isEmpty)
    {
      alg = EncodeAlgorithms.DEFAULT;
    }
    return alg;
  }

  ///
  /// 设置编码算法
  /// 同步更新字典中的algorithm字段，空值/默认值自动移除
  /// @param name - 算法名称（空字符串表示用默认）
  ///
  set algorithm(String name) {
    if (name.isEmpty/* || name == EncodeAlgorithms.kDefault*/) {
      remove('algorithm');
    } else {
      this['algorithm'] = name;
    }
  }

  ///
  /// 获取二进制数据
  /// 逻辑：优先取缓存 → 按算法解码字典中的data字段 → 缓存结果
  /// @return 二进制数据（null表示解码失败/无数据）
  ///
  Uint8List? get data{
    Uint8List? binary = _data;
    if(binary == null){
      String? text = getString('data');
      if(text == null || text.isEmpty){
        assert(false, '可传输数据为空: ${toMap()}');
        return null;
      }else{
        String alg = algorithm;
        // 按指定算法解码
        switch(alg){
          case EncodeAlgorithms.BASE_64:
            binary = Base64.decode(text);
            break;
          case EncodeAlgorithms.BASE_58:
            binary = Base58.decode(text);
            break;
          case EncodeAlgorithms.HEX:
            binary = Hex.decode(text);
            break;
          default:
            assert(false, '不支持的编码算法: $alg');
            return null;
        }
      }
      _data = binary;
    }
    return binary;
  }

  ///
  /// 设置二进制数据
  /// 逻辑：按指定算法编码 → 同步更新字典中的data字段 + 缓存
  /// @param binary - 二进制数据（null/空表示清空）
  /// @throws FormatException - 不支持的编码算法
  ///
  set data(Uint8List? binary){
    if(binary == null || binary.isEmpty){
      remove('data');
    }else{
      String text;
      String alg = algorithm;
      // 按制定算法编码
      switch (alg) {
        case EncodeAlgorithms.BASE_64:
          text = Base64.encode(binary);
          break;
        case EncodeAlgorithms.BASE_58:
          text = Base58.encode(binary);
          break;
        case EncodeAlgorithms.HEX:
          text = Hex.encode(binary);
          break;
        default:
          throw FormatException('不支持的编码算法: $alg');
      }
      this['data'] = text;
    }
    _data = binary;
  }
}