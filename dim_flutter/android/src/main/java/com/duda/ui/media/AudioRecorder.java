package com.duda.ui.media;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.net.Uri;
import android.os.IBinder;

/**
 * 音频录音功能前端封装类
 * 业务层调用入口，负责绑定 MediaService 并调用录音相关方法，
 * 提供启动录音、停止录音、获取录音时长等功能
 */
public class AudioRecorder {
    /**
     * 上下文对象（Activity）
     */
    private final Activity activity;

    /**
     * MediaService 的 Binder 对象，用于和后台服务通信
     */
    private MediaService.Binder binder = null;

    /**
     * 服务连接对象，监听 Service 绑定状态
     */
    private final Connection connection = new Connection();

    /**
     * 录音时长（毫秒级）
     */
    private int duration = 0;

    /**
     * 构造方法
     * @param activity 上下文对象（Activity）
     */
    public AudioRecorder(Activity activity) {
        super();
        this.activity = activity;
    }

    /**
     * 启动音频录音
     * @param outputFile 录音文件的输出路径
     */
    public void startRecord(String outputFile) {
        // 创建启动 MediaService 的 Intent
        Intent intent = new Intent(activity, MediaService.class);
        // 设置动作：录音
        intent.setAction(MediaService.RECORD);
        // 设置录音文件的 Uri（路径转 Uri）
        intent.setData(Uri.parse(outputFile));
        // 启动后台服务
        activity.startService(intent);
        // 绑定服务，建立通信通道
        activity.bindService(intent, connection, Context.BIND_AUTO_CREATE);
    }

    /**
     * 停止音频录音
     * @return 录音文件的路径，未绑定服务则返回 null
     */
    public String stopRecord() {
        String filePath = null;
        if (binder != null) {
            // 调用 Service 的停止录音方法，获取录音文件路径
            filePath = binder.stopRecord();
            // 获取录音时长（毫秒级）
            duration = binder.getRecordDuration();
            // 解绑服务
            activity.unbindService(connection);
        }
        // 停止后台服务
        activity.stopService(new Intent(activity, MediaService.class));
        return filePath;
    }

    /**
     * 获取录音时长
     * @return 录音时长（秒级）
     */
    public float getDuration() {
        // 毫秒级转秒级
        return duration / 1000.0f;
    }

    /**
     * 服务连接内部类
     * 监听 Service 绑定状态，获取 Binder 对象
     */
    private class Connection implements ServiceConnection {

        /**
         * Service 绑定成功时调用
         * @param name 服务组件名称
         * @param service 服务的 Binder 对象
         */
        @Override
        public void onServiceConnected(ComponentName name, IBinder service) {
            // 获取 MediaService 的 Binder 对象
            binder = (MediaService.Binder) service;
        }

        /**
         * Service 解绑时调用
         * @param name 服务组件名称
         */
        @Override
        public void onServiceDisconnected(ComponentName name) {
            // 清空 Binder 对象
            binder = null;
        }
    }
}
