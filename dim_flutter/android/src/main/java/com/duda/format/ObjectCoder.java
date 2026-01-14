package com.duda.format;

/**
 * 对象编解码器接口
 * 定义复杂对象（Map/List）与字符串之间的转换规则，
 * 可适配 JSON、XML 等任意结构化数据格式，实现序列化/反序列化解耦
 *
 * @param <T> 待序列化/反序列化的对象类型（通常是 Map 或 List）
 */
public interface ObjectCoder<T> {

    /**
     * 将复杂对象（Map/List）序列化为字符串
     *
     * @param object - 待序列化的对象（Map 或 List）
     * @return 序列化后的字符串（如 JSON/XML 格式）
     */
    String encode(T object);

    /**
     * 将字符串反序列化为复杂对象（Map/List）
     *
     * @param string - 序列化后的字符串（如 JSON/XML 格式）
     * @return 反序列化后的 Map 或 List 对象
     */
    T decode(String string);
}
