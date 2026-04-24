package com.acmecorp.catalog.config;

import jakarta.annotation.PreDestroy;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Named;
import jakarta.inject.Singleton;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

@Singleton
public class VirtualThreadExecutorProducer {

    private final ExecutorService executor = createExecutor();

    @Produces
    @ApplicationScoped
    @Named("virtualThreadExecutor")
    public ExecutorService virtualThreadExecutor() {
        return executor;
    }

    private static ExecutorService createExecutor() {
        return Executors.newCachedThreadPool();
    }

    @PreDestroy
    void shutdown() {
        executor.shutdown();
    }
}
