package com.acmecorp.orders.startup;

import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.boot.context.event.ApplicationStartedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;

@Component
public class StartupTimeline {

    private static final AtomicLong JVM_MAIN_START_NANOS = new AtomicLong();
    private static final AtomicLong JVM_MAIN_START_EPOCH_MILLIS = new AtomicLong();

    private final AtomicLong applicationStartedEpochMillis = new AtomicLong();
    private final AtomicLong applicationReadyEpochMillis = new AtomicLong();
    private final AtomicLong applicationStartedSinceJvmStartMillis = new AtomicLong(-1);
    private final AtomicLong applicationReadySinceJvmStartMillis = new AtomicLong(-1);

    public static void markJvmMainStart() {
        JVM_MAIN_START_NANOS.compareAndSet(0, System.nanoTime());
        JVM_MAIN_START_EPOCH_MILLIS.compareAndSet(0, System.currentTimeMillis());
    }

    @EventListener
    public void onApplicationStarted(ApplicationStartedEvent event) {
        long nowMillis = System.currentTimeMillis();
        applicationStartedEpochMillis.compareAndSet(0, nowMillis);
        applicationStartedSinceJvmStartMillis.compareAndSet(-1, elapsedSinceJvmStartMillis());
    }

    @EventListener
    public void onApplicationReady(ApplicationReadyEvent event) {
        long nowMillis = System.currentTimeMillis();
        applicationReadyEpochMillis.compareAndSet(0, nowMillis);
        applicationReadySinceJvmStartMillis.compareAndSet(-1, elapsedSinceJvmStartMillis());
    }

    public Map<String, Object> snapshot() {
        return Map.of(
                "jvmMainStartEpochMillis", JVM_MAIN_START_EPOCH_MILLIS.get(),
                "applicationStartedEpochMillis", applicationStartedEpochMillis.get(),
                "applicationReadyEpochMillis", applicationReadyEpochMillis.get(),
                "applicationStartedSinceJvmStartMillis", applicationStartedSinceJvmStartMillis.get(),
                "applicationReadySinceJvmStartMillis", applicationReadySinceJvmStartMillis.get()
        );
    }

    private long elapsedSinceJvmStartMillis() {
        long startNanos = JVM_MAIN_START_NANOS.get();
        if (startNanos == 0) {
            return -1;
        }
        return (System.nanoTime() - startNanos) / 1_000_000L;
    }
}
