package com.duda.channels;

import android.app.Activity;
import android.content.ContextWrapper;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;

import java.io.File;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

import com.duda.filesys.ExternalStorage;
import com.duda.filesys.LocalCache;
import com.duda.filesys.Paths;
import com.duda.ui.media.AudioPlayer;
import com.duda.ui.media.AudioRecorder;
import com.duda.utils.Log;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodCodec;

/**
 * 音频功能的 Flutter 方法通道
 * 负责处理 Flutter 侧发起的音频录制、播放相关方法调用，
 * 并将原生侧的音频状态回调给 Flutter
 */
public class AudioChannel extends MethodChannel {
    // 音频播放器实例
    private AudioPlayer audioPlayer = null;
    //音频录制器实例
    private AudioRecorder audioRecorder = null;

    /**
     * 构造方法：初始化音频方法通道
     * @param messenger Flutter 与原生通信的二进制信使
     * @param name 通道名称（对应 ChannelNames.AUDIO）
     * @param codec 方法编解码器
     */
    public AudioChannel(@NonNull BinaryMessenger messenger, @NonNull String name, @NonNull MethodCodec codec){
        super(messenger,name,codec);
        // 设置方法调用处理器，处理Flutter侧的方法调用
        setMethodCallHandler(new AudioChannelHandler());
    }

    /**
     * 初始化音频播放器
     * @param context 上下文包装类，用于创建音频播放器
     */
    public void initAudioPlayer(ContextWrapper context){
        audioPlayer = new AudioPlayer(context);
    }

    /**
     * 初始化音频录制器
     * @param activity 活动实例，用于创建音频录制器（需权限等上下文）
     */
    public void initAudioRecorder(Activity activity) {
        audioRecorder = new AudioRecorder(activity);
    }

    /**
     * 音频录制完成回调方法
     * 将录制好的音频数据和时长传递给 Flutter 侧
     * @param mp4Path 录制完成的音频文件路径
     * @param seconds 录制时长（秒）
     */
    public void onRecordFinished(String mp4Path, float seconds) {
        byte[] data;
        try {
            // 从外部存储加载音频文件的二进制数据
            data = ExternalStorage.loadBinary(mp4Path);
        } catch (IOException e) {
            e.printStackTrace();
            return;
        }
        // 封装传递给 Flutter 的参数
        Map<String, Object> params = new HashMap<>();
        params.put("data", data); // 音频二进制数据
        params.put("current", seconds); // 录制时长
        // 切换到主线程调用 Flutter 方法（Flutter 通信需主线程）
        new Handler(Looper.getMainLooper()).post(() ->
                invokeMethod(ChannelMethods.ON_RECORD_FINISHED, params));
    }

    /**
     * 音频播放完成回调方法
     * 通知 Flutter 侧指定路径的音频已播放完成
     * @param mp4Path 播放完成的音频文件路径
     */
    public void onPlayFinished(String mp4Path) {
        Map<String, Object> params = new HashMap<>();
        params.put("path", mp4Path); // 音频文件路径
        // 切换到主线程调用 Flutter 方法
        new Handler(Looper.getMainLooper()).post(() ->
                invokeMethod(ChannelMethods.ON_PLAY_FINISHED, params));
    }

    /**
     * 音频通道的方法调用处理器
     * 处理 Flutter 侧发起的 startRecord/stopRecord/startPlay/stopPlay 方法调用
     */
    static class AudioChannelHandler implements MethodChannel.MethodCallHandler {

        /**
         * 处理 Flutter 侧的方法调用
         * @param call 方法调用对象（包含方法名和参数）
         * @param result 方法调用结果回调（用于向 Flutter 返回结果）
         */
        @Override
        public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
            String method = call.method;
            // 根据方法名分发处理逻辑
            switch (method) {
                case ChannelMethods.START_RECORD: {
                    startRecord();
                    break;
                }
                case ChannelMethods.STOP_RECORD: {
                    stopRecord();
                    break;
                }
                case ChannelMethods.START_PLAY: {
                    // 获取 Flutter 传递的音频路径参数
                    String path = call.argument("path");
                    startPlay(path);
                    break;
                }
                case ChannelMethods.STOP_PLAY: {
                    // 获取 Flutter 传递的音频路径参数
                    String path = call.argument("path");
                    stopPlay(path);
                    break;
                }
            }
        }

        /**
         * 开始音频录制
         * 创建临时音频文件路径，启动录制器
         */
        private void startRecord() {
            // 获取本地缓存的临时目录
            String dir = LocalCache.getInstance().getTemporaryDirectory();
            // 拼接临时音频文件路径（voice.mp4）
            String path = Paths.append(dir, "voice.mp4");
            // 获取通道管理器实例，调用录制器开始录制
            ChannelManager man = ChannelManager.getInstance();
            man.audioChannel.audioRecorder.startRecord(path);
        }

        /**
         * 停止音频录制
         * 停止录制后，读取录制文件并回调给 Flutter
         */
        private void stopRecord() {
            ChannelManager man = ChannelManager.getInstance();
            AudioRecorder recorder = man.audioChannel.audioRecorder;
            // 停止录制并获取录制文件路径
            String path = recorder.stopRecord();
            // 检查文件是否存在
            if (path == null || !Paths.exists(path)) {
                Log.error("voice file not found: " + path);
                return;
            }
            // 通知 Flutter 录制完成
            man.audioChannel.onRecordFinished(path, recorder.getDuration());
        }

        /**
         * 开始播放音频
         * @param path 音频文件路径
         */
        private void startPlay(String path) {
            Log.info("playing " + path);
            // 将文件路径转换为 Uri
            Uri url = Uri.fromFile(new File(path));
            ChannelManager man = ChannelManager.getInstance();
            // 调用播放器开始播放
            man.audioChannel.audioPlayer.startPlay(url);
        }

        /**
         * 停止播放音频
         * @param path 音频文件路径（日志用，实际停止所有播放）
         */
        private void stopPlay(String path) {
            Log.info("stop playing " + path);
            ChannelManager man = ChannelManager.getInstance();
            // 调用播放器停止播放
            man.audioChannel.audioPlayer.stopPlay();
        }
    }
}
