package com.duda.ui.media;

import android.app.Service;
import android.content.Intent;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.media.MediaRecorder;
import android.net.Uri;
import android.os.IBinder;

import java.io.IOException;


import com.duda.channels.ChannelManager;
import com.duda.ui.Alert;
import com.duda.utils.Log;

/**
 * 音频核心服务类
 * 继承自 Android Service，在后台执行音频录制和播放操作，
 * 封装 Android 原生 MediaRecorder/MediaPlayer，处理音频硬件交互
 */
public class MediaService extends Service {
    /**
     * Intent 动作常量：录音
     */
    public static final String RECORD = "record";
    /**
     * Intent 动作常量：播放
     */
    public static final String PLAY = "play";

    /**
     * Android 原生音频播放类
     */
    private MediaPlayer player = null;
    /**
     * Android 原生音频录制类
     */
    private MediaRecorder recorder = null;

    /**
     * 录音临时文件路径
     */
    private String tempFile = null;
    /**
     * 录音开始时间戳（毫秒级）
     */
    private long recordStart = 0;
    /**
     * 录音结束时间戳（毫秒级）
     */
    private long recordStop = 0;

    /**
     * 构造方法
     */
    public MediaService() {
        super();
    }

    /**
     * Service 绑定方法
     * 前端绑定服务时调用，返回自定义 Binder 对象建立通信
     * @param intent 启动服务的 Intent
     * @return 自定义 Binder 对象
     */
    @Override
    public IBinder onBind(Intent intent) {
        // Return the communication channel to the service.
        return new Binder();
    }

    /**
     * Service 启动方法
     * 前端启动服务时调用，根据 Intent 动作分发到录音/播放逻辑
     * @param intent 启动服务的 Intent（包含动作和音频 Uri）
     * @param flags 启动标记
     * @param startId 启动 ID
     * @return 服务启动模式（START_STICKY：服务被杀死后自动重启）
     */
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String action = intent.getAction();
        Uri uri = intent.getData();
        if (action != null && uri != null) {
            if (action.equals(RECORD)) {
                // 动作：录音，启动录音逻辑
                startRecording(uri.getPath());
            } else if (action.equals(PLAY)) {
                // 动作：播放，启动播放逻辑
                startPlaying(uri);
            }
        }
        return START_STICKY;
    }

    /**
     * Service 销毁方法
     * 服务停止时调用，释放所有音频资源
     */
    @Override
    public void onDestroy() {
        // 停止所有音频操作
        stopAll();
        super.onDestroy();
    }

    /**
     * 停止所有音频操作（录音+播放）
     */
    private void stopAll() {
        stopRecording();
        stopPlaying();
    }

    //
    //  录音相关逻辑
    //

    /**
     * 启动录音
     * @param outputFile 录音文件输出路径
     */
    private void startRecording(String outputFile) {
        // 先停止所有音频操作，避免冲突
        stopAll();

        // 初始化 MediaRecorder
        recorder = new MediaRecorder();
        // 设置音频源：麦克风
        recorder.setAudioSource(MediaRecorder.AudioSource.MIC);
        // 设置输出格式：MPEG_4
        recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
        // 设置音频编码：AAC
        recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
        // 设置声道数：单声道
        recorder.setAudioChannels(1);
        // 设置采样率：44100Hz（兼容所有 Android 设备）
        recorder.setAudioSamplingRate(44100);
        // 设置编码比特率：96000
        recorder.setAudioEncodingBitRate(96000);

        // 设置输出文件路径
        recorder.setOutputFile(outputFile);
        try {
            // 准备录音
            recorder.prepare();
            // 开始录音
            recorder.start();
        } catch (IOException e) {
            e.printStackTrace();
        }

        // 记录录音文件路径和开始时间
        tempFile = outputFile;
        recordStart = recordStop = System.currentTimeMillis();
    }

    /**
     * 停止录音
     * @return 录音文件路径
     */
    private String stopRecording() {
        if (recorder != null) {
            try {
                // 停止录音
                recorder.stop();
            } catch (Exception e) {
                // 录音异常，弹出提示
                Alert.tips(getApplicationContext(), e.toString());
            }
            // 重置 MediaRecorder
            recorder.reset();
            // 释放资源
            recorder.release();
            recorder = null;
            // 记录录音结束时间
            recordStop = System.currentTimeMillis();
        }
        return tempFile;
    }

    /**
     * 获取录音时长
     * @return 录音时长（毫秒级）
     */
    private int getRecordedDuration() {
        // 时长 = 结束时间 - 开始时间
        return (int) (recordStop - recordStart);
    }

    //
    //  播放相关逻辑
    //

    /**
     * 播放完成回调方法
     * 通知 AudioChannel 播放结束
     * @param mp MediaPlayer 对象
     */
    private void onCompleted(MediaPlayer mp) {
        String path = playingUri == null ? null : playingUri.getPath();
        if (path != null) {
            // 清空播放 Uri
            playingUri = null;
            // 通知通道管理器播放完成
            ChannelManager man = ChannelManager.getInstance();
            man.audioChannel.onPlayFinished(path);
        }
    }

    /**
     * 当前播放音频的 Uri
     */
    Uri playingUri;

    /**
     * 启动音频播放
     * @param inputUri 待播放音频的 Uri
     */
    private void startPlaying(Uri inputUri) {
        // 先停止所有音频操作，避免冲突
        stopAll();
        // 清空上一次播放的回调状态
        onCompleted(null);
        assert inputUri != null : "inputUri empty";
        Log.info("start playing: " + inputUri);
        // 记录当前播放的 Uri
        playingUri = inputUri;

        // 初始化 MediaPlayer
        player = new MediaPlayer();
        // 设置音频流类型：音乐流
        player.setAudioStreamType(AudioManager.STREAM_MUSIC);
        // 设置是否循环播放：否
        player.setLooping(false);
        // 设置准备完成监听器：准备好后立即播放
        player.setOnPreparedListener(mp -> player.start());
        // 设置播放完成监听器：播放结束后回调
        player.setOnCompletionListener(this::onCompleted);
        try {
            // 设置播放数据源（通过 Uri）
            player.setDataSource(getApplicationContext(), inputUri);
        } catch (IOException e) {
            e.printStackTrace();
        }
        // 异步准备播放（避免主线程阻塞）
        player.prepareAsync();
    }

    /**
     * 停止音频播放
     */
    private void stopPlaying() {
        if (player != null) {
            // 停止播放
            player.stop();
            // 重置 MediaPlayer
            player.reset();
            // 释放资源
            player.release();
            player = null;
        }
    }

    /**
     * 获取当前音频的总时长
     * @return 音频时长（毫秒级），未初始化则返回 -1
     */
    private int getPlayingDuration() {
        if (player == null) {
            return -1;
        }
        // 获取 MediaPlayer 中的音频时长
        return player.getDuration();
    }

    //
    //  自定义 Binder 类：前端与 Service 通信的通道
    //

    /**
     * 自定义 Binder 内部类
     * 暴露录音/播放相关方法，供前端绑定服务后调用
     */
    class Binder extends android.os.Binder {

        /**
         * 启动录音
         * @param outputFile 录音文件输出路径
         */
        void startRecord(String outputFile) {
            startRecording(outputFile);
        }

        /**
         * 停止录音
         * @return 录音文件路径
         */
        String stopRecord() {
            return stopRecording();
        }

        /**
         * 获取录音时长
         * @return 录音时长（毫秒级）
         */
        int getRecordDuration() {
            return getRecordedDuration();
        }

        /**
         * 启动播放
         * @param inputUri 待播放音频的 Uri
         */
        void startPlay(Uri inputUri) {
            startPlaying(inputUri);
        }

        /**
         * 停止播放
         */
        void stopPlay() {
            stopPlaying();
        }

        /**
         * 获取播放音频的总时长
         *
         * @return 音频时长（毫秒级）
         */
        int getPlayDuration() {
            return getPlayingDuration();
        }
    }
}
