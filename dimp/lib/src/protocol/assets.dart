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





import 'package:dimp/dkd.dart';
import 'package:dimp/mkm.dart';
// import 'package:dkd/dkd.dart';

/// 金额类消息内容接口
/// 作用：定义包含资产金额的消息结构，是转账/收款等消息的基础
/// 数据格式：{
///      type : i2s(0x40),   // 消息类型标识（0x40=金额）
///      sn   : 123,         // 消息序列号
///
///      currency : "RMB",   // 币种（如：USD、USDT、BTC等）
///      amount   : 100.00   // 金额
///  }
abstract interface class MoneyContent implements Content{
  /// 获取币种（如RMB/USD/USDT）
  String get currency;

  /// 获取金额（可读可写）
  num get amount;
  set amount(num value);

  //-------- 工厂方法 --------

  /// 创建金额消息内容
  /// @param msgType  - 消息类型（可选，默认=0x40）
  /// @param currency - 币种（必填）
  /// @param amount   - 金额（必填）
  /// @return 金额消息实例
  static MoneyContent create(String? msgType,{required String currency,required num amount}){
    if(msgType == null){
      return BaseMoneyContent.from(currency: currency, amount: amount);
    }else{
      return BaseMoneyContent.fromType(msgType, currency: currency, amount: amount);
    }
  }
}

/// 转账类消息内容接口
/// 作用：在MoneyContent基础上增加“付款人/收款人”，实现点对点转账
/// 数据格式：{
///      type : i2s(0x41),   // 消息类型标识（0x41=转账）
///      sn   : 123,         // 消息序列号
///
///      currency : "RMB",    // 币种
///      amount   : 100.00,   // 金额
///      remitter : "{FROM}", // 付款人ID
///      remittee : "{TO}"    // 收款人ID
///  }
abstract interface class TransferContent implements MoneyContent{
  /// 获取付款人ID（可读可写）
  ID? get remitter;
  set remitter(ID? sender);

  /// 获取收款人ID（可读可写）
  ID? get remittee;
  set remittee(ID? receiver);

  //-------- 工厂方法 --------

  /// 创建转账消息内容
  /// @param currency - 币种（必填）
  /// @param amount   - 金额（必填）
  /// @return 转账消息实例
  static TransferContent create({required String currency,required num amount}) =>
  TransferMoneyContent.from(currency: currency,amount: amount);
}