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
import 'package:shared_preferences/shared_preferences.dart'; // 本地存储库


/// 应用设置工具类 - 单例模式，封装SharedPreferences操作
/// 用于持久化存储应用配置（如语言、主题、阅后即焚等）
class AppSettings {

  // 单例实现：工厂构造函数 + 私有景泰示例 + 私有构造函数
  factory AppSettings() => _instance;
  static final AppSettings _instance = AppSettings._internal();
  AppSettings._internal();

  SharedPreferences? _preferences; // SharedPreferences实例

  /// 加载SharedPreferences实例 - 懒加载，确保只初始化一次
  Future<SharedPreferences> load() async{
    SharedPreferences? sp = _preferences;
    if(sp == null){
      _preferences = sp = await SharedPreferences.getInstance();
    }
    return sp;
  }

  /// 获取指定键的值 - 泛型方法，返回指定类型的值
  T getValue<T>(String key) => _preferences?.get(key) as T;

  /// 设置指定键的值 - 泛型方法，根据类型调用不同的SP方法
  Future<bool> setValue<T>(String key,T value) async{
    bool? ok;
    switch(T){
      case bool:
        ok = await _preferences?.setBool(key, value as bool); // 布尔值
        break;
      case int:
        ok = await _preferences?.setInt(key, value as int); // 整数
        break;
      case double:
        ok = await _preferences?.setDouble(key, value as double); // 浮点数
        break;
      case String:
        ok = await _preferences?.setString(key, value as String); // 字符串
        break;
      case List:
        ok = await _preferences?.setStringList(key, value as List<String>); // 字符串列表
        break;
      default:
        assert(false, 'type error: $T, key: $key'); // 断言：不支持的类型
        return false;
    }
    return ok == true;
  }

  /// 移除指定键的值
  Future<bool> removeValue(String key) async =>
      await _preferences?.remove(key) ?? false;

  // 以下方法注释掉，暂不开放
  // Future<bool> clear() async => await _preferences.clear(); // 清空所有数据
  // Future<void> reload() async => await _preferences.reload(); // 重新加载数据
}