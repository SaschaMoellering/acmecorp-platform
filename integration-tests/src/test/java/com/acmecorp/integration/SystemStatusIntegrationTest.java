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

        assertThat(statuses)
                .isNotEmpty()
                .extracting(status -> status.get("service"))
                .containsAll(expectedServices);

        for (String service : expectedServices) {
            assertThat(statuses)
                    .anySatisfy(entry -> {
                        if (service.equals(entry.get("service"))) {
                            assertThat(entry.get("status")).isEqualTo("UP");
                        }
                    });
        }

        Map<String, Object> counters = fetchAnalyticsCounters();
        assertThat(counters).isNotEmpty();
        counters.values().forEach(value -> assertThat(value).isInstanceOf(Number.class));
    }
}
