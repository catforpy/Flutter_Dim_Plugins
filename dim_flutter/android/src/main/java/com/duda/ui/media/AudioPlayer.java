package com.duda.ui.media;


import android.content.ComponentName;
import android.content.Context;
import android.content.ContextWrapper;
import android.content.Intent;
import android.content.ServiceConnection;
import android.net.Uri;
import android.os.IBinder;

/**
 * 音频播放功能前端封装类
 * 业务层调用入口，负责绑定 MediaService 并调用播放相关方法，
 * 提供启动播放、停止播放、获取播放时长等功能
 */
public class AudioPlayer {

    /**
     * 上下文对象（接收 ContextWrapper 以适配更多场景）
     */
    private final ContextWrapper activity;

    /**
     * MediaService 的 Binder 对象，用于和后台服务通信
     */
    private MediaService.Binder binder = null;

    /**
     * 服务连接对象，监听 Service 绑定状态
     */
    private final Connection connection = new Connection();

    /**
     * 构造方法
     * @param activity 上下文对象（ContextWrapper 比 Activity 更通用）
     */
    public AudioPlayer(ContextWrapper activity) {
        super();
        this.activity = activity;
    }

    /**
     * 启动音频播放
     * @param inputUri 待播放音频文件的 Uri
     */
    public void startPlay(Uri inputUri) {
        // 创建启动 MediaService 的 Intent
        Intent intent = new Intent(activity, MediaService.class);
        // 设置动作：播放
        intent.setAction(MediaService.PLAY);
        // 设置播放文件的 Uri
        intent.setData(inputUri);
        // 启动后台服务
        activity.startService(intent);
        // 绑定服务，建立通信通道
        activity.bindService(intent, connection, Context.BIND_AUTO_CREATE);
    }

    /**
     * 停止音频播放
     */
    public void stopPlay() {
        if (binder != null) {
            // 调用 Service 的停止播放方法
            binder.stopPlay();
            // 解绑服务
            activity.unbindService(connection);
        }
        // 停止后台服务
        activity.stopService(new Intent(activity, MediaService.class));
    }

    /**
     * 获取当前音频的总时长
     * @return 音频时长（秒级），未绑定服务则返回 -1
     */
    public float getDuration() {
        if (binder == null) {
            return -1;
        }
        // 从 Service 获取毫秒级时长，转为秒级
        return binder.getPlayDuration() / 1000.0f;
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
