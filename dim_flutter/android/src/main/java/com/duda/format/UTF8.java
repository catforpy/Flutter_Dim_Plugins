package com.duda.format;

import java.nio.charset.Charset;

/**
 * UTF-8 编码工具类
 * 基于 StringCoder 接口封装 UTF-8 字符编码的转换能力，
 * 提供字符串与 UTF-8 字节数组的互转
 */
public final class UTF8 {

    /**
     * 将字符串编码为 UTF-8 字节数组
     * @param string 待编码的字符串
     * @return UTF-8 编码的字节数组
     */
    public static byte[] encode(String string){
        return coder.encode(string);
    }

    /**
     * 将 UTF-8 字节数组解码为字符串
     * @param utf8 待解码的 UTF-8 字节数组
     * @return 解码后的字符串
     */
    public static String decode(byte[] utf8) {
        return coder.decode(utf8);
    }

    // 默认的 UTF-8 编解码器（内置实现，无需外部初始化）
    public static StringCoder coder = new StringCoder(){

        @SuppressWarnings("CharsetObjectCanBeUsed")
        @Override
        public byte[] encode(String string){
            // 将字符串转换为UTF-8字节数组
            return string.getBytes(Charset.forName("UTF-8"));
        }

        @SuppressWarnings("CharsetObjectCanBeUsed")
        @Override
        public String decode(byte[] utf8){
            // 将UTF-8 字节数组转换为字符串
            return new String(utf8,Charset.forName("UTF-8"));
        }
    };
}
