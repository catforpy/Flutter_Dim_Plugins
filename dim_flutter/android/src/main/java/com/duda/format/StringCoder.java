package com.duda.format;

/**
 * 字符串编解码器接口
 * 定义字符串与二进制字节数组之间的转换规则，
 * 可适配 UTF-8、UTF-16、GBK 等任意字符编码格式
 */
public interface StringCoder {

    /**
     * 将字符串编码为二进制字节数组
     *
     * @param string - 待编码的本地字符串
     * @return 编码后的二进制字节数组
     */
    byte[] encode(String string);

    /**
     * 将二进制字节数组解码为字符串
     *
     * @param data - 待解码的二进制字节数组
     * @return 解码后的本地字符串
     */
    String decode(byte[] data);
}
