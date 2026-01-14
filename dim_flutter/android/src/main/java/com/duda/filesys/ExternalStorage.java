package com.duda.filesys;


import java.io.File;
import java.io.IOException;

import com.duda.format.JSON;
import com.duda.format.UTF8;

/**
 * 外部存储工具类（静态）
 * 提供文件读写、过期文件清理、屏蔽媒体扫描等通用文件系统操作能力
 */
public abstract class ExternalStorage {

    /**
     * 禁止图库扫描指定目录下的媒体文件
     * 原理：在指定目录创建 .nomedia 文件，Android 媒体扫描器会忽略该目录
     *
     * @param dir - 目标数据目录
     * @return true 创建成功，false 创建失败
     */
    public static boolean setNoMedia(String dir){
        try{
            // 拼接 .nomedia文件路径
            String path = Paths.append(dir, ".nomedia");
            // 如果文件不存在则创建
            if(!Paths.exists(path)){
                Storage file = new Storage();
                // 写入任意内容（仅需文件存在即可）
                file.setData(UTF8.encode("Moky loves May Lee forever!"));
                file.write(path);
            }
            return true;
        }catch (IOException e) {
            e.printStackTrace();
            return false;
        }
    }

    /**
     * 循环清理指定目录下的过期文件
     *
     * @param dir     - 目标目录
     * @param expired - 过期时间戳（毫秒，从1970-01-01 UTC开始计算）
     */
    public static void cleanup(String dir, long expired) {
        File file = new File(dir);
        // 目录存在才执行清理
        if (file.exists()) {
            cleanupFile(file, expired);
        }
    }

    /**
     * 递归清理文件/目录
     * @param file 目标文件/目录
     * @param expired 过期时间戳
     */
    @SuppressWarnings("ResultOfMethodCallIgnored")
    private static void cleanupFile(File file, long expired) {
        if (file.isDirectory()) {
            // 如果是目录，递归清理子目录/文件
            cleanupDirectory(file, expired);
        } else if (file.lastModified() < expired) {
            // 如果是文件且最后修改时间早于过期时间，删除文件
            file.delete();
        }
    }

    /**
     * 清理目录下的过期文件
     * @param dir 目标目录
     * @param expired 过期时间戳
     */
    private static void cleanupDirectory(File dir, long expired) {
        // 获取目录下所有子文件/目录
        File[] children = dir.listFiles();
        if (children == null || children.length == 0) {
            // 目录为空，直接返回
            return;
        }
        // 遍历子文件/目录，逐个清理
        for (File child : children) {
            cleanupFile(child, expired);
        }
    }

    //-------- 读取文件 --------

    /**
     * 通用文件读取方法
     * @param path 文件路径
     * @return 文件二进制数据
     * @throws IOException 读取失败时抛出异常
     */
    private static byte[] load(String path) throws IOException {
        Storage file = new Storage();
        file.read(path);
        return file.getData();
    }

    /**
     * 从文件加载二进制数据
     *
     * @param path - 文件路径
     * @return 文件二进制数据
     * @throws IOException 读取失败或数据为空时抛出异常
     */
    public static byte[] loadBinary(String path) throws IOException {
        byte[] data = load(path);
        if (data == null) {
            throw new IOException("failed to load binary file: " + path);
        }
        return data;
    }

    /**
     * 从文件加载文本内容
     *
     * @param path - 文件路径
     * @return 文本字符串（UTF-8 编码）
     * @throws IOException 读取失败或数据为空时抛出异常
     */
    public static String loadText(String path) throws IOException {
        byte[] data = load(path);
        if (data == null) {
            throw new IOException("failed to load text file: " + path);
        }
        // 二进制数据转 UTF-8 文本
        return UTF8.decode(data);
    }

    /**
     * 从文件加载 JSON 数据
     *
     * @param path - 文件路径
     * @return JSON 解析后的 Map/List 对象
     * @throws IOException 读取失败或数据为空时抛出异常
     */
    public static Object loadJSON(String path) throws IOException {
        byte[] data = load(path);
        if (data == null) {
            throw new IOException("failed to load JSON file: " + path);
        }
        // 二进制数据转 UTF-8 文本，再解析为 JSON 对象
        return JSON.decode(UTF8.decode(data));
    }

    //-------- 写入文件 --------

    /**
     * 通用文件写入方法
     * @param data 要写入的二进制数据
     * @param path 文件路径
     * @return 实际写入的字节数
     * @throws IOException 写入失败时抛出异常
     */
    private static int save(byte[] data, String path) throws IOException {
        Storage file = new Storage();
        file.setData(data);
        return file.write(path);
    }

    /**
     * 将二进制数据保存到文件
     *
     * @param data - 二进制数据
     * @param path - 文件路径
     * @return 写入的字节数
     * @throws IOException 写入失败或写入长度不匹配时抛出异常
     */
    public static int saveBinary(byte[] data, String path) throws IOException {
        int len = save(data, path);
        if (len != data.length) {
            throw new IOException("failed to save binary file: " + path);
        }
        return len;
    }

    /**
     * 将文本内容保存到文件
     *
     * @param text - 文本字符串
     * @param path - 文件路径
     * @return 写入的字节数
     * @throws IOException 写入失败或写入长度不匹配时抛出异常
     */
    public static int saveText(String text, String path) throws IOException {
        // 文本转 UTF-8 二进制数据
        byte[] data = UTF8.encode(text);
        int len = save(data, path);
        if (len != data.length) {
            throw new IOException("failed to save text file: " + path);
        }
        return len;
    }

    /**
     * 将 JSON 对象（Map/List）保存到文件
     *
     * @param object - Map/List 类型的 JSON 对象
     * @param path - 文件路径
     * @return 写入的字节数
     * @throws IOException 写入失败或写入长度不匹配时抛出异常
     */
    public static int saveJSON(Object object, String path) throws IOException {
        // JSON 对象转 UTF-8 二进制数据
        byte[] json = UTF8.encode(JSON.encode(object));
        int len = save(json, path);
        if (len != json.length) {
            throw new IOException("failed to save text file: " + path);
        }
        return len;
    }
}
