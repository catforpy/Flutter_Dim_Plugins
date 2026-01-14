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


/// 数据转换工具接口
/// ~~~~~~~~~~~~~~~~~~~~~~
/// 补充说明：提供通用的类型转换能力（String/bool/int/double/DateTime），
/// 支持自定义转换器实现，默认使用 BaseConverter
abstract class Converter {

  /// 布尔值状态映射表
  /// 补充说明：
  /// - 键：支持的布尔值字符串（不区分大小写）；
  /// - 值：对应的布尔值；
  /// - 用于将字符串/数字等类型转换为布尔值
  static final Map<String,bool> BOOLEAN_STATES={
    '1': true, 'yes': true, 'true': true, 'on': true,

    '0': false, 'no': false, 'false': false, 'off': false,
    //'+0': false, '-0': false, '0.0': false, '+0.0': false, '-0.0': false,
    'null': false, 'none': false, 'undefined': false,
  };

  /// 布尔值字符串最大长度
  /// 补充说明：限制转换布尔值时的字符串长度，避免无效长字符串解析，
  /// 取值为最长键 'undefined' 的长度（9）
  static/* final*/ int MAX_BOOLEAN_LEN = 'undefined'.length;

  /// 将任意类型值转换为字符串
  /// [value] - 待转换值
  /// [defaultValue] - 转换失败时返回的默认值
  static String? getString(Object? value, [String? defaultValue]) =>
      converter.getString(value, defaultValue);

  /// 将任意类型值转换为布尔值
  /// 补充说明：支持的输入类型：
  /// - bool：直接返回；
  /// - num：1/1.0 → true，0/0.0 → false；
  /// - String：匹配 BOOLEAN_STATES 中的键（忽略大小写/首尾空白）；
  /// [value] - 待转换值（支持 'true'/'false'/'yes'/'no'/'1'/'0' 等字符串）
  /// [defaultValue] - 转换失败时返回的默认值
  static bool? getBool(Object? value, [bool? defaultValue]) =>
      converter.getBool(value, defaultValue);

  /// 将任意类型值转换为整型
  /// [value] - 待转换值
  /// [defaultValue] - 转换失败时返回的默认值
  static int? getInt(Object? value, [int? defaultValue]) =>
      converter.getInt(value, defaultValue);

  /// 将任意类型值转换为浮点型
  /// [value] - 待转换值
  /// [defaultValue] - 转换失败时返回的默认值
  static double? getDouble(Object? value, [double? defaultValue]) =>
      converter.getDouble(value, defaultValue);

  /// 将任意类型值转换为 DateTime
  /// 补充说明：
  /// - 支持的输入类型：DateTime（直接返回）、num/String（视为时间戳，单位：秒）；
  /// - 时间戳范围：>=0（否则抛出异常）；
  /// [value] - 待转换值（时间戳，秒级，从 1970-01-01 00:00:00 开始）
  /// [defaultValue] - 转换失败时返回的默认值
  static DateTime? getDateTime(Object? value, [DateTime? defaultValue]) =>
      converter.getDateTime(value, defaultValue);

  /// 全局默认转换器
  /// 补充说明：可替换为自定义的 DataConverter 实现，实现特殊转换逻辑
  static DataConverter converter = BaseConverter();
}

/// 数据转换核心接口
/// 补充说明：定义各类类型转换的标准方法，便于扩展自定义转换逻辑
abstract interface class DataConverter {
  /// 转换为字符串
  String?     getString(Object? value, String?   defaultValue);

  /// 转换为布尔值
  bool?         getBool(Object? value, bool?     defaultValue);

  /// 转换为整型
  int?           getInt(Object? value, int?      defaultValue);

  /// 转换为浮点型
  double?     getDouble(Object? value, double?   defaultValue);

  /// 转换为 DateTime
  DateTime? getDateTime(Object? value, DateTime? defaultValue);
}

/// 默认数据转换器实现
/// 补充说明：实现 DataConverter 接口，提供基础的类型转换逻辑，
/// 所有转换失败场景（如非数字字符串转int）会抛出异常，需通过 defaultValue 兜底
class BaseConverter implements DataConverter {

  @override
  String? getString(Object? value, String? defaultValue){
    if(value == null){
      return defaultValue;
    }else if(value is String){
      // 精确匹配了字符串类型
      return value;
    }else{
      // 转换为字符串
      return value.toString();
    }
  }

  /// 私有方法：将任意值转为字符串（非 null）
  /// 补充说明：null 会被上层方法处理，此处确保 value 非 null
  String getStr(Object value) => value is String
      ? value
      : value.toString();

  @override
  bool? getBool(Object? value,bool? defaultValue){
    if(value == null){
      return defaultValue;
    }else if(value is bool){
      // 精确匹配布尔类型
      return value;
    }else if(value is num){
      // int,double-数字类型
      if(value is double){
        assert(value == 1.0 || value == 0.0, 'bool value error: $value');
        return value != 0.0;
      }
      assert(value == 1 || value == 0, 'bool value error: $value');
      return value != 0;
    }
    String text = getStr(value);
    text = text.trim(); //去除首位空白
    int size = text.length;
    if(size == 0){
      return false; //空字符串视为 false
    }else if(size > Converter.MAX_BOOLEAN_LEN){
      throw FormatException('bool value error: "$value"'); // 超长字符串抛出异常
    }else{
      text = text.toLowerCase();  // 同一转为小写匹配
    }
    bool? state = Converter.BOOLEAN_STATES[text];
    if(state == null){
      throw FormatException('bool value error: "$value"'); // 无匹配值抛出异常
    }
    return state;
  }

  @override
  int? getInt(Object? value, int? defaultValue) {
    if (value == null) {
      return defaultValue;
    } else if (value is int) {
      // exactly - 精确匹配整型
      return value;
    } else if (value is num) {  // double - 浮点型转整型
      // assert(false, 'not an int value: $value');
      return value.toInt();
    } else if (value is bool) {
      return value ? 1 : 0; // 布尔值转 1/0
    }
    String str = getStr(value);
    return int.parse(str); // 字符串解析为整型（失败会抛出 FormatException）
  }

  @override
  double? getDouble(Object? value, double? defaultValue) {
    if (value == null) {
      return defaultValue;
    } else if (value is double) {
      // exactly - 精确匹配浮点型
      return value;
    } else if (value is num) {  // int - 整型转浮点型
      // assert(false, 'not a double value: $value');
      return value.toDouble();
    } else if (value is bool) {
      return value ? 1.0 : 0.0; // 布尔值转 1.0/0.0
    }
    String str = getStr(value);
    return double.parse(str); // 字符串解析为浮点型（失败会抛出 FormatException）
  }

  @override
  DateTime? getDateTime(Object? value, DateTime? defaultValue) {
    if (value == null) {
      return defaultValue;
    } else if (value is DateTime) {
      // exactly - 精确匹配 DateTime 类型
      return value;
    }
    double? seconds = getDouble(value, null);
    if (seconds == null || seconds < 0) {
      throw FormatException('Timestamp error: "$value"'); // 无效时间戳抛出异常
    }
    double millis = seconds * 1000; // 秒转毫秒
    return DateTime.fromMillisecondsSinceEpoch(millis.toInt());
  }

}