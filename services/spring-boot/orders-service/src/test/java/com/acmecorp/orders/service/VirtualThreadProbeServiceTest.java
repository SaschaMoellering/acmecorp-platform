package com.acmecorp.orders.service;

import com.acmecorp.orders.config.VirtualThreadsConfig;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.junit.jupiter.SpringJUnitConfig;

import java.util.concurrent.Executors;

import static org.assertj.core.api.Assertions.assertThat;

@SpringJUnitConfig(classes = {VirtualThreadsConfig.class, VirtualThreadProbeService.class})
@TestPropertySource(properties = "spring.threads.virtual.enabled=true")
class VirtualThreadProbeServiceTest {

    @Autowired
    private VirtualThreadProbeService virtualThreadProbeService;

    @Test
    void asyncWorkRunsOnVirtualThread() {
        boolean isVirtual = virtualThreadProbeService.isRunningOnVirtualThread().join();
        assertThat(isVirtual).isEqualTo(isVirtualThreadSupported());
    }

    private boolean isVirtualThreadSupported() {
        try {
            Thread.class.getMethod("isVirtual");
            Executors.class.getMethod("newVirtualThreadPerTaskExecutor");
            return true;
        } catch (Exception ignored) {
            return false;
        }
    }
}
