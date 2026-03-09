package com.acmecorp.catalog.config;

import jakarta.annotation.PreDestroy;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Named;
import jakarta.inject.Singleton;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
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
        try {
            Method factory = Executors.class.getMethod("newVirtualThreadPerTaskExecutor");
            return (ExecutorService) factory.invoke(null);
        } catch (NoSuchMethodException e) {
            return Executors.newCachedThreadPool();
        } catch (IllegalAccessException | InvocationTargetException e) {
            throw new IllegalStateException("Failed to create virtual-thread executor", e);
        }
    }

    @PreDestroy
    void shutdown() {
        executor.shutdown();
    }
}
