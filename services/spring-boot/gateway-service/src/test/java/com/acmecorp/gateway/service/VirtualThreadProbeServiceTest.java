package com.acmecorp.gateway.service;

import com.acmecorp.gateway.config.VirtualThreadsConfig;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.junit.jupiter.SpringJUnitConfig;

import static org.assertj.core.api.Assertions.assertThat;

@SpringJUnitConfig(classes = {VirtualThreadsConfig.class, VirtualThreadProbeService.class})
@TestPropertySource(properties = "spring.threads.virtual.enabled=true")
class VirtualThreadProbeServiceTest {

    @Autowired
    private VirtualThreadProbeService virtualThreadProbeService;

    @Test
    void asyncWorkRunsOnVirtualThread() {
        boolean isVirtual = virtualThreadProbeService.isRunningOnVirtualThread().join();
        assertThat(isVirtual).isTrue();
    }
}
