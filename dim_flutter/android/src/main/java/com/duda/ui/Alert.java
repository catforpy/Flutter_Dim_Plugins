package com.duda.ui;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.Context;
import android.content.DialogInterface;
import android.view.Window;
import android.widget.Toast;

/**
 * 简易提示工具类
 * 封装 Android 原生 Toast 和 AlertDialog，提供快速的用户反馈能力，
 * 主要用于音频操作异常提示、用户交互选择等场景
 */
public class Alert {

    /**
     * 显示长时 Toast 提示
     * @param context 上下文对象（Activity/Application）
     * @param msg 提示文本内容
     */
    public static void tips(Context context, CharSequence msg) {
        // Toast.LENGTH_LONG：长时显示（约3.5秒）
        Toast.makeText(context, msg, Toast.LENGTH_LONG).show();
    }

    /**
     * 显示长时 Toast 提示（资源ID版）
     * @param context 上下文对象
     * @param resId 字符串资源ID（如 R.string.error_msg）
     */
    public static void tips(Context context, int resId) {
        Toast.makeText(context, resId, Toast.LENGTH_LONG).show();
    }

    /**
     * 显示无标题的 AlertDialog 选择弹窗
     * @param activity 上下文（需传 Activity，不能传 Application）
     * @param items 弹窗选项列表（如 ["录音", "播放", "取消"]）
     * @param listener 选项点击监听器（处理用户选择逻辑）
     */
    public static void alert(Activity activity, CharSequence[] items, DialogInterface.OnClickListener listener) {
        // 创建 AlertDialog 构建器
        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        // 设置弹窗选项列表和点击监听器
        builder.setItems(items, listener);
        // 创建 Dialog 实例
        Dialog dialog = builder.create();
        // 隐藏弹窗标题栏
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        // 显示弹窗
        dialog.show();
    }
}
