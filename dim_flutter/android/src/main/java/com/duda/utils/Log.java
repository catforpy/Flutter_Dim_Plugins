package com.duda.utils;

import java.util.Arrays;
import java.util.Date;

import com.duda.type.Time;

/**
 * 自定义日志工具类
 * 封装 System.out.println，增强日志输出格式（时间戳、代码位置），
 * 支持日志级别控制，适配开发/测试/生产环境的不同日志输出需求
 */
public final class Log {
    /**
     * 日志级别标记：调试（最低级别，开发用）
     */
    public static final int DEBUG_FLAG = 0x01;
    /**
     * 日志级别标记：信息（普通业务日志）
     */
    public static final int INFO_FLAG = 0x02;
    /**
     * 日志级别标记：警告（非致命问题）
     */
    public static final int WARNING_FLAG = 0x04;
    /**
     * 日志级别标记：错误（致命问题）
     */
    public static final int ERROR_FLAG = 0x08;

    /**
     * 调试模式：输出所有级别日志（DEBUG+INFO+WARNING+ERROR）
     */
    public static final int DEBUG = DEBUG_FLAG | INFO_FLAG | WARNING_FLAG | ERROR_FLAG;
    /**
     * 开发模式：输出 INFO+WARNING+ERROR 日志
     */
    public static final int DEVELOP = INFO_FLAG | WARNING_FLAG | ERROR_FLAG;
    /**
     * 发布模式：仅输出 WARNING+ERROR 日志（生产环境用）
     */
    public static final int RELEASE = WARNING_FLAG | ERROR_FLAG;

    /**
     * 当前日志级别（默认发布模式）
     * 可在应用初始化时修改：如 Log.LEVEL = Log.DEBUG;
     */
    public static int LEVEL = RELEASE;

    /**
     * 获取格式化的当前时间字符串（yyyy-MM-dd HH:mm:ss）
     * @return 完整时间戳字符串
     */
    public static String getTime() {
        Date now = Time.now();
        return Time.getFullTimeString(now);
    }

    /**
     * 获取日志调用的代码位置（文件名:行号）
     * @return 格式化的代码位置字符串（如 MainActivity:25）
     */
    private static String getLocation() {
        String filename = null;
        int line = -1;
        // 获取当前线程的堆栈轨迹
        StackTraceElement[] traces = Thread.currentThread().getStackTrace();
        boolean flag = false;
        for (StackTraceElement element : traces) {
            filename = element.getFileName();
            // 跳过 Log 类自身的堆栈信息，找到真正的调用位置
            if (filename != null && filename.endsWith("Log.java")) {
                flag = true;
            } else if (flag) {
                // 获取调用行号
                line = element.getLineNumber();
                break;
            }
        }
        // 断言防止获取失败（开发环境提示，生产环境忽略）
        assert filename != null && line >= 0 : "traces error: " + Arrays.toString(traces);
        // 去掉文件名后缀（如 Log.java -> Log）
        filename = filename.split("\\.")[0];
        // 拼接成 "文件名:行号" 格式
        return filename + ":" + line;
    }

    /**
     * 输出 DEBUG 级别日志
     * @param msg 日志内容
     */
    public static void debug(String msg) {
        // 检查当前级别是否允许输出 DEBUG 日志
        if ((LEVEL & DEBUG_FLAG) == 0) {
            return;
        }
        String time = getTime();
        String loc = getLocation();
        // 格式化输出：[时间] 级别 | 代码位置 > 日志内容
        System.out.println("[" + time + "]  DEBUG  | " + loc + " >\t" + msg);
    }

    /**
     * 输出 INFO 级别日志
     * @param msg 日志内容
     */
    public static void info(String msg) {
        if ((LEVEL & INFO_FLAG) == 0) {
            return;
        }
        String time = getTime();
        String loc = getLocation();
        System.out.println("[" + time + "]         | " + loc + " >\t" + msg);
    }

    /**
     * 输出 WARNING 级别日志
     * @param msg 日志内容
     */
    public static void warning(String msg) {
        if ((LEVEL & WARNING_FLAG) == 0) {
            return;
        }
        String time = getTime();
        String loc = getLocation();
        System.out.println("[" + time + "] WARNING | " + loc + " >\t" + msg);
    }

    /**
     * 输出 ERROR 级别日志
     * @param msg 日志内容
     */
    public static void error(String msg) {
        if ((LEVEL & ERROR_FLAG) == 0) {
            return;
        }
        String time = getTime();
        String loc = getLocation();
        System.out.println("[" + time + "]  ERROR  | " + loc + " >\t" + msg);
    }
}
