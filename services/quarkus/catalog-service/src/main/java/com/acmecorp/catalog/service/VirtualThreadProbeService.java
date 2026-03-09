package com.acmecorp.catalog.service;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;

@ApplicationScoped
public class VirtualThreadProbeService {

    private final ExecutorService executorService;

    @Inject
    public VirtualThreadProbeService(@Named("virtualThreadExecutor") ExecutorService executorService) {
        this.executorService = executorService;
    }

    public boolean isRunningOnVirtualThread() {
        try {
            return executorService.submit(() -> isVirtual(Thread.currentThread())).get();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Interrupted while checking virtual thread execution", e);
        } catch (ExecutionException e) {
            throw new IllegalStateException("Failed to check virtual thread execution", e);
        }
    }

    private static boolean isVirtual(Thread thread) {
        try {
            Method method = Thread.class.getMethod("isVirtual");
            return (Boolean) method.invoke(thread);
        } catch (NoSuchMethodException e) {
            return false;
        } catch (IllegalAccessException | InvocationTargetException e) {
            throw new IllegalStateException("Failed to inspect thread type", e);
        }
    }
}
