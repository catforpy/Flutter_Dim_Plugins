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

/// 字符序列核心接口
/// 补充说明：该接口定义了字符串的核心操作规范，等价于 Dart 原生 String 类的核心行为抽象，
/// 目的是为自定义字符序列实现提供统一标准（如不可变字符串、分段字符串等）
abstract interface class CharSequence {
  /// 给定[index]位置的字符（以单代码单元[String]形式返回）。
  /// 返回的字符串恰好表示一个 UTF-16 代码单元，该代码单元可能是
  /// 代理对（surrogate pair）的一半。代理对中的单个成员是无效的 UTF-16 字符串：
  /// ```dart
  /// var clef = '\u{1D11E}';
  /// // 以下返回的是无效的 UTF-16 字符串
  /// clef[0].codeUnits;      // [0xD834]
  /// clef[1].codeUnits;      // [0xDD1E]
  /// ```
  /// 补充说明：UTF-16 代理对用于表示 Unicode 基本多文种平面（BMP）外的字符（如emoji、特殊符号），
  /// 这类字符需要两个 UTF-16 代码单元组合表示，单独取其中一个会得到无效的孤立代理字符。
  /// 该方法等价于：`String.fromCharCode(this.codeUnitAt(index))`.
  String operator [](int index);

  /// 返回给定[index]位置的 16 位 UTF-16 代码单元值。
  /// 补充说明：返回值是整数类型（如 0xD834），代表该位置字符的 UTF-16 编码值，
  /// 区别于 [operator []] 返回的字符串形式。
  int codeUnitAt(int index);

  /// 字符串的长度。
  /// 返回该字符串中 UTF-16 代码单元的数量。如果字符串包含基本多文种平面
  /// （平面 0）以外的字符，则 [runes] 的数量可能更少：
  /// ```dart
  /// 'Dart'.length;          // 4
  /// 'Dart'.runes.length;    // 4
  ///
  /// var clef = '\u{1D11E}';
  /// clef.length;            // 2 （2个UTF-16代码单元）
  /// clef.runes.length;      // 1 （1个Unicode码点）
  /// ```
  /// 补充说明：
  /// - length：统计 UTF-16 代码单元数量（所有字符至少占 1 个，BMP 外字符占 2 个）；
  /// - runes.length：统计 Unicode 码点（字符）数量（每个字符无论编码长度都算 1 个）。
  int get length;

  /*
  /// 基于字符串代码单元生成的哈希码。
  /// 该哈希码与 [operator ==] 兼容：具有相同代码单元序列的字符串哈希码相同。
  int get hashCode;

  /// 判断[other]是否是具有相同代码单元序列的`String`。
  /// 该方法逐字节比较字符串的每个代码单元，不检查 Unicode 等价性。
  /// 例如，以下两个字符串都表示 'Amélie'，但由于编码方式不同，判定为不相等：
  /// ```dart
  /// 'Am\xe9lie' == 'Ame\u{301}lie'; // false
  /// ```
  /// 第一个字符串将 'é' 编码为单个 Unicode 代码单元（也是单个码点），
  /// 而第二个字符串将其编码为 'e' 加组合重音字符 '◌́'。
  bool operator ==(Object other);
   */

  /// 将此字符串与[other]进行比较。
  /// 返回值规则：
  /// - 负数：`this` 排序在 `other` 之前；
  /// - 正数：`this` 排序在 `other` 之后；
  /// - 零：`this` 和 `other` 等价。
  /// 排序规则：比较首个不同位置的代码单元值；若一个字符串是另一个的前缀，
  /// 则较短的字符串排在前面；若内容完全相同则等价。
  /// 排序不检查 Unicode 等价性，且区分大小写。
  /// ```dart
  /// var relation = 'Dart'.compareTo('Go');
  /// print(relation); // < 0 （Dart 排在 Go 前）
  /// relation = 'Go'.compareTo('Forward');
  /// print(relation); // > 0 （Go 排在 Forward 后）
  /// relation = 'Forward'.compareTo('Forward');
  /// print(relation); // 0 （完全等价）
  /// ```
  /// 补充说明：比较基于字符的 ASCII 码值（如大写字母 < 小写字母，'A'(65) < 'a'(97)）。
  int compareTo(String other);

  /// 判断此字符串是否以[other]结尾。
  /// 示例：
  /// ```dart
  /// const string = 'Dart is open source';
  /// print(string.endsWith('urce')); // true
  /// ```
  /// 补充说明：匹配是精确的（区分大小写、区分字符编码），且[other]必须是连续的后缀。
  bool endsWith(String other);

  /// 判断此字符串是否以匹配[pattern]的子串开头。
  /// ```dart
  /// const string = 'Dart is open source';
  /// print(string.startsWith('Dar')); // true
  /// print(string.startsWith(RegExp(r'[A-Z][a-z]'))); // true
  /// ```
  /// 若指定[index]，则检查从该位置开始的子串是否以匹配[pattern]的内容开头：
  /// ```dart
  /// const string = 'Dart';
  /// print(string.startsWith('art', 0)); // false
  /// print(string.startsWith('art', 1)); // true
  /// print(string.startsWith(RegExp(r'\w{3}'), 2)); // false
  /// ```
  /// 约束：[index] 不能为负数，且不能大于字符串长度。
  /// 补充说明：若正则表达式包含 '^'（行首匹配），且[index]>0 且正则非多行模式，
  /// 则无法匹配（因为 '^' 仅匹配整个字符串的开头，而非子串开头）：
  /// ```dart
  /// const string = 'Dart';
  /// print(string.startsWith(RegExp(r'^art'), 1)); // false
  /// print(string.startsWith(RegExp(r'art'), 1)); // true
  /// ```
  bool startsWith(Pattern pattern, [int index = 0]);

  /// 返回[pattern]在该字符串中首次匹配的起始位置（从[start]开始，包含[start]）：
  /// ```dart
  /// const string = 'Dartisans';
  /// print(string.indexOf('art')); // 1
  /// print(string.indexOf(RegExp(r'[A-Z][a-z]'))); // 0
  /// ```
  /// 若未找到匹配项则返回 -1：
  /// ```dart
  /// const string = 'Dartisans';
  /// string.indexOf(RegExp(r'dart')); // -1
  /// ```
  /// 约束：[start] 不能为负数，且不能大于字符串长度。
  /// 补充说明：匹配是区分大小写的，且返回的是匹配子串的第一个字符的索引。
  int indexOf(Pattern pattern, [int start = 0]);

  /// 返回[pattern]在该字符串中最后一次匹配的起始位置。
  /// 从[start]位置反向搜索，找到[pattern]的匹配项：
  /// ```dart
  /// const string = 'Dartisans';
  /// print(string.lastIndexOf('a')); // 6
  /// print(string.lastIndexOf(RegExp(r'a(r|n)'))); // 6
  /// ```
  /// 若未找到匹配项则返回 -1：
  /// ```dart
  /// const string = 'Dartisans';
  /// print(string.lastIndexOf(RegExp(r'DART'))); // -1
  /// ```
  /// 若省略[start]，则从字符串末尾开始搜索；若指定[start]，则[start]不能为负数，
  /// 且不能大于字符串长度。
  /// 补充说明：反向搜索仅改变查找方向，匹配的子串仍需是正向的（如 'art' 不会匹配 'tra'）。
  int lastIndexOf(Pattern pattern, [int? start]);

  /// 判断该字符串是否为空（长度为 0）。
  /// 补充说明：仅当 `length == 0` 时返回 true，空字符串 '' 会返回 true，
  /// 包含空白字符（如空格、换行）的字符串返回 false。
  bool get isEmpty;

  /// 判断该字符串是否非空（长度大于 0）。
  /// 补充说明：等价于 `!isEmpty`，是语法糖方法，提升代码可读性。
  bool get isNotEmpty;

  /// 将此字符串与[other]拼接，创建新字符串。
  /// 示例：
  /// ```dart
  /// const string = 'dart' + 'lang'; // 'dartlang'
  /// ```
  /// 补充说明：拼接操作不会修改原字符串（Dart 字符串不可变），始终返回新字符串；
  /// 若拼接 null 会抛出异常，需确保[other]非空。
  String operator +(String other);

  /// 返回该字符串从[start]（包含）到[end]（不包含）的子串。
  /// 示例：
  /// ```dart
  /// const string = 'dartlang';
  /// var result = string.substring(1); // 'artlang'
  /// result = string.substring(1, 4); // 'art'
  /// ```
  /// 约束：
  /// 1. [start] 和 [end] 必须非负，且不大于字符串长度；
  /// 2. 若指定[end]，则[end]必须大于等于[start]；
  /// 3. 若省略[end]，则默认截取到字符串末尾。
  /// 补充说明：截取操作返回新字符串，原字符串保持不变。
  String substring(int start, [int? end]);

  /// 返回去除首尾空白字符后的字符串。
  /// 若字符串包含首尾空白字符，则返回去除后的新字符串；
  /// ```dart
  /// final trimmed = '\tDart is fun\n'.trim();
  /// print(trimmed); // 'Dart is fun'
  /// ```
  /// 否则返回原字符串（避免创建不必要的新对象）：
  /// ```dart
  /// const string1 = 'Dart';
  /// final string2 = string1.trim(); // 'Dart'
  /// print(identical(string1, string2)); // true
  /// ```
  /// 空白字符定义：符合 Unicode White_Space 属性（版本 6.2+）的字符，以及 BOM 字符（0xFEFF）。
  /// 以下是 Unicode 6.3 定义的会被修剪的字符列表：
  /// ```plaintext
  ///     0009..000D    ; White_Space # Cc   <control-0009>..<control-000D>
  ///     0020          ; White_Space # Zs   SPACE（空格）
  ///     0085          ; White_Space # Cc   <control-0085>（下一行）
  ///     00A0          ; White_Space # Zs   NO-BREAK SPACE（非断行空格）
  ///     1680          ; White_Space # Zs   OGHAM SPACE MARK（欧甘文空格标记）
  ///     2000..200A    ; White_Space # Zs   EN QUAD..HAIR SPACE（各种宽度的空格）
  ///     2028          ; White_Space # Zl   LINE SEPARATOR（行分隔符）
  ///     2029          ; White_Space # Zp   PARAGRAPH SEPARATOR（段分隔符）
  ///     202F          ; White_Space # Zs   NARROW NO-BREAK SPACE（窄非断行空格）
  ///     205F          ; White_Space # Zs   MEDIUM MATHEMATICAL SPACE（中等数学空格）
  ///     3000          ; White_Space # Zs   IDEOGRAPHIC SPACE（表意字符空格，如中文全角空格）
  ///
  ///     FEFF          ; BOM                ZERO WIDTH NO_BREAK SPACE（零宽非断行空格）
  /// ```
  /// 补充说明：
  /// 1. 后续 Unicode 版本可能移除 U+0085 的空白属性，是否被修剪取决于系统的 Unicode 版本；
  /// 2. trim() 仅去除首尾空白，中间空白保留（如 'a b c'.trim() → 'a b c'）；
  /// 3. 空字符串调用 trim() 仍返回自身。
  String trim();

  /// 返回去除开头空白字符后的字符串。
  /// 与[trim]类似，但仅移除开头的空白字符：
  /// ```dart
  /// final string = ' Dart '.trimLeft();
  /// print(string); // 'Dart '
  /// ```
  /// 补充说明：
  /// 1. 仅去除字符串开头的空白，结尾空白保留；
  /// 2. 无开头空白时返回原字符串。
  String trimLeft();

  /// 返回去除结尾空白字符后的字符串。
  /// 与[trim]类似，但仅移除结尾的空白字符：
  /// ```dart
  /// final string = ' Dart '.trimRight();
  /// print(string); // ' Dart'
  /// ```
  /// 补充说明：
  /// 1. 仅去除字符串结尾的空白，开头空白保留；
  /// 2. 无结尾空白时返回原字符串。
  String trimRight();

  /// 将此字符串重复[times]次并拼接，创建新字符串。
  /// `str * n` 的结果等价于：`str + str + ...`（n 次）`... + str`。
  /// ```dart
  /// const string = 'Dart';
  /// final multiplied = string * 3;
  /// print(multiplied); // 'DartDartDart'
  /// ```
  /// 若[times]为 0 或负数，返回空字符串 ''。
  /// 补充说明：
  /// 1. [times] 必须是整数，非整数会编译报错；
  /// 2. 重复 1 次返回原字符串，避免创建新对象。
  String operator *(int times);

  /// 若字符串长度小于[width]，则在左侧填充[padding]字符至[width]长度。
  /// 返回新字符串：在原字符串左侧重复添加[padding]，直到长度达到[width]。
  /// ```dart
  /// const string = 'D';
  /// print(string.padLeft(4)); // '   D'
  /// print(string.padLeft(2, 'x')); // 'xD'
  /// print(string.padLeft(4, 'y')); // 'yyyD'
  /// print(string.padLeft(4, '>>')); // '>>>>>>D'
  /// ```
  /// 约束：
  /// 1. 若[width] ≤ 原字符串长度，直接返回原字符串；
  /// 2. 负数[width]视为 0，返回空字符串；
  /// 补充说明：
  /// 1. 若[padding]长度≠1，填充后的字符串长度可能≠[width]（如示例中用 '>>' 填充会多填）；
  /// 2. [padding] 默认值为空格 ' '；
  /// 3. 填充操作始终返回新字符串，原字符串不变。
  String padLeft(int width, [String padding = ' ']);

  /// 若字符串长度小于[width]，则在右侧填充[padding]字符至[width]长度。
  /// 返回新字符串：在原字符串右侧重复添加[padding]，直到长度达到[width]。
  /// ```dart
  /// const string = 'D';
  /// print(string.padRight(4)); // 'D    '
  /// print(string.padRight(2, 'x')); // 'Dx'
  /// print(string.padRight(4, 'y')); // 'Dyyy'
  /// print(string.padRight(4, '>>')); // 'D>>>>>>'
  /// ```
  /// 约束：
  /// 1. 若[width] ≤ 原字符串长度，直接返回原字符串；
  /// 2. 负数[width]视为 0，返回空字符串；
  /// 补充说明：
  /// 1. 若[padding]长度≠1，填充后的字符串长度可能≠[width]；
  /// 2. [padding] 默认值为空格 ' '；
  /// 3. 与 padLeft 仅填充方向不同，其他规则完全一致。
  String padRight(int width, [String padding = ' ']);

  /// 判断该字符串是否包含匹配[other]的子串。
  /// 示例：
  /// ```dart
  /// const string = 'Dart strings';
  /// final containsD = string.contains('D'); // true
  /// final containsUpperCase = string.contains(RegExp(r'[A-Z]')); // true
  /// ```
  /// 若指定[startIndex]，则仅检查从该位置开始（包含）是否存在匹配：
  /// ```dart
  /// const string = 'Dart strings';
  /// final containsD = string.contains(RegExp('D'), 0); // true
  /// final caseSensitive = string.contains(RegExp(r'[A-Z]'), 1); // false
  /// ```
  /// 约束：[startIndex] 不能为负数，且不能大于字符串长度。
  /// 补充说明：
  /// 1. 匹配区分大小写（如 'd' 不等于 'D'）；
  /// 2. [other] 可以是字符串或正则表达式（Pattern 类型）。
  bool contains(Pattern other, [int startIndex = 0]);

  /// 将字符串中第一个匹配[from]的子串替换为[to]，返回新字符串。
  /// 从[startIndex]开始查找第一个匹配[from]的子串，并用[to]替换该子串。
  /// 示例：
  /// ```dart
  /// '0.0001'.replaceFirst(RegExp(r'0'), ''); // '.0001'
  /// '0.0001'.replaceFirst(RegExp(r'0'), '7', 1); // '0.7001'
  /// ```
  /// 补充说明：
  /// 1. 仅替换第一个匹配项，后续匹配项保持不变；
  /// 2. 若未找到匹配项，返回原字符串；
  /// 3. [to] 是字面量字符串，不会解析正则表达式（如 '$1' 不会被视为分组引用）。
  String replaceFirst(Pattern from, String to, [int startIndex = 0]);

  /// 将字符串中第一个匹配[from]的子串替换为自定义逻辑生成的字符串。
  /// ```dart
  /// const string = 'Dart is fun';
  /// print(string.replaceFirstMapped(
  ///     'fun', (m) => 'open source')); // Dart is open source
  ///
  /// print(string.replaceFirstMapped(
  ///     RegExp(r'\w(\w*)'), (m) => '<${m[0]}-${m[1]}>')); // <Dart-art> is fun
  /// ```
  /// 返回新字符串：原字符串中从[startIndex]开始的第一个匹配[from]的子串，
  /// 会被 [replace] 回调函数的返回值替换。
  /// 约束：[startIndex] 不能为负数，且不能大于字符串长度。
  /// 补充说明：
  /// 1. [replace] 回调接收 Match 对象，可获取匹配的子串、分组等信息；
  /// 2. 适合需要根据匹配内容动态生成替换值的场景（如正则分组引用）。
  String replaceFirstMapped(Pattern from, String Function(Match match) replace,
      [int startIndex = 0]);

  /// 将字符串中所有匹配[from]的非重叠子串替换为[replace]，返回新字符串。
  /// 查找所有匹配[from]的非重叠子串（通过 `from.allMatches(thisString)` 迭代），
  /// 并用字面量字符串[replace]替换这些子串。
  /// ```dart
  /// 'resume'.replaceAll(RegExp(r'e'), 'é'); // 'résumé'
  /// ```
  /// 注意：[replace] 是字面量字符串，不会被解析（如正则分组引用 '$1' 会被原样保留）。
  /// 若替换逻辑依赖匹配内容（如正则分组），请使用 [replaceAllMapped] 方法。
  /// 补充说明：
  /// 1. 替换所有非重叠的匹配项（如 'aaa' 替换 'aa' 会得到 'a'，而非空）；
  /// 2. 未找到匹配项时返回原字符串。
  String replaceAll(Pattern from, String replace);

  /// 将字符串中所有匹配[from]的子串替换为自定义逻辑生成的字符串。
  /// 创建新字符串：所有匹配[from]的非重叠子串，会被 [replace] 回调的返回值替换。
  /// 该方法适用于替换逻辑依赖匹配内容的场景（区别于 [replaceAll] 的固定替换值）。
  /// [replace] 回调接收每个匹配项的 Match 对象，其返回值作为替换内容。
  /// 以下示例将字符串中的每个单词转换为简化版「猪拉丁语」：
  /// ```dart
  /// String pigLatin(String words) => words.replaceAllMapped(
  ///     RegExp(r'\b(\w*?)([aeiou]\w*)', caseSensitive: false),
  ///     (Match m) => "${m[2]}${m[1]}${m[1]!.isEmpty ? 'way' : 'ay'}");
  ///
  /// final result = pigLatin('I have a secret now!');
  /// print(result); // 'Iway avehay away ecretsay ownay!'
  /// ```
  /// 补充说明：
  /// 1. 替换所有非重叠的匹配项；
  /// 2. 可通过 Match 对象获取分组、匹配位置等信息，支持动态替换；
  /// 3. 未找到匹配项时返回原字符串。
  String replaceAllMapped(Pattern from, String Function(Match match) replace);

  /// 将字符串中[start]到[end]的子串替换为[replacement]，返回新字符串。
  /// 等价于以下逻辑：
  /// ```dart
  /// this.substring(0, start) + replacement + this.substring(end)
  /// ```
  /// 示例：
  /// ```dart
  /// const string = 'Dart is fun';
  /// final result = string.replaceRange(8, null, 'open source');
  /// print(result); // Dart is open source
  /// ```
  /// 约束：
  /// 1. `0 <= start <= end <= length`；
  /// 2. 若[end]为 null，默认替换到字符串末尾。
  /// 补充说明：
  /// 1. 替换的是指定索引范围的子串，而非匹配模式的子串；
  /// 2. [replacement] 可以是空字符串（即删除指定范围的子串）。
  String replaceRange(int start, int? end, String replacement);

  /// 按[pattern]的匹配项分割字符串，返回子串列表。
  /// 通过 `from.allMatches(thisString)` 查找所有匹配项，将字符串分割为：
  /// - 第一个匹配项之前的子串；
  /// - 匹配项之间的子串；
  /// - 最后一个匹配项之后的子串。
  /// ```dart
  /// const string = 'Hello world!';
  /// final splitted = string.split(' ');
  /// print(splitted); // [Hello, world!];
  /// ```
  /// 若模式未匹配到任何内容，返回仅包含原字符串的列表。
  /// 若[pattern]是字符串，则始终满足：
  /// ```dart
  /// string.split(pattern).join(pattern) == string
  /// ```
  /// 补充规则：
  /// 1. 若开头是空匹配项，其前的空子串不加入结果；
  /// 2. 若结尾是空匹配项，其后的空子串不加入结果；
  /// 3. 若空匹配项紧跟前一个匹配项，中间的空子串不加入结果。
  /// ```dart
  /// const string = 'abba';
  /// final re = RegExp(r'b*');
  /// // re.allMatches(string) 会找到 4 个匹配项：
  /// // - 第一个 'a' 前的空匹配；
  /// // - 'bb' 匹配；
  /// // - 'bb' 后、第二个 'a' 前的空匹配；
  /// // - 第二个 'a' 后的空匹配。
  /// print(string.split(re)); // [a, a]
  /// ```
  /// 若开头/结尾/匹配项后是非空匹配，会在结果中引入空子串：
  /// ```dart
  /// const string = 'abbaa';
  /// final splitted = string.split('a'); // ['', 'bb', '', '']
  /// ```
  /// 若原字符串是空字符串：
  /// - 若模式匹配空字符串，返回空列表（开头/结尾的空匹配被忽略）；
  /// - 若模式不匹配，返回仅包含空字符串的列表 [""]。
  /// ```dart
  /// const string = '';
  /// print(string.split('')); // []
  /// print(string.split('a')); // [""]
  /// ```
  /// 若模式为空字符串，将字符串分割为单个 UTF-16 代码单元的字符串列表：
  /// ```dart
  /// const string = 'Pub';
  /// print(string.split('')); // [P, u, b]
  /// // Same as:
  /// var codeUnitStrings = [
  ///   for (final unit in string.codeUnits) String.fromCharCode(unit)
  /// ];
  /// print(codeUnitStrings); // [P, u, b]
  /// ```
  /// 补充说明：
  /// 1. 分割基于 UTF-16 代码单元，而非 Unicode 码点（代理对会被拆分为两个元素）；
  /// 2. 要按 Unicode 码点分割，应遍历 runes 而非使用 split('')：
  /// ```dart
  /// const string = '\u{1F642}';
  /// for (final rune in string.runes) {
  ///   print(String.fromCharCode(rune));
  /// }
  /// ```
  List<String> split(Pattern pattern);

  /// 分割字符串、转换各部分内容，并将转换后的结果拼接为新字符串。
  /// 分割规则：
  /// 1. [pattern] 用于将字符串分割为「匹配部分」和「非匹配部分」；
  /// 2. 每个匹配项（通过 [Pattern.allMatches] 获取）视为「匹配部分」；
  /// 3. 两个匹配项之间、开头到第一个匹配项、最后一个匹配项到结尾的子串视为「非匹配部分」；
  /// 4. 不忽略任何空部分（区别于 split 方法）。
  /// 转换规则：
  /// 1. 「匹配部分」通过 [onMatch] 回调转换（省略则使用匹配的子串）；
  /// 2. 「非匹配部分」通过 [onNonMatch] 回调转换（省略则使用原字符串）。
  /// 最终结果：将所有转换后的部分按顺序拼接为新字符串。
  /// ```dart
  /// final result = 'Eats shoots leaves'.splitMapJoin(RegExp(r'shoots'),
  ///     onMatch: (m) => '${m[0]}', // (or no onMatch at all)
  ///     onNonMatch: (n) => '*');
  /// print(result); // *shoots*
  /// ```
  /// 补充说明：该方法整合了「分割 + 转换 + 拼接」，避免多次遍历字符串，性能优于分步操作。
  String splitMapJoin(Pattern pattern,
      {String Function(Match)? onMatch, String Function(String)? onNonMatch});

  /// 该字符串的 UTF-16 代码单元组成的不可修改列表。
  /// 补充说明：
  /// 1. 列表元素为整数（如 'A' → 65）；
  /// 2. 列表不可修改（调用 add/remove 会抛出异常）；
  /// 3. 长度与 `length` 属性一致。
  List<int> get codeUnits;

  /// 该字符串的 Unicode 码点组成的可迭代对象。
  /// 若字符串包含代理对，会将其合并为单个整数返回；未匹配的代理半部分会被视为
  /// 有效的 16 位代码单元。
  /// 补充说明：
  /// 1. 每个元素代表一个 Unicode 字符（码点），如 '\u{1D11E}' → [119070]；
  /// 2. 可通过 `String.fromCharCode(rune)` 转换为字符。
  Runes get runes;

  /// 将字符串中所有字符转换为小写。
  /// 若字符串已是全小写，直接返回原字符串（避免创建新对象）：
  /// ```dart
  /// 'ALPHABET'.toLowerCase(); // 'alphabet'
  /// 'abc'.toLowerCase(); // 'abc'
  /// ```
  /// 该方法使用与语言无关的 Unicode 映射规则，因此仅在部分语言中生效。
  /// 补充说明：
  /// 1. 转换是全量的（所有大写字符都会转小写，如 'Dart' → 'dart'）；
  /// 2. 不支持语言特定的大小写转换（如土耳其语的 'I' 转 'ı' 而非 'i'）。
  String toLowerCase();

  /// 将字符串中所有字符转换为大写。
  /// 若字符串已是全大写，直接返回原字符串：
  /// ```dart
  /// 'alphabet'.toUpperCase(); // 'ALPHABET'
  /// 'ABC'.toUpperCase(); // 'ABC'
  /// ```
  /// 该方法使用与语言无关的 Unicode 映射规则，因此仅在部分语言中生效。
  /// 补充说明：
  /// 1. 转换是全量的（所有小写字符都会转大写，如 'dart' → 'DART'）；
  /// 2. 特殊字符（如数字、符号）保持不变。
  String toUpperCase();
}