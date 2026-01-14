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
import 'package:dim_flutter/src/ui/nav.dart';
import 'package:flutter/cupertino.dart';


// ------------------------ 弹窗核心逻辑：仅替换.tr为接口调用 ------------------------
/// 弹窗工具类
/// 提供系统风格的提示框、确认框、操作菜单等弹窗功能
class Alert {

  /// 显示提示框（只有确认按钮）
  /// [context] - 上下文
  /// [title] - 标题（可为空）
  /// [body] - 内容（支持String/Image/Widget）
  /// [callback] - 确认按钮点击回调
  static void show(BuildContext context, String? title, dynamic body,
      {VoidCallback? callback}) {
    // 统一内容格式：String转为Text，Image转为带尺寸的SizedBox
    if (body is String) {
      body = Text(body);
    } else if (body is Image) {
      body = SizedBox(
        height: 256,
        width: 256,
        child: body,
      );
    }
    // 显示Cupertino风格的模态弹窗
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        // 改造点1：title.tr → i18nTranslator.translate(title)
        title: title == null || title.isEmpty ? null : Text(i18nTranslator.translate(title)),
        content: body,
        actions: [
          // 确认按钮
          CupertinoDialogAction(
            isDefaultAction: true, // 设置为默认按钮
            onPressed: () {
              // 关闭弹窗
              Navigator.pop(context);
              // 执行回调
              if (callback != null) {
                callback();
              }
            },
            // 改造点2：'OK'.tr → i18nTranslator.translate('OK')
            child: Text(i18nTranslator.translate('OK')),
          ),
        ],
      ),
    );
  }

  /// 显示确认框（取消+确认按钮）
  /// [context] - 上下文
  /// [title] - 标题（可为空）
  /// [body] - 内容（支持String/Image/Widget）
  /// [okTitle] - 确认按钮文字（默认"OK"）
  /// [okAction] - 确认按钮回调
  /// [cancelTitle] - 取消按钮文字（默认"Cancel"）
  /// [cancelAction] - 取消按钮回调
  static void confirm(BuildContext context, String? title, dynamic body,
      {String? okTitle, VoidCallback? okAction,
        String? cancelTitle, VoidCallback? cancelAction}) {
    // 设置默认按钮文字
    okTitle ??= 'OK';
    cancelTitle ??= 'Cancel';
    // 统一内容格式
    if (body is String) {
      body = Text(body);
    } else if (body is Image) {
      body = SizedBox(
        height: 256,
        width: 256,
        child: body,
      );
    }
    // 显示Cupertino风格的对话框
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        // 改造点3：title.tr → 接口调用
        title: title == null || title.isEmpty ? null : Text(i18nTranslator.translate(title)),
        content: body,
        actions: [
          // 取消按钮
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              if (cancelAction != null) {
                cancelAction();
              }
            },
            // 改造点4：cancelTitle!.tr → 接口调用
            child: Text(i18nTranslator.translate(cancelTitle!)),
          ),
          // 确认按钮（破坏性操作样式）
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              if (okAction != null) {
                okAction();
              }
            },
            isDestructiveAction: true, // 红色文字样式
            // 改造点5：okTitle!.tr → 接口调用
            child: Text(i18nTranslator.translate(okTitle!)),
          ),
        ],
      ),
    );
  }

  /// 显示操作菜单（底部弹出的ActionSheet）
  /// [context] - 上下文
  /// [title] - 标题（可为空）
  /// [message] - 说明文字（可为空）
  /// [action1] - 第一个操作项（String/Widget）
  /// [callback1] - 第一个操作回调（必填）
  /// [action2] - 第二个操作项（可选）
  /// [callback2] - 第二个操作回调
  /// [action3] - 第三个操作项（可选）
  /// [callback3] - 第三个操作回调
  static void actionSheet(BuildContext context, String? title, String? message,
      dynamic action1, VoidCallback callback1, [
        dynamic action2, VoidCallback? callback2,
        dynamic action3, VoidCallback? callback3,
      ]) => showCupertinoModalPopup(context: context,
    builder: (context) => CupertinoActionSheet(
      // 改造点6：title.tr → 接口调用
      title: title == null || title.isEmpty ? null : Text(i18nTranslator.translate(title)),
      message: message == null || message.isEmpty ? null : Text(message),
      actions: [
        // 第一个操作项（必填）
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            callback1();
          },
          // 改造点7：action1.tr → 接口调用
          child: action1 is String ? Text(i18nTranslator.translate(action1)) : action1,
        ),
        // 第二个操作项（可选）
        if (action2 != null)
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              if (callback2 != null) {
                callback2();
              }
            },
            // 改造点8：action2.tr → 接口调用
            child: action2 is String ? Text(i18nTranslator.translate(action2)) : action2,
          ),
        // 第三个操作项（可选）
        if (action3 != null)
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              if (callback3 != null) {
                callback3();
              }
            },
            // 改造点9：action3.tr → 接口调用
            child: action3 is String? Text(i18nTranslator.translate(action3)) : action3,
          ),
        // 取消按钮（固定最后一个）
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDefaultAction: true,
          // 改造点10：'Cancel'.tr → 接口调用
          child: Text(i18nTranslator.translate('Cancel')),
        ),
      ],
    ),
  );

  /// 创建带图标和文字的操作项组件
  /// [icon] - 图标
  /// [text] - 文字
  static Widget action(IconData icon, String text) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon),
      const SizedBox(width: 12,), // 图标和文字间距
      // 改造点11：text.tr → 接口调用
      Text(i18nTranslator.translate(text)),
    ],
  );

}