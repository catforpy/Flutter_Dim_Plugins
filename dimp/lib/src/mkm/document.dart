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

///
/// 身份文档基类（所有用户/群组文档的父类）
/// 作用：定义身份文档的通用逻辑（验证、签名、属性读写），是Visa/Bulletin的底层支撑
///
class BaseDocument extends Dictionary implements Document { 
  // 构造方法1：从字典初始化（解析网络/本地存储的文档）
  BaseDocument([super.dict]);

  /// 文档所属的实体ID（用户/群组，缓存）
  ID? _identifier;
  /// 序列化后的文档内容(JSON字符串，缓存)
  String? _json;
  /// 文档内容的签名（防止篡改，缓存）
  TransportableData? _sig;
  /// 文档的原始属性字典（缓存）
  Map? _properties;
  /// 文档验证状态：1=有效，0=未验证，-1=无效
  int _status = 0;
  /// 构造方法2：创建新文档/加载本地已验证的文档
  /// @param identifier - 实体id(用户/群组）
  /// @param docTyep    - 文档类型（VISA/BULLETIN）
  /// @param data       - 序列化后的文档内容（JSON）
  /// @param signature  - 文档签名（Base64格式）
  BaseDocument.from(ID? identifier, String docType,{String? data,TransportableData? signature})
  {
    // 1. 存储实体ID
    this['did'] = identifier.toString();
    _identifier = identifier;

    // 2. 存储文档类型（非空校验）
    assert(docType.isNotEmpty && docType != '*', '文档类型错误: $docType');
    this['type'] = docType;

    // 3. 处理文档内容和签名
    if(data == null || signature == null){
      // 场景1：创建新的空文档（无内容/签名）
      assert(data == null && signature == null, '文档内容/签名不匹配: $data, $signature');
      _json = null;
      _sig = null;
      // 初始化属性字典（包含创建时间）
      _properties = {
        'type':docType,       // 兼容旧版字段（已废弃）
        'created_time': DateTime.now().millisecondsSinceEpoch / 1000.0,
      };  
      _status = 0;  // 未验证
    }else{
      // 场景2：加载本地已验证的文档（有内容/签名）
      assert(data.isNotEmpty && signature.isNotEmpty, '文档内容/签名为空: $data, $signature');
      this['data'] = data;
      this['signature'] = signature.toString();
      _json = data;
      _sig = signature;
      _properties = null;   //懒加载（使用时再解析）
      _status = 1;    // 本地已验证，直接标记为有效
    }
  }
  /// 获取文档验证状态（是否有效）
  @override
  bool get isValid => _status > 0;
  /// 获取文档所属的实体ID（懒加载+费控校验）
  @override
  ID get identifier{
    _identifier ??= ID.parse(this['did']);
    return _identifier!;
  }
  /// 私有方法：获取序列化后的文档内容（懒加载）
  String? _getData(){
    _json ??= getString('data');
    return _json;
  }
  /// 私有方法：获取文档签名的二进制数据（懒加载）
  Uint8List? _getSignature(){
    TransportableData? ted = _sig;
    if(ted == null){
      Object base64 = this['signature'];
      _sig = ted = TransportableData.parse(base64);
    }
    return ted?.data;
  }
  /// 获取文档的原始属性字典（懒加载+验证状态校验）
  @override
  Map? get properties{
    if(_status < 0){
      // 文档已验证无效，返回null
      return null;
    }
    if(_properties == null){
      String? data = _getData();
      if(data == null){
        // 无序列化内容，创建空属性字典
        _properties = {};
      }else{
        // 解析json字符串为属性字典
        _properties = JSONMap.decode(data);
        assert(_properties != null, '文档内容解析失败: $data');
      }
    }
    return _properties;
  }
  /// 获取文档属性（按名称）
  @override
  dynamic getProperty(String name) => properties?[name];
  /// 设置文档属性（按名称）
  @override
  void setProperty(String name, Object? value){
    // 1.重置验证状态（属性变更后需重新签名/验证）
    assert(_status >= 0, '文档状态异常: $this');
    _status = 0;

    // 2.更新属性值
    Map? dict = properties;
    if(dict == null){
      assert(false, '获取文档属性失败: $this');
    }else if(value == null){
      dict.remove(name);  //值为Null则删除字段
    }else{
      dict[name] = value; //否则更新字段
    }

    // 3.清空缓存的内容和签名（属性变更后失效）
    remove('data');
    remove('signature');
    _json = null;
    _sig = null;
  }
  /// 验证文档签名
  @override
  bool verify(VerifyKey publicKey){
    if(_status > 0){
      // 已验证通过，直接返回true
      return true;
    }
    // 1.获取待验证的内容和签名
    String? data = _getData();
    Uint8List? signature = _getSignature();

    // 2.校验内容和签名的合法性
    if(data == null){
      // 无内容，签名页必须为空（新文档）
      _status = signature == null ? 0 : -1;
    }else if(signature == null){
      // 有内容但无签名：无效
      _status = -1;
    }else if(publicKey.verify(UTF8.encode(data), signature)){
      // 签名验证通过，文档有效
      _status = 1;
    }
    // 注：状态为0时不代表无效，可能是还没找到正确的验证密钥
    return _status == 1;
  }
  /// 对文档内容签名（防止篡改）
  @override
  Uint8List? sign(SignKey privateKey){
    Uint8List? signature;
    if(_status > 0){
      // 已签名/验证通过，直接返回缓存的签名
      assert(_json != null, '文档内容为空: $this');
      signature = _getSignature();
      assert(signature != null, '文档签名为空: $this');
      return signature;
    }

    // 1.更新签名时间（每次签名都刷新）
    setProperty('time', DateTime.now().millisecondsSinceEpoch / 1000.0);

    // 2.序列化属性字典并签名
    Map? dict = properties;
    if(dict == null){
      assert(false, '文档属性为空: ${toMap()}');
      return null;
    }
    String data = JSONMap.encode(dict);   // 转为json字符串
    assert(data.isNotEmpty, '序列化文档内容为空: $dict');
    signature = privateKey.sign(UTF8.encode(data));     //私钥签名
    assert(signature.isNotEmpty, '签名失败: $dict');
    TransportableData ted = TransportableData.create(signature);

    // 3.存储序列化内容和签名
    this['data'] = data;                 // JSON字符串
    this['signature'] = ted.toObject();  // Base64格式
    _json = data;
    _sig = ted;

    // 4.标记为有效
    _status = 1;
    return signature;
  }
  //---- 通用属性的快捷读写方法 ----
  /// 获取文档的签名时间
  @override
  DateTime? get time => Converter.getDateTime(getProperty('time'));
  /// 获取文档的名称（用户昵称/群组名）
  @override
  String? get name => Converter.getString(getProperty('name'));
  /// 设置文档的名称（用户昵称/群组名）
  @override
  set name(String? value) => setProperty('name', value);
  
}