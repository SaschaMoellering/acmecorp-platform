package com.acmecorp.analytics;

import com.acmecorp.analytics.service.AnalyticsService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@Testcontainers
class RedisAnalyticsTest {

    @Container
    static GenericContainer<?> redis = new GenericContainer<>(DockerImageName.parse("redis:7"))
        .withExposedPorts(6379);

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.data.redis.host", redis::getHost);
        registry.add("spring.data.redis.port", redis::getFirstMappedPort);
    }

    @Autowired
    private AnalyticsService analyticsService;

    @Test
    void shouldTrackEvents() {
        String event = "orders.created";
        
        long initialCount = analyticsService.getCounter(event);
        analyticsService.track(event);
        long newCount = analyticsService.getCounter(event);
        
        assertThat(newCount).isEqualTo(initialCount + 1);
    }

    @Test
    void shouldReturnAllCounters() {
        analyticsService.track("orders.created");
        analyticsService.track("billing.invoice.paid");
        
        Map<String, Long> counters = analyticsService.allCounters();
        
        assertThat(counters).containsKeys("orders.created", "billing.invoice.paid");
        assertThat(counters.get("orders.created")).isGreaterThan(0);
        assertThat(counters.get("billing.invoice.paid")).isGreaterThan(0);
    }
}