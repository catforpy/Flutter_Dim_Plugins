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
import 'package:mkm/protocol.dart';
import 'package:mkm/type.dart';

/// 基础资产消息类（通用货币消息）
/// 设计目的：封装IM中的资产相关消息（如余额查询、收款通知），核心字段为币种+金额
class BaseMoneyContent extends BaseContent implements MoneyContent {
  /// 构造方法1：从字典初始化(解析网络传输的资产消息)
  BaseMoneyContent([super.dict]);

  /// 构造方法2：从消息类型+币种+金额初始化（自定义资产消息类型）
  /// @param msgType - 消息类型
  /// @param currency - 币种（如CNY、USD、BTC）
  /// @param amount - 金额（数值类型）
  BaseMoneyContent.fromType(
    String msgType, {
    required String currency,
    required num amount,
  }) : super.fromType(msgType) {
    this['currency'] = currency;
    this['amount'] = amount;
  }

  /// 构造方法3：默认资产消息类型 + 币种+金额初始化（最常用）
  /// @param currency - 币种
  /// @param amount - 金额
  BaseMoneyContent.from({required String currency, required num amount})
    : this.fromType(ContentType.MONEY, currency: currency, amount: amount);

  /// 获取币种（空字符串表示未设置）
  @override
  String get currency => getString('currency') ?? '';

  /// 获取金额（解析字典中的amount字段，兼容数值/字符串类型，默认返回0）
  @override
  num get amount {
    var val = this['amount'];
    if (val is num) {
      return val;
    }
    // 非数值类型时，尝试转为浮点数
    return Converter.getDouble(val) ?? 0;
  }

  /// 设置金额（同步更新字典中的amount字段）
  @override
  set amount(num value) => this['amount'] = value;
}

/// 转账消息类（继承基础资产消息，扩展付款人/收款人字段）
/// 设计目的：封装IM中的转账业务消息，明确转账的付款方和收款方
class TransferMoneyContent extends BaseMoneyContent implements TransferContent {
  /// 构造方法1：从字典初始化（解析网络传输的转账消息）
  TransferMoneyContent([super.dict]);

  /// 构造方法2：默认转账消息类型 + 币种+金额初始化
  /// @param currency - 币种
  /// @param amount - 金额
  TransferMoneyContent.from({required String currency, required num amount})
    : super.fromType(ContentType.TRANSFER, currency: currency, amount: amount);

  /// 获取付款人ID（null表示未设置）
  @override
  ID? get remitter => ID.parse(this['remitter']);

  /// 设置付款人ID（同步更新字典中的remitter字段）
  @override
  set remitter(ID? sender) => setString('remitter', sender);

  /// 获取收款人ID（null表示未设置）
  @override
  ID? get remittee => ID.parse(this['remittee']);

  /// 设置收款人ID（同步更新字典中的remittee字段）
  @override
  set remittee(ID? receiver) => setString('remittee', receiver);
}
