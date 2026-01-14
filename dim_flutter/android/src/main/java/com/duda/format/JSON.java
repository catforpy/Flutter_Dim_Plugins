package com.duda.format;

/**
 * JSON 序列化工具类
 * 基于 ObjectCoder 接口封装 JSON 格式的序列化/反序列化能力，
 * 底层实现可灵活替换（如 FastJSON、Gson 等）
 */
public final class JSON {

    /**
     * 将复杂对象（Map/List）序列化为 JSON 字符串
     * @param container 待序列化的对象（通常是 Map 或 List）
     * @return JSON 格式的字符串
     */
    public static String encode(Object container) {
        return coder.encode(container);
    }

    /**
     * 将 JSON 字符串反序列化为复杂对象（Map/List）
     * @param json JSON 格式的字符串
     * @return 反序列化后的 Map/List 对象
     */
    public static Object decode(String json) {
        return coder.decode(json);
    }

    // 默认的 JSON 编解码器（需外部初始化，解耦具体实现）
    public static ObjectCoder<Object> coder = null;
    /*/ 示例实现（使用 FastJSON），已注释留档
    public static ObjectCoder<Object> coder = new ObjectCoder<Object>() {

        @Override
        public String encode(Object container) {
            return com.alibaba.fastjson.JSON.toJSONString(container);
        }

        @Override
        public Object decode(String json) {
            return com.alibaba.fastjson.JSON.parse(json);
        }
    };
    /*/
}
