package com.duda.threading;

/**
 * 自定义任务执行线程抽象类
 * 继承 Thread 类，定义后台线程的核心执行逻辑，
 * 子类需实现 getTask() 方法指定任务来源
 */
abstract class TaskThread extends Thread{

    // 线程运行标记：true 运行中，false 停止
    boolean running = false;

    /**
     * 启动线程（重写父类方法，初始化运行标记）
     */
    @Override
    public void start() {
        running = true;
        super.start();
    }

    /**
     * 线程核心执行逻辑
     * 循环获取任务并执行，无任务时休眠，直到运行标记置为 false
     */
    @Override
    public void run() {
        Runnable task;
        // 运行标记为 true 时持续循环
        while (running) {
            // 获取待执行的任务（由子类实现）
            task = getTask();
            if (task == null) {
                // 无任务时休眠 101ms，避免空循环占用 CPU
                // no more task, have a rest. ^_^
                _sleep(101);
                continue;
            }
            try {
                // 执行任务
                task.run();
            } catch (Exception e) {
                // 捕获任务执行异常，避免线程崩溃
                e.printStackTrace();
            }
        }
    }

    /**
     * 获取待执行的任务（抽象方法，由子类实现）
     * @return 待执行的任务，无任务时返回 null
     */
    protected abstract Runnable getTask();

    /**
     * 线程休眠工具方法（封装异常处理）
     * @param millis 休眠时长（毫秒）
     */
    @SuppressWarnings("SameParameterValue")
    private static void _sleep(long millis) {
        try {
            Thread.sleep(millis);
        } catch (InterruptedException e) {
            // 捕获中断异常，打印堆栈但不终止线程
            e.printStackTrace();
        }
    }

    /**
     * 紧急任务线程
     * 仅处理指定的紧急任务池，优先级最高
     */
    static class Urgency extends TaskThread {

        // 紧急任务池
        private final TaskPool pool1;

        /**
         * 构造方法：绑定紧急任务池
         * @param pool 紧急任务池
         */
        Urgency(TaskPool pool) {
            super();
            this.pool1 = pool;
        }

        /**
         * 获取紧急任务池中的任务
         * @return 紧急任务，无任务时返回 null
         */
        @Override
        protected Runnable getTask() {
            return pool1.getTask();
        }
    }

    /**
     * 普通任务线程
     * 优先处理紧急任务池，无紧急任务时处理普通任务池
     */
    static class Trivial extends TaskThread {

        // 紧急任务池（优先）
        private final TaskPool pool1;
        // 普通任务池（次优先）
        private final TaskPool pool2;

        /**
         * 构造方法：绑定紧急/普通任务池
         * @param pool1 紧急任务池
         * @param pool2 普通任务池
         */
        Trivial(TaskPool pool1, TaskPool pool2) {
            super();
            this.pool1 = pool1;
            this.pool2 = pool2;
        }

        /**
         * 优先获取紧急任务，无则获取普通任务
         * @return 待执行的任务，无任务时返回 null
         */
        @Override
        protected Runnable getTask() {
            Runnable task = pool1.getTask();
            if (task == null) {
                // 无紧急任务时，获取普通任务
                task = pool2.getTask();
            }
            return task;
        }
    }
}
