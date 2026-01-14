package com.duda.type;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.Locale;

public final class Time extends Date {
    /**
     * 无参构造：创建当前时间的 Time 对象
     */
    public Time() {
        super();
    }

    /**
     * 带参构造：根据毫秒级时间戳创建 Time 对象
     * @param mills 毫秒级时间戳
     */
    public Time(long mills) {
        super(mills);
    }

    /**
     * 将 Date 对象转换为秒级时间戳
     * @param date Date 对象
     * @return 秒级时间戳（float 类型，保留小数）
     */
    public static float getTimestamp(Date date) {
        return date.getTime() / 1000.0f;
    }

    //
    //  工厂方法
    //

    /**
     * 将任意对象解析为 Time 对象
     * @param time 待解析的对象（时间戳、字符串、Date 等）
     * @return 解析后的 Time 对象，失败则返回 null
     */
    public static Time parseTime(Object time) {
        if (time == null) {
            return null;
        } else if (time instanceof Time) {
            // 已是 Time 类型，直接强转
            return (Time) time;
        }
        // 先通过 Converter 转换为 Date，再转为 Time
        Date date = Converter.getDateTime(time, null);
        //assert date != null : "should not happen";
        return new Time(date.getTime());
    }

    /**
     * 获取当前时间的 Date 对象
     * @return 当前时间
     */
    public static Date now() {
        return new Date();
    }

    /**
     * 模糊比较两个时间的先后关系
     * 允许 60 秒误差，用于解决时间同步导致的微小偏差问题
     *
     * @param time1 时间1
     * @param time2 时间2
     * @return -1: time1 早于 time2 超过60秒; 1: time1 晚于 time2 超过60秒; 0: 误差内
     */
    public static int fuzzyCompare(Date time1, Date time2) {
        long t1 = time1.getTime();
        long t2 = time2.getTime();
        // 超过 60 秒才算真正的先后
        if (t1 < (t2 - 60 * 1000)) {
            return -1;
        }
        if (t1 > (t2 + 60 * 1000)) {
            return 1;
        }
        return 0;
    }

    /**
     * 生成可读的时间字符串（根据时间远近自动切换格式）
     * 规则：
     *  - 今天：上午/下午 HH:mm
     *  - 72小时内：星期几 HH:mm
     *  - 今年内：MM-dd HH:mm
     *  - 往年：yyyy-MM-dd HH:mm
     *
     * @param date 待格式化的时间
     * @return 可读的时间字符串
     */
    public static String getTimeString(Date date) {
        Calendar calendar = Calendar.getInstance();
        calendar.setTime(now());
        // 计算今天 00:00:00 的时间戳
        calendar.set(Calendar.HOUR_OF_DAY, 0);
        calendar.set(Calendar.MINUTE, 0);
        calendar.set(Calendar.SECOND, 0);
        long midnight = calendar.getTimeInMillis();

        long timestamp = date.getTime();
        if (timestamp >= midnight) {
            // 今天：a HH:mm（a 代表上午/下午）
            return getTimeString(date, "a HH:mm");
        } else if (timestamp >= (midnight - 72 * 3600 * 1000)) {
            // 72小时内：EEEE HH:mm（EEEE 代表星期几）
            return getTimeString(date, "EEEE HH:mm");
        }
        // 计算今年 01-01 00:00:00 的时间戳
        calendar.set(Calendar.MONTH, 0);
        calendar.set(Calendar.DAY_OF_MONTH, 0);
        long begin = calendar.getTimeInMillis();
        if (timestamp >= begin) {
            // 今年内：MM-dd HH:mm
            return getTimeString(date, "MM-dd HH:mm");
        } else {
            // 往年：yyyy-MM-dd HH:mm
            return getTimeString(date, "yyyy-MM-dd HH:mm");
        }
    }

    /**
     * 根据指定格式生成时间字符串
     * @param date 待格式化的时间
     * @param pattern 时间格式（如 yyyy-MM-dd HH:mm:ss）
     * @return 格式化后的时间字符串
     */
    public static String getTimeString(Date date, String pattern) {
        SimpleDateFormat formatter = new SimpleDateFormat(pattern, Locale.CHINA);
        return formatter.format(date);
    }

    /**
     * 根据毫秒级时间戳生成完整时间字符串（yyyy-MM-dd HH:mm:ss）
     * @param date 毫秒级时间戳
     * @return 完整格式的时间字符串
     */
    public static String getFullTimeString(long date) {
        return getTimeString(new Date(date), "yyyy-MM-dd HH:mm:ss");
    }

    /**
     * 生成完整时间字符串（yyyy-MM-dd HH:mm:ss）
     * @param date Date 对象
     * @return 完整格式的时间字符串
     */
    public static String getFullTimeString(Date date) {
        return getTimeString(date, "yyyy-MM-dd HH:mm:ss");
    }
}
