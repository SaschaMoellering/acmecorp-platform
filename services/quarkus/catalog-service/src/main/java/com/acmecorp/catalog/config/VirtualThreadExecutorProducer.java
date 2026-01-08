package com.acmecorp.catalog.config;

import jakarta.annotation.PreDestroy;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Singleton;
import jakarta.inject.Named;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

@Singleton
public class VirtualThreadExecutorProducer {

    private final ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();

    @Produces
    @ApplicationScoped
    @Named("virtualThreadExecutor")
    public ExecutorService virtualThreadExecutor() {
        return executor;
    }

    @PreDestroy
    void shutdown() {
        executor.shutdown();
    }
}
