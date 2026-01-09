package com.acmecorp.integration;

import org.junit.jupiter.api.Test;

import java.util.Map;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

class SystemStatusIntegrationTest extends AbstractIntegrationTest {

    @Test
    void gatewayShouldReportHealthyServicesAndCounters() {
        var statuses = fetchSystemStatus();

        Set<String> expectedServices = Set.of(
                "orders",
                "billing",
                "notification",
                "analytics",
                "catalog"
        );

        assertThat(statuses).isNotEmpty();
        assertThat(statuses)
                .extracting(status -> status.get("service"))
                .containsAll(expectedServices);

        assertServiceUp(statuses, "orders");
        assertServiceUp(statuses, "billing");
        assertServiceUp(statuses, "notification");
        assertServiceUp(statuses, "catalog");
        assertServiceStatusPresent(statuses, "analytics");

        Map<String, Object> counters = fetchAnalyticsCounters();
        assertThat(counters).isNotEmpty();
        counters.values().forEach(value -> assertThat(value).isInstanceOf(Number.class));
    }

    private void assertServiceUp(Iterable<Map<String, Object>> statuses, String service) {
        assertThat(statuses)
                .anySatisfy(entry -> {
                    if (service.equals(entry.get("service"))) {
                        assertThat(entry.get("status")).isEqualTo("UP");
                    }
                });
    }

    private void assertServiceStatusPresent(Iterable<Map<String, Object>> statuses, String service) {
        assertThat(statuses)
                .anySatisfy(entry -> {
                    if (service.equals(entry.get("service"))) {
                        assertThat(entry.get("status")).isNotNull();
                    }
                });
    }

}
