package com.duda.threading;


import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReadWriteLock;
import java.util.concurrent.locks.ReentrantReadWriteLock;

/**
 * 线程安全的任务池（任务队列）
 * 封装线程安全的 Runnable 任务列表，负责任务的添加和取出，
 * 是后台线程框架的核心任务仓库，支持多线程并发操作
 */
class TaskPool {
    // 任务列表（存储待执行的 Runnable 任务）
    private final List<Runnable> tasks = new ArrayList<>();
    // 读写锁（保证任务列表的线程安全，读共享、写互斥）
    private final ReadWriteLock taskLock = new ReentrantReadWriteLock();

    /**
     * 添加任务到任务池（线程安全）
     * @param runnable 待执行的任务
     */
    void addTask(Runnable runnable) {
        // 获取写锁（互斥锁，保证添加任务时其他线程无法读写）
        Lock writeLock = taskLock.writeLock();
        writeLock.lock();
        try {
            // 将任务添加到列表末尾
            tasks.add(runnable);
        } finally {
            // 释放写锁（必须在 finally 中执行，避免锁泄漏）
            writeLock.unlock();
        }
    }

    /**
     * 从任务池取出最后一个任务（线程安全，后进先出）
     * @return 待执行的任务，无任务时返回 null
     */
    Runnable getTask() {
        Runnable runnable;
        // 获取写锁（取出任务会修改列表，需互斥）
        Lock writeLock = taskLock.writeLock();
        writeLock.lock();
        try {
            // NOTICE: 取出最后一个任务（后进先出，优先执行最新添加的任务）
            int index = tasks.size() - 1;
            if (index < 0) {
                // 任务列表为空，返回 null
                runnable = null;
            } else {
                // 移除并返回最后一个任务
                runnable = tasks.remove(index);
            }
        } finally {
            // 释放写锁
            writeLock.unlock();
        }
        return runnable;
    }
}
