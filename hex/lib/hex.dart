/// 引入dart内置库：
/// - convert：提供编解码基础能力
/// - typed_data：提供TypedData类型（如Uint8List），用于高效处理字节数据
library hex;

import "dart:convert";
import "dart:typed_data";

/// 十六进制字符集（小写），用于解码时匹配字符对应的数值
/// 索引0-15分别对应字符'0'-'9','a'-'f'
const String _ALPHABET = "0123456789abcdef";

/// 全局默认的十六进制编解码实例
/// 对外提供便捷调用入口，无需手动创建HexCodec对象
const HEX = const HexCodec();

/// 十六进制编解码器核心类
/// 实现Codec抽象类，定义字节数组(List<int>) ↔ 十六进制字符串(String)的双向转换能力
class HexCodec extends Codec<List<int>, String> {

  /// 构造函数（常量构造函数，确保全局单例）
  const HexCodec();

  /// 获取编码器：字节数组 → 十六进制字符串
  @override
  Converter<List<int>, String> get encoder => const HexEncoder();

  /// 获取解码器：十六进制字符串 → 字节数组
  @override
  Converter<String, List<int>> get decoder => const HexDecoder();

}

/// 十六进制编码器
/// 将字节数组（List<int>）转换为十六进制字符串
class HexEncoder extends Converter<List<int>, String> {

  /// 配置项：是否输出大写的十六进制字符串
  /// 默认值为false（输出小写）
  final bool upperCase;

  /// 构造函数
  /// [upperCase] - 可选参数，指定编码结果是否大写，默认小写
  const HexEncoder({bool this.upperCase=false});

  /// 核心编码方法：将字节数组转换为十六进制字符串
  /// [bytes] - 待编码的字节数组（List<int>），每个元素必须是0-255的单字节值
  /// 返回值：十六进制字符串（小写/大写由upperCase配置）
  @override
  String convert(List<int> bytes) {
    // 创建字符串缓冲区，高效拼接字符串（避免多次String拼接的性能损耗）
    StringBuffer buffer = new StringBuffer();
    
    // 遍历每个字节，逐个转换为十六进制字符
    for (int part in bytes) {
      // 校验：确保当前值是单字节（0-255），超出则抛出格式异常
      // & 0xff 是位运算，用于过滤高8位，判断是否为单字节
      if (part & 0xff != part) {
        throw new FormatException("Non-byte integer detected");
      }
      // 转换逻辑：
      // 1. 若字节值小于16（0x0-0xf），补前导0（保证每个字节对应2位十六进制）
      // 2. 调用toRadixString(16)将整数转为十六进制字符串
      buffer.write('${part < 16 ? '0' : ''}${part.toRadixString(16)}');
    }
    
    // 根据配置返回大写/小写结果
    if(upperCase) {
      return buffer.toString().toUpperCase();
    } else {
      return buffer.toString();
    }
  }
}

/// 十六进制解码器
/// 将十六进制字符串转换为字节数组（Uint8List）
class HexDecoder extends Converter<String, List<int>> {

  /// 构造函数（常量构造函数）
  const HexDecoder();

  /// 核心解码方法：将十六进制字符串转换为字节数组
  /// [hex] - 待解码的十六进制字符串（支持大小写、带空格）
  /// 返回值：Uint8List（无符号8位整数列表，高效存储字节数据）
  @override
  List<int> convert(String hex) {
    // 步骤1：预处理字符串
    // 1. 移除所有空格（兼容带空格的十六进制字符串，如"a1 b2 c3"）
    // 2. 转为小写（统一匹配_ALPHABET字符集，避免大小写问题）
    String str = hex.replaceAll(" ", "");
    str = str.toLowerCase();
    
    // 步骤2：补位处理
    // 若字符串长度为奇数，在开头补0（保证每2位对应一个字节）
    // 例："a1b" → "0a1b"
    if(str.length % 2 != 0) {
      str = "0" + str;
    }
    
    // 步骤3：初始化结果数组
    // 长度为字符串长度的1/2（每2位十六进制对应1个字节）
    Uint8List result = new Uint8List(str.length ~/ 2);
    
    // 步骤4：逐2位解析为字节
    for(int i = 0 ; i < result.length ; i++) {
      // 取第i个字节对应的两位十六进制字符的索引
      // 第一位：i*2 位置的字符
      int firstDigit = _ALPHABET.indexOf(str[i*2]);
      // 第二位：i*2+1 位置的字符
      int secondDigit = _ALPHABET.indexOf(str[i*2+1]);
      
      // 校验：若字符不在_ALPHABET中（返回-1），说明是非十六进制字符，抛出异常
      if (firstDigit == -1 || secondDigit == -1) {
        throw new FormatException("Non-hex character detected in $hex");
      }
      
      // 计算字节值：
      // 第一位左移4位（等价于乘以16） + 第二位 = 单字节值（0-255）
      // 例："a1" → 10<<4 + 1 = 161
      result[i] = (firstDigit << 4) + secondDigit;
    }
    
    // 返回解码后的字节数组
    return result;
  }
}