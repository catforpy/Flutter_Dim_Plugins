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

/// 键值对/二元组（不可变）
/// 核心作用：将两个不同类型的值封装成一个不可变对象，用于需要返回/传递两个关联数据的场景
/// 典型使用场景：
/// 1. 方法需要返回两个关联值（如：返回命令+消息、返回数据+状态）
/// 2. 集合中存储关联数据（如：Map的entry、列表中存储键值对）
/// 3. 避免创建临时类来封装少量关联数据
/// 泛型说明：
/// A - 第一个值的类型（可任意类型，如ID、String、Command等）
/// B - 第二个值的类型（可任意类型，如ReliableMessage、int、List等）
class Pair<A,B>{
  /// 构造函数：创建不可变的二元组
  /// [first] - 第一个值（泛型A）
  /// [second] - 第二个值（泛型B）
  /// 注意：构造函数用const修饰，创建的是编译时常量，不可修改内部值
  const Pair(this.first,this.second);

  /// 第一个值(泛型A)：不可变，初始化后无法修改
  /// 示例：存储群组命令（GroupCommand）、用户ID（ID）、状态码（int）等
  final A first;

  /// 第二个值(泛型B)：不可变，初始化后无法修改
  /// 示例：存储可靠消息（ReliableMessage）、消息内容（Content）、描述信息（String）等
  final B second;

  /// 重写相等运算符（==）：自定义两个Pair对象的相等判断规则
  /// [other] - 待比较的另一个对象
  /// 返回：true=两个Pair相等，false=不相等
  /// 相等条件：
  /// 1. 是同一个对象（identical）
  /// 2. 是Pair类型，且first和second的值分别相等（支持null值判断）
  @override
  bool operator ==(Object other) {
    if(other is Pair){
      if(identical(this, other)){
        // 同一对象引用，直接返回相等
        return true;
      }
      // 两个值都相等则Pair相等（调用工具方法处理null值）
      return _objectEquals(first, other.first)
        && _objectEquals(second, other.second);
    }
    return false;
  }

  /// 重写哈希值（hashCode）：保证相等的Pair对象哈希值相同
  /// 设计逻辑：结合first和second的哈希值，避免哈希冲突
  /// 作用：Pair作为Map的key/Set的元素时，能正确判断唯一性
  @override
  int get hashCode => Object.hash(first, second);

  /// 获取运行时类型名称（仅调试用）
  /// 作用：调试时能看到Pair的真实泛型类型（如Pair<ResetCommand, ReliableMessage>）
  String get className => _runtimeType(this,'Pair');

  /// 重写字符串格式化：方便调试时直观查看Pair内容
  /// 输出格式示例：
  /// <Pair<ResetCommand, ReliableMessage>>
  ///   <a>ResetCommand{group: 123456, members: [user1, user2]}</a>
  ///   <b>ReliableMessage{sender: admin, receiver: 123456}</b>
  /// </Pair>
  @override
  String toString(){
    String clazz = className;
    return '<$clazz>\n\t<a>$first</a>\n\t<b>$second</b>\n</$clazz>';
  }

}

/// 三元组（不可变）：封装三个不同类型的值，逻辑与Pair一致
/// 核心作用：需要返回/传递三个关联数据时使用（比Pair多一个值）
/// 典型使用场景：
/// 1. 方法需要返回三个关联值（如：数据+状态+描述、命令+消息+时间戳）
/// 2. 避免创建临时类封装三个关联数据
/// 泛型说明：
/// A - 第一个值的类型
/// B - 第二个值的类型
/// C - 第三个值的类型
class Triplet<A,B,C>{
  /// 构造函数：初始化第一个、第二个、第三个值（不可变）
  /// [first] - 第一个值（泛型A）
  /// [second] - 第二个值（泛型B）
  /// [third] - 第三个值（泛型C）
  const Triplet(this.first,this.second,this.third);

  /// 第一个值（泛型A）：不可变，初始化后无法修改
  final A first;

  /// 第二个值（泛型B）：不可变，初始化后无法修改
  final B second;

  /// 第三个值（泛型C）：不可变，初始化后无法修改
  final C third;

  /// 重写相等运算符：判断两个Triplet是否相等
  /// 相等条件：
  /// 1. 是同一个对象（identical）
  /// 2. 是Triplet类型，且first/second/third的值分别相等（支持null值）
  @override
  bool operator ==(Object other) {
    if(other is Triplet)
    {
      if(identical(this, other))
      {
        // 同一对象引用，直接返回相等
        return true;
      }
      /// 三个值都相等则Triplet相等（调用工具方法处理null值）
      return _objectEquals(first, other.first)
        && _objectEquals(second, other.second)
        && _objectEquals(third, other.third);
    }
    return false;
  }

  /// 【注意】原代码缺失hashCode重写，补充说明：
  /// 规范写法应重写hashCode，保证相等的Triplet哈希值相同：
  /// @override
  /// int get hashCode => Object.hash(first, second, third);

  /// 【注意】原代码缺失toString重写，补充说明：
  /// 调试用格式化输出建议：
  /// @override
  /// String toString() {
  ///   String clazz = _runtimeType(this, 'Triplet');
  ///   return '<$clazz>\n\t<a>$first</a>\n\t<b>$second</b>\n\t<c>$third</c>\n</$clazz>';
  /// }
}


/// 工具方法：安全判断两个对象是否相等（处理null值）
/// 解决问题：直接用==判断时，null == null 返回true，但obj == null 需特殊处理
/// [obj1] - 第一个待比较对象（可null）
/// [obj2] - 第二个待比较对象（可null）
/// 返回：两个对象是否相等
/// 逻辑：
/// 1. obj1为null → 只有obj2也为null时相等
/// 2. obj1非null → obj2为null则不相等；否则用==判断
bool _objectEquals(Object? obj1,Object? obj2){
  if(obj1 == null){
    // 第一个对象为Null时，第二个也必须为null才相等
    return obj2 == null;
  }else if(obj2 == null)
  {
    // 第一个非Null ,第二个为null ,不相等
    return false;
  }else{
    // 都非null 直接用==判断
    return obj1 == obj2;
  }
}

/// 工具方法：获取对象的运行时类型名称（仅调试模式生效）
/// 作用：调试时能看到泛型的具体类型（如Pair<ResetCommand, ReliableMessage>），而非默认的Pair
/// [object] - 目标对象（如Pair/Triplet实例）
/// [className] - 默认类型名（如"Pair"）
/// 返回：调试模式返回真实运行时类型名，生产模式返回默认名
String _runtimeType(Object object,String className){
  assert((){
    // 调试模式下（assert生效），更新为真实的运行时类型名
    className = object.runtimeType.toString();
    return true;
  }());
  return className;
}