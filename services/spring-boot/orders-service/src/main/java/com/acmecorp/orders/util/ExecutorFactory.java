package com.acmecorp.orders.util;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public final class ExecutorFactory {

    private ExecutorFactory() {
    }

    // Java baseline compatibility shim: avoid Java 21 virtual-thread APIs on the Java 17 branch.
    public static ExecutorService create() {
        return Executors.newCachedThreadPool();
    }

    public static void shutdown(ExecutorService executor) {
        executor.shutdown();
        try {
            if (!executor.awaitTermination(5, TimeUnit.SECONDS)) {
                executor.shutdownNow();
            }
        } catch (InterruptedException ex) {
            executor.shutdownNow();
            Thread.currentThread().interrupt();
        }
    }
}
