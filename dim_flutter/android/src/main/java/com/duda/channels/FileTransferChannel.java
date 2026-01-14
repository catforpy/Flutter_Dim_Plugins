package com.duda.channels;

import androidx.annotation.NonNull;

import com.duda.filesys.LocalCache;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodCodec;

/**
 * 文件传输功能的 Flutter 方法通道
 * 负责处理 Flutter 侧发起的获取缓存目录、临时目录等文件系统相关方法调用
 */
public class FileTransferChannel extends MethodChannel {

    /**
     * 构造方法：初始化文件传输方法通道
     * @param messenger Flutter 与原生通信的二进制信使
     * @param name 通道名称（对应 ChannelNames.FILE_TRANSFER）
     * @param codec 方法编解码器
     */
    public FileTransferChannel(@NonNull BinaryMessenger messenger, @NonNull String name, @NonNull MethodCodec codec) {
        super(messenger, name, codec);
        // 设置方法调用处理器，处理 Flutter 侧的文件相关方法调用
        setMethodCallHandler(new FileChannelHandler());
    }

    /**
     * 文件通道的方法调用处理器
     * 处理 Flutter 侧发起的 getCachesDirectory/getTemporaryDirectory 方法调用
     */
    static class FileChannelHandler implements MethodChannel.MethodCallHandler {

        /**
         * 处理 Flutter 侧的方法调用
         * @param call 方法调用对象（包含方法名和参数）
         * @param result 方法调用结果回调（用于向 Flutter 返回目录路径）
         */
        @Override
        public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
            switch (call.method) {
                case ChannelMethods.GET_CACHES_DIRECTORY: {
                    // 获取本地缓存实例
                    LocalCache localCache = LocalCache.getInstance();
                    // 获取缓存目录路径
                    String dir = localCache.getCachesDirectory();
                    // 向 Flutter 返回成功结果（缓存目录路径）
                    result.success(dir);
                    break;
                }
                case ChannelMethods.GET_TEMPORARY_DIRECTORY: {
                    // 获取本地缓存实例
                    LocalCache localCache = LocalCache.getInstance();
                    // 获取临时目录路径
                    String dir = localCache.getTemporaryDirectory();
                    // 向 Flutter 返回成功结果（临时目录路径）
                    result.success(dir);
                    break;
                }
                default:
                    // 方法未实现，通知 Flutter
                    result.notImplemented();
                    break;
            }
        }

    }
}
