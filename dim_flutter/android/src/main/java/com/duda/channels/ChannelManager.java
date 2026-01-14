package com.duda.channels;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.common.StandardMethodCodec;

/**
 * Flutter 方法通道名称常量类
 * 定义所有原生与 Flutter 通信的通道名称
 */
final class ChannelNames {

    // 音频功能通道名称
    static final String AUDIO = "chat.dim/audio";

    // 会话功能通道名称
    static final String SESSION = "chat.dim/session";

    // 文件传输功能通道名称
    static final String FILE_TRANSFER = "chat.dim/ftp";
}

/**
 * Flutter 方法通道方法名常量类
 * 定义各通道下的方法名称（包括 Flutter 调用原生、原生回调 Flutter）
 */
final class ChannelMethods {

    //
    //  音频通道方法名
    //
    // Flutter 调用原生：开始录制音频
    static final String START_RECORD = "startRecord";
    // Flutter 调用原生：停止录制音频
    static final String STOP_RECORD = "stopRecord";
    // Flutter 调用原生：开始播放音频
    static final String START_PLAY = "startPlay";
    // Flutter 调用原生：停止播放音频
    static final String STOP_PLAY = "stopPlay";

    // 原生回调 Flutter：音频录制完成
    static final String ON_RECORD_FINISHED = "onRecordFinished";
    // 原生回调 Flutter：音频播放完成
    static final String ON_PLAY_FINISHED = "onPlayFinished";

    //
    //  会话通道方法名
    //
    // 原生回调 Flutter：发送内容消息
    static final String SEND_CONTENT = "sendContent";
    // 原生回调 Flutter：发送命令消息
    static final String SEND_COMMAND = "sendCommand";

    //
    //  FTP 通道方法名
    //
    // Flutter 调用原生：获取缓存目录
    static final String GET_CACHES_DIRECTORY = "getCachesDirectory";
    // Flutter 调用原生：获取临时目录
    static final String GET_TEMPORARY_DIRECTORY = "getTemporaryDirectory";

}

/**
 * 通道管理器（单例模式）
 * 统一管理所有 Flutter 方法通道的创建和实例持有
 */
public enum ChannelManager {

    // 单例实例
    INSTANCE;

    /**
     * 获取通道管理器单例
     * @return 单例实例
     */
    public static ChannelManager getInstance() {
        return INSTANCE;
    }

    /**
     * 私有构造方法（单例模式）
     */
    ChannelManager() {

    }

    //
    //  各功能通道实例
    //
    // 音频通道实例
    public AudioChannel audioChannel = null;
    // 会话通道实例
    public SessionChannel sessionChannel = null;
    // 文件传输通道实例
    public FileTransferChannel fileChannel = null;

    /**
     * 自定义消息编解码器
     * 处理 BigDecimal 类型的转换（转为 double 避免序列化问题）
     */
    private static class MessageCodec extends StandardMessageCodec {
        @Override
        protected void writeValue(@NonNull ByteArrayOutputStream stream, @Nullable Object value) {
            if (value instanceof BigDecimal) {
                // 修复 BigDecimal 序列化问题：转为 double 类型
                value = ((BigDecimal) value).doubleValue();
            }
            super.writeValue(stream, value);
        }
    }

    /**
     * 初始化所有 Flutter 方法通道
     * @param messenger Flutter 二进制信使（用于创建通道）
     */
    public void initChannels(BinaryMessenger messenger) {
        // 打印初始化日志（调试用）
        System.out.println("initChannels: audioChannel=" + audioChannel);
        System.out.println("initChannels: sessionChannel=" + sessionChannel);
        System.out.println("initChannels: fileChannel=" + fileChannel);
        // 创建自定义编解码器（处理 BigDecimal）
        StandardMethodCodec codec = new StandardMethodCodec(new MessageCodec());
        // 初始化音频通道（注：原代码注释了空判断，强制重建）
        //if (audioChannel == null) {
        audioChannel = new AudioChannel(messenger, ChannelNames.AUDIO, codec);
        //}
        // 初始化会话通道
        //if (sessionChannel == null) {
        sessionChannel = new SessionChannel(messenger, ChannelNames.SESSION, codec);
        //}
        // 初始化文件传输通道
        //if (fileChannel == null) {
        fileChannel = new FileTransferChannel(messenger, ChannelNames.FILE_TRANSFER, codec);
        //}
    }
}
