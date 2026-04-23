package com.acmecorp.catalog;

import com.acmecorp.catalog.service.VirtualThreadProbeService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;

@QuarkusTest
class VirtualThreadProbeServiceTest {

    @Inject
    VirtualThreadProbeService virtualThreadProbeService;

    @Test
    void probeFallsBackWhenVirtualThreadsAreUnavailable() {
        assertFalse(virtualThreadProbeService.isRunningOnVirtualThread());
    }
}
