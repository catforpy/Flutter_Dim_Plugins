package com.duda.filesys;

/**
 * 本地缓存路径管理器（单例，枚举实现）
 * 为APP不同业务场景生成标准化的文件路径，管理缓存目录/临时目录的创建和初始化
 */
public enum LocalCache {

    // 单例实例
    INSTANCE;

    /**
     * 获取 LocalCache 单例实例
     * @return 单例对象
     */
    public static LocalCache getInstance() {
        return INSTANCE;
    }

    //
    //  目录相关成员变量
    //
    // 缓存目录默认路径
    private String cacheDir = "/tmp/.dim";
    // 临时目录默认路径
    private String tmpDir = "/tmp/.dim";
    // 缓存目录是否已创建并初始化
    private boolean cacheBuilt = false;
    // 临时目录是否已创建并初始化
    private boolean tmpBuilt = false;

    /**
     * 构建并初始化目录
     * 确保目录存在，并创建 .nomedia 文件禁止媒体扫描
     * @param root 目标目录路径
     * @param built 目录是否已构建的标记
     * @return true 目录构建/初始化成功，false 失败
     */
    private boolean buildDir(String root, boolean built) {
        if (built) {
            // 目录已构建，直接返回成功
            return true;
        }
        // 确保目录存在，并创建 .nomedia 文件禁止图库扫描
        return Paths.mkdirs(root) && ExternalStorage.setNoMedia(root);
    }

    /**
     * 获取受保护的缓存目录
     * 用于存储元数据/签证/文档、图片/音频/视频等持久化缓存文件
     *
     * @return 缓存目录路径（示例："/sdcard/Android/data/chat.dim.sechat/cache"）
     */
    public String getCachesDirectory() {
        // 确保目录已构建并初始化
        cacheBuilt = buildDir(cacheDir, cacheBuilt);
        return cacheDir;
    }

    /**
     * 设置缓存目录根路径
     * @param root 新的缓存目录根路径
     */
    public void setCachesDirectory(String root) {
        cacheDir = root;
        // 重置构建标记，下次获取时重新构建
        cacheBuilt = false;
    }

    /**
     * 获取受保护的临时目录
     * 用于存储上传/下载过程中的临时文件
     *
     * @return 临时目录路径（示例："/data/data/chat.dim.sechat/cache"）
     */
    public String getTemporaryDirectory() {
        // 确保目录已构建并初始化
        tmpBuilt = buildDir(tmpDir, tmpBuilt);
        return tmpDir;
    }

    /**
     * 设置临时目录根路径
     * @param root 新的临时目录根路径
     */
    public void setTemporaryDirectory(String root) {
        tmpDir = root;
        // 重置构建标记，下次获取时重新构建
        tmpBuilt = false;
    }

    //
    //  业务路径生成
    //

    /**
     * 生成头像图片文件路径
     * 采用二级目录（AA/BB）分散存储，避免单目录文件过多
     *
     * @param filename - 头像文件名（格式：md5数据的十六进制字符串 + 扩展名）
     * @return 头像文件完整路径（示例："/sdcard/chat.dim.sechat/caches/avatar/{AA}/{BB}/{filename}"）
     */
    public String getAvatarFilePath(String filename) {
        String dir = getCachesDirectory();
        // 取文件名前两位作为一级子目录
        String AA = filename.substring(0, 2);
        // 取文件名2-4位作为二级子目录
        String BB = filename.substring(2, 4);
        // 拼接完整路径
        return Paths.append(dir, "avatar", AA, BB, filename);
    }

    /**
     * 生成缓存文件路径（图片/音频/视频等）
     * 采用二级目录（AA/BB）分散存储，避免单目录文件过多
     *
     * @param filename - 缓存文件名（格式：md5数据的十六进制字符串 + 扩展名）
     * @return 缓存文件完整路径（示例："/sdcard/chat.dim.sechat/caches/files/{AA}/{BB}/{filename}"）
     */
    public String getCacheFilePath(String filename) {
        String dir = getCachesDirectory();
        // 取文件名前两位作为一级子目录
        String AA = filename.substring(0, 2);
        // 取文件名2-4位作为二级子目录
        String BB = filename.substring(2, 4);
        // 拼接完整路径
        return Paths.append(dir, "files", AA, BB, filename);
    }

    /**
     * 生成上传文件路径（加密数据）
     *
     * @param filename - 上传文件名（格式：md5数据的十六进制字符串 + 扩展名）
     * @return 上传文件完整路径（示例："/sdcard/chat.dim.sechat/tmp/upload/{filename}"）
     */
    public String getUploadFilePath(String filename) {
        String dir = getTemporaryDirectory();
        // 拼接完整路径
        return Paths.append(dir, "upload", filename);
    }

    /**
     * 生成下载文件路径（加密数据）
     *
     * @param filename - 下载文件名（格式：md5数据的十六进制字符串 + 扩展名）
     * @return 下载文件完整路径（示例："/sdcard/chat.dim.sechat/tmp/download/{filename}"）
     */
    public String getDownloadFilePath(String filename) {
        String dir = getTemporaryDirectory();
        // 拼接完整路径
        return Paths.append(dir, "download", filename);
    }
}
