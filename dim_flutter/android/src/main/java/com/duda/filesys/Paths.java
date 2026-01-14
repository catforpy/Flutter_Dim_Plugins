package com.duda.filesys;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

import com.duda.utils.ArrayUtils;

/**
 * 路径处理工具接口（静态工具方法集合）
 * 封装文件路径的拼接、解析、校验、清理等通用操作，适配 Windows/Linux/Android 不同系统的路径分隔符
 * 所有方法均为静态方法，无需实例化，直接通过接口名调用
 */
public interface Paths {

    /**
     * 拼接路径（核心方法）
     * 将基础路径与多个子路径片段拼接，自动补充系统默认的路径分隔符（如 Linux/Android 是 /，Windows 是 \）
     *
     * @param path       基础路径（如 "/sdcard/data" 或 "C:\\Users"）
     * @param components 可变参数，待拼接的子路径片段（如 "cache", "temp.txt"）
     * @return 拼接后的完整路径（如 "/sdcard/data/cache/temp.txt"）
     */
    static String append(String path, String... components) {
        // 字符串构建器，高效拼接路径（避免多次字符串拼接产生冗余对象）
        StringBuilder sb = new StringBuilder();
        sb.append(path);
        // 遍历所有子路径片段，逐个拼接
        for (String item : components) {
            sb.append(File.separator); // 自动适配系统分隔符
            sb.append(item);
        }
        return sb.toString();
    }

    /**
     * 从完整路径中提取文件名（含后缀）
     * 支持处理带参数/锚点的路径（如 "/data/file.txt?param=1#hash" 会提取 "file.txt"）
     * 兼容 Windows/Linux 分隔符（/ 或 \）
     *
     * @param path 完整路径（如 "/sdcard/doc/笔记.md" 或 "C:\\Downloads\\photo.jpg?size=1024"）
     * @return 纯文件名（如 "笔记.md"、"photo.jpg"），路径无分隔符时返回原路径
     */
    static String filename(String path) {
        int pos;
        // 第一步：移除路径中的 URL 参数（? 后的内容）
        pos = path.indexOf("?");
        if (pos >= 0) {
            path = path.substring(0, pos);
        }
        // 第二步：移除路径中的锚点（# 后的内容）
        pos = path.indexOf("#");
        if (pos >= 0) {
            path = path.substring(0, pos);
        }
        // 第三步：查找最后一个 Linux 分隔符 /
        pos = path.lastIndexOf("/");
        if (pos < 0) {
            // 未找到 /，尝试查找 Windows 分隔符 \
            pos = path.lastIndexOf("\\");
            if (pos < 0) {
                // 无任何分隔符，路径本身就是文件名，直接返回
                return path;
            }
        }
        // 截取最后一个分隔符后的内容（即文件名）
        return path.substring(pos + 1);
    }

    /**
     * 从文件名中提取扩展名（后缀）
     * 扩展名指最后一个 "." 后的字符串，无 "." 时返回 null
     *
     * @param filename 文件名（如 "photo.jpg"、"document.tar.gz"、"readme"）
     * @return 扩展名（如 "jpg"、"gz"），无扩展名时返回 null
     */
    static String extension(String filename) {
        // 查找最后一个 "." 的位置（处理多后缀文件，如 tar.gz 取 gz）
        int pos = filename.lastIndexOf(".");
        if (pos < 0) {
            // 无扩展名，返回 null
            return null;
        }
        // 截取 "." 后的扩展名
        return filename.substring(pos + 1);
    }

    /**
     * 从完整路径中提取父目录路径
     * 兼容不同系统分隔符，处理路径末尾带分隔符的场景（如 "/data/cache/" 父目录是 "/data"）
     *
     * @param path 完整路径（如 "/sdcard/data/file.txt"、"C:\\Downloads\\temp\\"）
     * @return 父目录路径（如 "/sdcard/data"、"C:\\Downloads"）；
     *         根目录（如 "/"）返回自身；相对路径无父目录时返回 null
     */
    static String parent(String path) {
        int pos;
        // 场景1：路径以 / 结尾（Linux/Android）
        if (path.endsWith("/")) {
            // 查找倒数第二个 / 的位置（跳过末尾的分隔符）
            pos = path.lastIndexOf("/", path.length() - 2);
        }
        // 场景2：路径以 \ 结尾（Windows）
        else if (path.endsWith("\\")) {
            pos = path.lastIndexOf("\\", path.length() - 2);
        }
        // 场景3：路径不以分隔符结尾
        else {
            // 先找 Linux 分隔符 /
            pos = path.lastIndexOf("/");
            if (pos < 0) {
                // 再找 Windows 分隔符 \
                pos = path.lastIndexOf("\\");
            }
        }
        // 无分隔符（相对路径），返回 null
        if (pos < 0) {
            return null;
        }
        // 根目录（如 "/"），返回自身
        else if (pos == 0) {
            return "/";
        }
        // 截取父目录路径
        return path.substring(0, pos);
    }

    /**
     * 将相对路径转换为绝对路径
     * 自动处理路径中的 "./"（当前目录）、"../"（上级目录），生成规范的绝对路径
     * 兼容 Windows/Linux 分隔符，支持判断已为绝对路径的场景（如 "/data"、"C:\\file.txt"）
     *
     * @param relative 相对路径（如 "../cache/file.txt"、"./temp"）
     * @param base     基准绝对路径（如 "/sdcard/data"、"C:\\Users\\Admin"）
     * @return 规范化的绝对路径
     * @throws AssertionError 基准路径或相对路径为空时抛出断言异常
     */
    static String abs(String relative, String base) {
        // 断言：基准路径和相对路径不能为空（开发期校验，发布时可关闭）
        assert base.length() > 0 && relative.length() > 0 : "paths error: " + base + ", " + relative;

        // 判断相对路径是否已是绝对路径：
        // 1. Linux/Android 绝对路径以 / 开头；
        // 2. Windows 绝对路径含 :（如 C:\\）；
        // 3. URL 路径（如 file:///sdcard）也视为绝对路径
        if (relative.startsWith("/") || relative.indexOf(":") > 0) {
            return relative;
        }

        String path;
        // 拼接基准路径和相对路径（自动补充分隔符）
        if (base.endsWith("/") || base.endsWith("\\")) {
            // 基准路径已带分隔符，直接拼接
            path = base + relative;
        } else {
            // 基准路径无分隔符，先判断基准路径的分隔符类型，再补充
            String separator = base.contains("\\") ? "\\" : "/";
            path = base + separator + relative;
        }

        // 清理路径中的 ./ 或 ../ 等冗余片段
        if (path.contains("./")) {
            return tidy(path, "/");
        } else if (path.contains(".\\")) {
            return tidy(path, "\\");
        } else {
            // 无冗余片段，直接返回
            return path;
        }
    }

    /**
     * 清理路径中的冗余片段（核心方法）
     * 移除路径中的 "./"（当前目录），处理 "../"（上级目录）的回退逻辑，生成规范路径
     * 例如：/data/./cache/../file.txt → /data/file.txt
     *
     * @param path      待清理的路径（如 "/sdcard/../data/./temp.txt"）
     * @param separator 路径分隔符（/ 或 \）
     * @return 规范化的路径（如 "/data/temp.txt"）
     * @throws AssertionError 路径回退超出根目录时抛出（如 "../file.txt" 无上级目录）
     */
    static String tidy(String path, final String separator) {
        // 定义路径片段常量：上级目录（../ 或 ..\）、当前目录（./ 或 .\）
        final String parent = ".." + separator;
        final String current = "." + separator;
        // 存储路径片段的列表，用于重组规范路径
        List<String> array = new ArrayList<>();
        String next;
        int left, right = 0;

        // 循环拆分路径为多个片段（按分隔符分割）
        while (right >= 0) {
            left = right;
            // 查找下一个分隔符的位置
            right = path.indexOf(separator, left);
            if (right < 0) {
                // 最后一个片段（无后续分隔符）
                next = path.substring(left);
            } else {
                // 截取当前片段（包含分隔符）
                right += separator.length();
                next = path.substring(left, right);
            }

            // 处理上级目录片段（../）：移除列表最后一个片段（回退一级）
            if (next.equals(parent)) {
                // 断言：回退不能超出根目录（避免 ../ 过多导致路径错误）
                assert array.size() > 0 : "path error: " + path;
                array.remove(array.size() - 1);
            }
            // 处理当前目录片段（./）：忽略，不加入列表
            else if (!next.equals(current)) {
                // 普通片段，加入列表
                array.add(next);
            }
        }

        // 将清理后的片段列表拼接为完整路径
        return ArrayUtils.join("", array);
    }

    /**
     * 检查文件/目录是否存在
     * 封装 File.exists() 方法，简化路径存在性校验
     *
     * @param path 文件/目录路径
     * @return true 存在，false 不存在
     */
    static boolean exists(String path) {
        File file = new File(path);
        return file.exists();
    }

    /**
     * 创建多级目录（递归创建）
     * 封装 File.mkdirs() 方法，目录已存在时返回是否为目录（避免重复创建）
     *
     * @param path 要创建的目录路径（如 "/sdcard/data/cache/temp"）
     * @return true 创建成功 或 目录已存在且是目录；false 创建失败（如权限不足）
     */
    static boolean mkdirs(String path) {
        File file = new File(path);
        if (file.exists()) {
            // 目录已存在，校验是否为目录（避免路径是文件的情况）
            return file.isDirectory();
        } else {
            // 递归创建多级目录
            return file.mkdirs();
        }
    }

    /**
     * 删除文件/空目录
     * 封装 File.delete() 方法，文件不存在时视为删除成功（避免抛出异常）
     * 注意：无法删除非空目录（需先递归删除子文件/目录）
     *
     * @param path 要删除的文件/目录路径
     * @return true 删除成功 或 文件不存在；false 删除失败（如权限不足、目录非空）
     */
    static boolean delete(String path) {
        File file = new File(path);
        if (file.exists()) {
            return file.delete();
        } else {
            // 文件不存在，返回 true（视为删除成功，简化业务逻辑）
            return true;
        }
    }
}
