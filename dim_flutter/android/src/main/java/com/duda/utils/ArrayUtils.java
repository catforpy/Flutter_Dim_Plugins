package com.duda.utils;

import java.util.ArrayList;
import java.util.List;

/**
 * 数组/字符串工具接口（静态工具方法集合）
 * 核心功能：
 * 1. 字节数组的拼接（按分隔符）、拆分（按分隔符，如换行符）
 * 2. 字符串的拼接（按分隔符）、拆分（按分隔符，如换行符）
 * 3. 封装换行符（\n）相关的快捷操作（行拼接/拆分）
 * 所有方法均为静态方法，无需实例化，直接通过接口名调用
 */
public interface ArrayUtils {

    /**
     * 换行符常量（ASCII 码 10），作为默认的行分隔符
     * 对应字符 '\n'，适用于多平台的文本行分隔场景
     */
    byte LINEFEED = '\n';

    /**
     * 快捷方法：将多个字节数组按「换行符」拼接成一个完整的字节数组
     * 本质是调用 join(LINEFEED, packages)，专用于文本行的拼接
     *
     * @param packages 待拼接的字节数组列表（每个元素代表一行字节数据）
     * @return 拼接后的完整字节数组（行之间用 \n 分隔，末尾无多余换行符）；空列表返回 null
     */
    static byte[] joinLines(List<byte[]> packages) {
        return join(LINEFEED, packages);
    }

    /**
     * 快捷方法：将字节数组按「换行符」拆分成多个字节数组（每行一个）
     * 本质是调用 split(LINEFEED, data)，专用于文本行的拆分
     *
     * @param data 待拆分的字节数组（包含多个换行符分隔的行）
     * @return 拆分后的字节数组列表（每个元素对应一行数据，不含换行符）；空数据返回空列表
     */
    static List<byte[]> splitLines(byte[] data) {
        return split(LINEFEED, data);
    }

    /**
     * 快捷方法：将字符串按「换行符」拆分成多个字符串（每行一个）
     * 本质是调用 split("\\n", text)，专用于文本行的拆分
     *
     * @param text 待拆分的字符串（包含多个换行符分隔的行）
     * @return 拆分后的字符串列表（每个元素对应一行文本，不含换行符）；空字符串返回空列表
     */
    static List<String> splitLines(String text) {
        return split(""+LINEFEED, text);
    }

    /**
     * 核心方法：将多个字节数组按指定分隔符拼接成一个完整的字节数组
     * 拼接规则：数组1 + 分隔符 + 数组2 + 分隔符 + ... + 数组N（末尾无分隔符）
     * 性能优化：先计算总长度再创建数组，避免多次扩容，效率高于逐字节拼接
     *
     * @param separator 字节分隔符（如 LINEFEED 即 \n）
     * @param packages  待拼接的字节数组列表（不能为空列表，否则返回 null）
     * @return 拼接后的完整字节数组；空列表返回 null
     */
    static byte[] join(byte separator, List<byte[]> packages) {
        // 获取待拼接的数组数量
        final int count = packages.size();
        int index;
        // 第一步：计算拼接后的总字节数（预分配数组大小，避免扩容）
        int size = 0;
        byte[] pack;
        for (index = 0; index < count; ++index) {
            pack = packages.get(index);
            // 每个数组长度 + 1个分隔符长度
            size += pack.length + 1;
        }
        // 空列表直接返回 null
        if (size == 0) {
            return null;
        } else {
            // 减去最后一个多余的分隔符（末尾不需要分隔符）
            size -= 1;
        }

        // 第二步：创建总缓冲区，开始拼接
        byte[] buffer = new byte[size];
        // 先复制第一个数组（无前置分隔符）
        pack = packages.get(0);
        // 使用 System.arraycopy 高效复制数组（native 方法，比循环赋值快）
        System.arraycopy(pack, 0, buffer, 0, pack.length);

        // 第三步：复制剩余数组（每个数组前加分隔符）
        int offset = pack.length; // 缓冲区当前写入位置
        for (index = 1; index < count; ++index) {
            // 写入分隔符
            buffer[offset] = separator;
            offset++; // 偏移量后移
            // 复制当前数组到缓冲区
            pack = packages.get(index);
            System.arraycopy(pack, 0, buffer, offset, pack.length);
            offset += pack.length; // 偏移量更新为当前末尾
        }

        return buffer;
    }

    /**
     * 核心方法：将字节数组按指定分隔符拆分成多个字节数组
     * 拆分规则：遇到分隔符则截断，分隔符本身不包含在结果中
     * 处理空分隔符段：连续分隔符会跳过空段（如 "a\n\nb" 拆分后为 ["a", "b"]）
     *
     * @param separator 字节分隔符（如 LINEFEED 即 \n）
     * @param data      待拆分的字节数组（null/空数组返回空列表）
     * @return 拆分后的字节数组列表（每个元素为分隔符之间的有效数据）
     */
    static List<byte[]> split(byte separator, byte[] data) {
        // 初始化结果列表
        List<byte[]> lines = new ArrayList<>();
        byte[] tmp;
        // pos1：当前段的起始位置；pos2：分隔符的位置
        int pos1 = 0, pos2;

        // 循环遍历字节数组，直到处理完所有数据
        while (pos1 < data.length) {
            // 第一步：查找下一个分隔符的位置
            pos2 = pos1;
            while (pos2 < data.length) {
                if (data[pos2] == separator) {
                    // 找到分隔符，停止查找
                    break;
                } else {
                    // 未找到，继续后移
                    ++pos2;
                }
            }

            // 第二步：提取当前段（分隔符之间的有效数据）
            if (pos2 > pos1) {
                // 创建当前段的字节数组（长度 = 分隔符位置 - 起始位置）
                tmp = new byte[pos2 - pos1];
                // 复制有效数据到临时数组
                System.arraycopy(data, pos1, tmp, 0, pos2 - pos1);
                // 添加到结果列表
                lines.add(tmp);
            }

            // 第三步：跳过当前分隔符，更新起始位置，继续处理下一段
            pos1 = pos2 + 1;
        }

        return lines;
    }

    /**
     * 核心方法：将多个字符串按指定分隔符拼接成一个完整的字符串
     * 拼接规则：字符串1 + 分隔符 + 字符串2 + ... + 字符串N（末尾无分隔符）
     * 使用 StringBuilder 高效拼接，避免字符串常量池产生冗余对象
     *
     * @param separator 字符串分隔符（如 "\n"、","）
     * @param array     待拼接的字符串列表（空列表返回空字符串）
     * @return 拼接后的完整字符串
     */
    static String join(String separator, List<String> array) {
        // 初始化字符串构建器（高效拼接）
        StringBuilder sb = new StringBuilder();
        final int count = array.size();

        if (count > 0) {
            // 先添加第一个字符串（无前置分隔符）
            sb.append(array.get(0));
            // 循环添加剩余字符串（每个字符串前加分隔符）
            for (int index = 1; index < count; ++index) {
                // 添加分隔符
                sb.append(separator);
                // 添加当前字符串
                sb.append(array.get(index));
            }
        }

        // 转换为最终字符串
        return sb.toString();
    }

    /**
     * 核心方法：将字符串按指定分隔符拆分成多个字符串
     * 拆分规则：遇到分隔符则截断，分隔符本身不包含在结果中
     * 处理空段：连续分隔符会跳过空段（如 "a,,b" 拆分后为 ["a", "b"]）
     * 支持多字符分隔符（如 "||"、"\r\n"）
     *
     * @param separator 字符串分隔符（如 "\n"、","）
     * @param text      待拆分的字符串（空字符串返回空列表）
     * @return 拆分后的字符串列表（每个元素为分隔符之间的有效文本）
     */
    static List<String> split(String separator, String text) {
        // 初始化结果列表
        List<String> array = new ArrayList<>();
        // pos1：当前段的起始位置；pos2：分隔符的位置
        int pos1 = 0, pos2;

        // 循环遍历字符串，直到处理完所有字符
        while (pos1 < text.length()) {
            // 第一步：从 pos1 开始查找分隔符的位置
            pos2 = text.indexOf(separator, pos1);

            if (pos2 < 0) {
                // 未找到分隔符，说明是最后一段，直接截取剩余部分
                array.add(text.substring(pos1));
                // 退出循环
                break;
            }

            // 第二步：提取当前段（分隔符之间的有效文本）
            if (pos2 > pos1) {
                // 截取 [pos1, pos2) 区间的字符串（不含分隔符）
                array.add(text.substring(pos1, pos2));
            }

            // 第三步：跳过当前分隔符（支持多字符分隔符），更新起始位置
            pos1 = pos2 + separator.length();
        }

        return array;
    }
}
