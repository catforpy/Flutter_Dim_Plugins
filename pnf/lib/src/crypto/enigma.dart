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

import 'dart:math';
import 'dart:typed_data';

// 导入格式转换工具（Base64/Hex）
import 'package:mkm/format.dart';
// 导入协议相关（ID类型）
import 'package:mkm/protocol.dart';
// 导入键值对工具
import 'package:object_key/object_key.dart';

import 'digest.dart';
import 'template.dart';

/// MD5秘钥管理核心类（Enigma）
/// 核心作用：
/// 1. 存储/管理多个MD5相关的秘钥（key: 秘钥标识, value: 秘钥字节数据）；
/// 2. 支持从URL中提取enigma参数，匹配对应的秘钥；
/// 3. 构建带MD5校验的上传URL（用于文件上传鉴权）
class Enigma{

  /// 秘钥字典：存储秘钥表示与秘钥字节的映射
  /// key: 秘钥标识字符串（如base64编码/hex编码的字符串）
  /// value:解码后的秘钥原始字节数据
  final Map<String,Uint8List> _dictionary = {};

  /// 获取类名（用于toString格式化）
  String get className => 'Enigma';

  /// 格式化输出（便于调试）
  @override
  String toString(){
    String clazz = className;
    String keys = _dictionary.keys.toString();
    return '<$clazz>\r\n'
        '    keys: $keys\r\n'
        '</$clazz>';
  }

  /// 获取所有秘钥（只读）
  Map<String,Uint8List> get all => _dictionary;

  /// 获取任意一个秘钥（键值对）
  /// 返回值：Pair(秘钥标识摘要, 秘钥字节)，无秘钥时返回null并触发断言
  Pair<String,Uint8List>? get any{
    if(_dictionary.isEmpty){
      assert(false, 'enigma secrets not found');
      return null;
    }
    var entry = _dictionary.entries.first;
    // 对秘钥标识做摘要处理（MD5）
    String text = _EnigmaHelper.digest(entry.key);
    return Pair(text, entry.value);
  }

  /// 清空所有秘钥
  void clear() =>
      _dictionary.clear();

  /// 根据前缀移除匹配的秘钥
  /// [keys] - 待移除的秘钥前缀列表
  void remove(Iterable<String> keys){
    // 遍历每个前缀
    for(String prefix in keys){
      if (prefix.isEmpty) {
        assert(false, 'enigma error: $keys');
        continue;
      }
      // 移除所有标识以该前缀开头的密钥
      _dictionary.removeWhere((text,_) => _EnigmaHelper.match(text,enigma:prefix),
      );
    }
  }

  /// 更新秘钥字典（批量添加秘钥）
  /// [secrets] - 秘钥字符串列表（支持格式：base64,xxx / hex,xxx / xxx）
  void update(Iterable<String> secrets) {
    Pair<String,Uint8List>? pair;
    for(String text in secrets){
      // 解码秘钥字符串为（标识，字节）键值对
      pair = _EnigmaHelper.decode(text);
      if(pair == null){
        assert(false, 'failed to decode secret: $text');
        continue;
      }
      // 存入字典
      _dictionary[pair.first] = pair.second;
    }
  }

  /// 根据前缀查找匹配的秘钥
  /// [keys] - 待匹配的前缀列表（null则返回任意一个）
  /// 返回值：Pair(匹配的前缀, 秘钥字节)，无匹配返回null
  Pair<String, Uint8List>? lookup([Iterable<String>? keys]){
    if(keys == null){
      return any;
    }
    // 遍历每个前缀
    for(String prefix in keys){
      if (prefix.isEmpty) {
        assert(false, 'enigma error: $keys');
        continue;
      }
      // 遍历字典查找匹配的秘钥
      for(var entry in _dictionary.entries){
        // 检查秘钥标识是否匹配该前缀
        if(_EnigmaHelper.match(entry.key, enigma: prefix)){
          return Pair(entry.key, entry.value);
        }
      }
    }
    // 未找到匹配的秘钥
    return null;
  }

  //
  //  URL: "https://tfs.dim.chat/{ID}/upload?md5={MD5}&salt={SALT}&enigma=123456"
  //

  /// 从API URL中提取enigma参数，查找对应的秘钥
  /// [api] - 上传API的URL模板/完整URL
  /// 返回值：匹配的秘钥键值对，无匹配返回null
  Pair<String, Uint8List>? fetch(String api){
    // 从URL中提取enigma参数值
    List<String>? keys;
    String enigma = _EnigmaHelper.getEnigma(api);
    //如果提取到的enigma值，则用该值作为前缀查找
    if(enigma.isNotEmpty){
      keys = [enigma];
    }else{
      //未指定enigma，返回任意一个秘钥
    }
    return lookup(keys);
  }

  /// 构建带MD5校验的上传URL（核心业务方法）
  /// 哈希规则：md5(md5(data) + secret + salt)
  /// [api] - URL模板（含{ID}/{MD5}/{SALT}/{ENIGMA}占位符）
  /// [sender] - 发送者ID（替换{ID}）
  /// [data] - 待上传文件的字节数据（必填）
  /// [secret] - 鉴权秘钥（必填）
  /// [enigma] - enigma标识（必填）
  /// 返回值：填充后的完整上传URL
  String build(String api, ID sender, {
    required Uint8List data, required Uint8List secret, required String enigma
  }){
    // 参数校验
    assert(data.isNotEmpty && secret.isNotEmpty && enigma.isNotEmpty, 'enigma params error: ${data.length}, ${secret.length}, $enigma');
    // 替换URL中的{ID}占位符（发送者地址）
    String urlString = api;
    urlString = Template.replace(urlString, 'ID', sender.address.toString());
    // 生成16字节随机盐值
    Uint8List salt = _EnigmaHelper.random(16);
    // 计算哈希：md5（md5（文件数据） + 秘钥 + 盐值）
    Uint8List temp = _EnigmaHelper.concat(MD5.digest(data), secret, salt);
    Uint8List hash = MD5.digest(temp);
    // 替换{MD5}和{SALT}占位符{Hex编码}
    urlString = Template.replace(urlString, 'MD5', Hex.encode(hash));
    urlString = Template.replace(urlString, 'SALT', Hex.encode(salt));
    // 替换{ENIGMA}或enigma查询参数
    return _EnigmaHelper.replaceEnigma(urlString, enigma);
  }
}

/// Enigma工具类（静态内部辅助类）
/// 核心作用：封装秘钥解析、URL处理、字节操作等通用逻辑
abstract class _EnigmaHelper {

  /// 对秘钥标识做摘要（取前6位，用于简化匹配）
  /// [secret] - 原始秘钥标识字符串
  /// 返回值：标识字符串的前6位（不足则返回原字符串并触发断言）
  static String digest(String secret) {
    List<String> pair = secret.split(',');
    assert(pair.length == 1 || pair.length == 2, 'enigma secret error: $secret');
    String text = pair.last;
    if(text.length > 6){
      return text.substring(0,6);
    }
    assert(false, 'enigma secret not safe: $secret');
    return text;
  }

  /// 检查秘钥标识是否匹配指定前缀
  /// [secret] - 秘钥标识字符串
  /// [enigma] - 待匹配的前缀
  /// 返回值：是否匹配
  static bool match(String secret, {required String enigma}) {
    List<String> pair = secret.split(',');
    assert(pair.length == 1 || pair.length == 2, 'enigma secret error: $secret');
    String text = pair.last;
     // 提取前缀的有效部分（分割后取最后一段）
    String prefix = enigma.split(',').last;
    if (prefix.isEmpty) {
      assert(false, 'enigma error: $enigma');
      return false;
    }
    // 检查秘钥标识是否以该前缀开头
    return text.startsWith(prefix);
  }

  /// 解码秘钥字符串为（标识, 字节）键值对
  /// 支持格式：
  /// 1. base64,{BASE64_ENCODE} → 解码BASE64
  /// 2. hex,{HEX_ENCODE} → 解码HEX
  /// 3. {HEX_ENCODE} → 解码HEX
  /// [secret] - 待解码的秘钥字符串
  /// 返回值：Pair(原始标识, 解码后的字节)，解码失败返回null
  static Pair<String, Uint8List>? decode(String secret){
    List<String> pair = secret.split(',');
    assert(pair.length == 1 || pair.length == 2, 'enigma secret error: $secret');
    String text = pair.last;
    // 根据前缀选择解码方式
    Uint8List? data;
    if(pair.length == 2 && pair.first == 'base64'){
      // BASE64编码方式
      data = Base64.decode(text);
    }else{
      // HEX编码格式（默认）
      data = Hex.decode(text);
    }
    return data == null ? null : Pair(text, data);
  }

  //
  //  URL: "https://tfs.dim.chat/{ID}/upload?md5={MD5}&salt={SALT}&enigma={ENIGMA}"
  //

  /// 从URL中提取enigma查询参数的值
  /// [url] - 待解析的URL
  /// 返回值：enigma参数值（无则返回空字符串）
  static String getEnigma(String url){
    String? enigma = Template.getQueryParam(url, 'enigma');
    // 排除占位符情况
    if (enigma == null || enigma == '{ENIGMA}') {
      return '';
    }
    return enigma;
  }

  /// 将enigma值填入URL（替换占位符或新增查询参数）
  /// [url] - URL模板/完整URL
  /// [enigma] - 要填入的enigma值
  /// 返回值：处理后的URL
  static String replaceEnigma(String url, String enigma) {
    // 如果包含{ENIGMA}占位符，直接替换
    if (url.contains('{ENIGMA}')) {
      return Template.replace(url, 'ENIGMA', enigma);
    }
    // 否则替换/新增enigma查询参数
    return Template.replaceQueryParam(url, 'enigma', enigma);
  }

  //
  //  Bytes 字节操作工具
  //

  /// 拼接三个字节数组
  static Uint8List concat(Uint8List a, Uint8List b, Uint8List c) =>
      Uint8List.fromList(a + b + c);

  /// 生成指定长度的随机字节数组（用于盐值生成）
  /// [size] - 字节长度（如16）
  /// 返回值：随机字节数组
  static Uint8List random(int size) {
    Uint8List data = Uint8List(size);
    Random r = Random();
    for (int i = 0; i < size; ++i) {
      // 生成0-255的随机整数作为字节值
      data[i] = r.nextInt(256);
    }
    return data;
  }
}