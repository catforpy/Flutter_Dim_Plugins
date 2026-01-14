package com.duda.type;

import java.util.Arrays;
import java.util.Date;
import java.util.List;

/**
 * 通用类型安全转换工具接口
 * 提供静态方法，实现任意 Object 类型到基础类型（字符串、布尔、数字、日期）的安全转换，
 * 支持默认值兜底，避免空指针或格式错误导致的崩溃
 */
public interface Converter {
    /**
     * 将任意对象转换为字符串
     * @param value 待转换的对象
     * @param defaultValue 转换失败时的默认值
     * @return 转换后的字符串，失败则返回默认值
     */
    static String getString(Object value, String defaultValue) {
        if (value == null) {
            // 对象为空，返回默认值
            return defaultValue;
        } else if (value instanceof String) {
            // 已是字符串类型，直接强转
            return (String) value;
        } else {
            // 其他类型调用 toString() 方法转换
            //assert false : "not a string value: " + value;
            return value.toString();
        }
    }

    /**
     * 将任意对象转换为布尔值
     * 支持多种格式：布尔类型、数字(1/0)、字符串(true/false/yes/no等)
     *
     * @param value 待转换的对象
     * @param defaultValue 转换失败时的默认值
     * @return 转换后的布尔值，失败则返回默认值
     */
    static boolean getBoolean(Object value, boolean defaultValue) {
        if (value == null) {
            // 对象为空，返回默认值
            return defaultValue;
        } else if (value instanceof Boolean) {
            // 已是布尔类型，直接强转
            return (Boolean) value;
        } else if (value instanceof Number) {  // Byte, Short, Integer, Long, Float, Double
            // 数字类型：1->true, 0->false
            int num = ((Number) value).intValue();
            assert num == 1 || num == 0 : "boolean value error: " + value;
            return num != 0;
        }
        // 其他类型转为字符串处理
        String lower;
        if (value instanceof String) {
            lower = ((String) value);
        } else {
            lower = value.toString();
        }
        if (lower.isEmpty()) {
            // 空字符串视为 false
            return false;
        } else {
            // 统一转为小写，避免大小写敏感
            lower = lower.toLowerCase();
        }
        // 匹配 false 关键词列表
        if (FALSE_LIST.contains(lower)) {
            return false;
        }
        // 匹配 true 关键词列表，否则断言报错
        assert TRUE_LIST.contains(lower) : "boolean value error: " + value;
        return true;
    }

    /**
     * 判定为 false 的字符串列表
     * 支持 0/false/no/off/null/undefined 等常见格式
     */
    List<String> FALSE_LIST = Arrays.asList(
            "0", "false", "no", "off", "null", "undefined"
    );

    /**
     * 判定为 true 的字符串列表
     * 支持 1/true/yes/on 等常见格式
     */
    List<String> TRUE_LIST = Arrays.asList(
            "1", "true", "yes", "on"
    );

    /**
     * 将任意对象转换为 byte 类型
     * @param value 待转换的对象
     * @param defaultValue 转换失败时的默认值
     * @return 转换后的 byte 值，失败则返回默认值
     */
    static byte getByte(Object value, byte defaultValue) {
        if (value == null) {
            return defaultValue;
        } else if (value instanceof Byte) {
            return (byte) value;
        } else if (value instanceof Number) {  // Short, Integer, Long, Float, Double
            // 其他数字类型转为 byte
            return ((Number) value).byteValue();
        } else if (value instanceof Boolean) {
            // 布尔类型：true->1, false->0
            return (byte) ((Boolean) value ? 1 : 0);
        }
        // 其他类型转为字符串后解析
        String str = value instanceof String ? (String) value : value.toString();
        return Byte.parseByte(str);
    }

    /**
     * 将任意对象转换为 short 类型
     * @param value 待转换的对象
     * @param defaultValue 转换失败时的默认值
     * @return 转换后的 short 值，失败则返回默认值
     */
    static short getShort(Object value, short defaultValue) {
        if (value == null) {
            return defaultValue;
        } else if (value instanceof Short) {
            // exactly
            return (Short) value;
        } else if (value instanceof Number) {  // Byte, Integer, Long, Float, Double
            // 其他数字类型转为 short
            return ((Number) value).shortValue();
        } else if (value instanceof Boolean) {
            // 布尔类型：true->1, false->0
            return (short) ((Boolean) value ? 1 : 0);
        }
        // 其他类型转为字符串后解析
        String str = value instanceof String ? (String) value : value.toString();
        return Short.parseShort(str);
    }

    /**
     * 将任意对象转换为 int 类型
     * @param value 待转换的对象
     * @param defaultValue 转换失败时的默认值
     * @return 转换后的 int 值，失败则返回默认值
     */
    static int getInt(Object value, int defaultValue) {
        if (value == null) {
            return defaultValue;
        } else if (value instanceof Integer) {
            // exactly
            return (Integer) value;
        } else if (value instanceof Number) {  // Byte, Short, Long, Float, Double
            // 其他数字类型转为 int
            return ((Number) value).intValue();
        } else if (value instanceof Boolean) {
            // 布尔类型：true->1, false->0
            return (Boolean) value ? 1 : 0;
        }
        // 其他类型转为字符串后解析
        String str = value instanceof String ? (String) value : value.toString();
        return Integer.parseInt(str);
    }

    /**
     * 将任意对象转换为 long 类型
     * @param value 待转换的对象
     * @param defaultValue 转换失败时的默认值
     * @return 转换后的 long 值，失败则返回默认值
     */
    static long getLong(Object value, long defaultValue) {
        if (value == null) {
            return defaultValue;
        } else if (value instanceof Long) {
            // exactly
            return (Long) value;
        } else if (value instanceof Number) {  // Byte, Short, Integer, Float, Double
            // 其他数字类型转为 long
            return ((Number) value).longValue();
        } else if (value instanceof Boolean) {
            // 布尔类型：true->1L, false->0L
            return (Boolean) value ? 1L : 0L;
        }
        // 其他类型转为字符串后解析
        String str = value instanceof String ? (String) value : value.toString();
        return Long.parseLong(str);
    }

    /**
     * 将任意对象转换为 float 类型
     * @param value 待转换的对象
     * @param defaultValue 转换失败时的默认值
     * @return 转换后的 float 值，失败则返回默认值
     */
    static float getFloat(Object value, float defaultValue) {
        if (value == null) {
            return defaultValue;
        } else if (value instanceof Float) {
            // exactly
            return (Float) value;
        } else if (value instanceof Number) {  // Byte, Short, Integer, Long, Double
            // 其他数字类型转为 float
            return ((Number) value).floatValue();
        } else if (value instanceof Boolean) {
            // 布尔类型：true->1.0F, false->0.0F
            return (Boolean) value ? 1.0F : 0.0F;
        }
        // 其他类型转为字符串后解析
        String str = value instanceof String ? (String) value : value.toString();
        return Float.parseFloat(str);
    }

    /**
     * 将任意对象转换为 double 类型
     * @param value 待转换的对象
     * @param defaultValue 转换失败时的默认值
     * @return 转换后的 double 值，失败则返回默认值
     */
    static double getDouble(Object value, double defaultValue) {
        if (value == null) {
            return defaultValue;
        } else if (value instanceof Double) {
            // exactly
            return (Double) value;
        } else if (value instanceof Number) {  // Byte, Short, Integer, Long, Float
            // 其他数字类型转为 double
            return ((Number) value).doubleValue();
        } else if (value instanceof Boolean) {
            // 布尔类型：true->1.0, false->0.0
            return (Boolean) value ? 1.0 : 0.0;
        }
        // 其他类型转为字符串后解析
        String str = value instanceof String ? (String) value : value.toString();
        return Double.parseDouble(str);
    }

    /**
     * 将任意对象转换为 Date 类型
     * 支持时间戳（秒级）、字符串、数字等格式
     *
     * @param value 待转换的对象（通常是秒级时间戳）
     * @param defaultValue 转换失败时的默认值
     * @return 转换后的 Date 对象，失败则返回默认值
     */
    static Date getDateTime(Object value, Date defaultValue) {
        if (value == null) {
            return defaultValue;
        } else if (value instanceof Date) {
            // exactly
            return (Date) value;
        }
        // 其他类型转为 double 秒级时间戳，再转为毫秒级
        double seconds = getDouble(value, 0);
        double millis = seconds * 1000;
        return new Date((long) millis);
    }

}
