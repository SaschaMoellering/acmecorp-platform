package com.acmecorp.orders.service;

import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.concurrent.CompletableFuture;

@Service
public class VirtualThreadProbeService {

    @Async
    public CompletableFuture<Boolean> isRunningOnVirtualThread() {
        return CompletableFuture.completedFuture(isVirtual(Thread.currentThread()));
    }

    static boolean isVirtual(Thread thread) {
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
