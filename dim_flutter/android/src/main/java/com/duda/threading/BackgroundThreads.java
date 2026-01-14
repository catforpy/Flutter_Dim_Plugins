package com.duda.threading;

/**
 * 后台线程框架总控类
 * 负责初始化任务池、线程实例，对外提供添加「紧急任务/普通任务」的接口，
 * 是业务代码调用后台线程的统一入口
 */
public final class BackgroundThreads {

    //
    //  任务池定义
    //
    // 紧急任务池（优先执行）
    private static final TaskPool rushing = new TaskPool();
    // 普通任务池（低优先级）
    private static final TaskPool waiting = new TaskPool();

    /**
     * 添加普通任务到后台执行（低优先级）
     * @param runnable 待执行的任务
     */
    public static void wait(Runnable runnable) {
        waiting.addTask(runnable);
    }

    /**
     * 添加紧急任务到后台执行（高优先级）
     * @param runnable 待执行的任务
     */
    public static void rush(Runnable runnable) {
        rushing.addTask(runnable);
    }

    //
    //  线程池定义
    //
    // 紧急线程：仅处理 rushing 任务池的任务（高优先级）
    private static final TaskThread thread1 = new TaskThread.Urgency(rushing);
    // 普通线程1：优先处理 rushing 任务池，无任务时处理 waiting 任务池
    private static final TaskThread thread2 = new TaskThread.Trivial(rushing, waiting);
    // 普通线程2：优先处理 rushing 任务池，无任务时处理 waiting 任务池
    private static final TaskThread thread3 = new TaskThread.Trivial(rushing, waiting);

    /**
     * 停止所有后台线程
     * 置空运行标记，线程会在下次循环时退出
     */
    public static void stop() {
        thread1.running = false;
        thread2.running = false;
        thread3.running = false;
    }

    // 静态初始化块：类加载时自动启动所有后台线程
    static {
        thread1.start();
        thread2.start();
        thread3.start();
    }
}
