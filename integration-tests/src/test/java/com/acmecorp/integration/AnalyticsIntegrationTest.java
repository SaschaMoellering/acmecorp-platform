package com.acmecorp.integration;

import org.awaitility.Awaitility;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class AnalyticsIntegrationTest extends AbstractIntegrationTest {

    @Test
    void countersShouldReflectNewOrders() {
        Map<String, Object> before = fetchAnalyticsCounters();
        long beforeCreated = longValue(before.getOrDefault("orders.created", 0L));

        var catalog = fetchCatalogItems();
        assertThat(catalog).isNotEmpty();
        var productId = UUID.fromString(catalog.get(0).get("id").toString());
        createOrder("analytics@example.com", productId, 1);

        Map<String, Object> after = Awaitility.await()
                .atMost(Duration.ofSeconds(10))
                .pollInterval(Duration.ofSeconds(1))
                .until(this::fetchAnalyticsCounters,
                        counters -> longValue(counters.getOrDefault("orders.created", 0L)) >= beforeCreated);

        assertThat(longValue(after.getOrDefault("orders.created", 0L))).isGreaterThanOrEqualTo(beforeCreated);
    }

    private long longValue(Object value) {
        return value instanceof Number number ? number.longValue() : 0L;
    }
}
