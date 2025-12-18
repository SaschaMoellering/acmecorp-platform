package com.acmecorp.analytics;

import com.acmecorp.analytics.service.AnalyticsService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE,
    properties = {
        "spring.autoconfigure.exclude=org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration"
    })
class RedisAnalyticsTest extends BaseRedisTest {

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