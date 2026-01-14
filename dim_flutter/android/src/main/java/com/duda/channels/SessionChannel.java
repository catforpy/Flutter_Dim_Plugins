package com.duda.channels;

import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;

import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodCodec;

/**
 * 会话功能的 Flutter 方法通道
 * 负责将原生侧的会话消息（内容/命令）回调给 Flutter
 */
public class SessionChannel extends MethodChannel {

    /**
     * 构造方法：初始化会话方法通道
     * @param messenger Flutter 与原生通信的二进制信使
     * @param name 通道名称（对应 ChannelNames.SESSION）
     * @param codec 方法编解码器
     */
    public SessionChannel(@NonNull BinaryMessenger messenger, @NonNull String name, @NonNull MethodCodec codec) {
        super(messenger, name, codec);
    }

    /**
     * 发送命令消息给 Flutter
     * @param command 命令消息内容（Map 格式）
     * @param receiver 消息接收者标识
     */
    public void sendCommand(Map<String, Object> command, String receiver) {
        // 封装传递给 Flutter 的参数
        Map<String, Object> params = new HashMap<>();
        params.put("content", command); // 命令内容
        params.put("receiver", receiver); // 接收者
        // 切换到主线程调用 Flutter 方法
        new Handler(Looper.getMainLooper()).post(() ->
                invokeMethod(ChannelMethods.SEND_COMMAND, params));
    }

    /**
     * 发送内容消息给 Flutter
     * @param content 普通内容消息（Map 格式）
     * @param receiver 消息接收者标识
     */
    public void sendContent(Map<String, Object> content, String receiver) {
        // 封装传递给 Flutter 的参数
        Map<String, Object> params = new HashMap<>();
        params.put("content", content); // 消息内容
        params.put("receiver", receiver); // 接收者
        // 切换到主线程调用 Flutter 方法
        new Handler(Looper.getMainLooper()).post(() ->
                invokeMethod(ChannelMethods.SEND_CONTENT, params));
    }

}
