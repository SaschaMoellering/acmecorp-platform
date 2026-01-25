package com.acmecorp.analytics.service;

import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.concurrent.CompletableFuture;

@Service
public class VirtualThreadProbeService {

    @Async
    public CompletableFuture<Boolean> isRunningOnVirtualThread() {
        return CompletableFuture.completedFuture(Thread.currentThread().isVirtual());
    }
}
