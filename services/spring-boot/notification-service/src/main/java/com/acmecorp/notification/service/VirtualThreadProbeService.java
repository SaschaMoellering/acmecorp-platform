package com.acmecorp.notification.service;

import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.concurrent.CompletableFuture;

@Service
public class VirtualThreadProbeService {

    @Async
    public CompletableFuture<Boolean> isRunningOnVirtualThread() {
        return CompletableFuture.completedFuture(isVirtualThread());
    }

    private boolean isVirtualThread() {
        try {
            return (Boolean) Thread.class.getMethod("isVirtual").invoke(Thread.currentThread());
        } catch (Exception ignored) {
            return false;
        }
    }
}
