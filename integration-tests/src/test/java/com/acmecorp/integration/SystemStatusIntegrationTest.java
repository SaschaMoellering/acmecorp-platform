package com.acmecorp.integration;

import org.junit.jupiter.api.Test;

import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;

class SystemStatusIntegrationTest extends AbstractIntegrationTest {

    @Test
    void gatewayShouldReportHealthyServicesAndCounters() {
        var statuses = fetchSystemStatus();

        // Gateway aggregates downstream services; it should not list itself as a service.
        Set<String> expectedServices = Set.of(
                "orders",
                "billing",
                "notification",
                "analytics",
                "catalog"
        );

        assertThat(statuses).isNotEmpty();

        Map<String, Map<String, Object>> statusByService = statuses.stream()
                .collect(Collectors.toMap(
                        entry -> (String) entry.get("service"),
                        entry -> entry
                ));

        assertThat(statusByService.keySet())
                .containsAll(expectedServices)
                .doesNotContain("gateway-service");

        expectedServices.forEach(service -> assertThatServiceIsUp(statusByService.get(service)));
        assertThatHealthDetails(statusByService.get("analytics"));

        Map<String, Object> counters = fetchAnalyticsCounters();
        assertThat(counters).isNotEmpty();
        counters.values().forEach(value -> assertThat(value).isInstanceOf(Number.class));
    }

    private void assertThatServiceIsUp(Map<String, Object> entry) {
        assertThat(entry).isNotNull();
        assertThat(entry.get("status")).isEqualTo("UP");
    }

    private void assertThatHealthDetails(Map<String, Object> entry) {
        if (entry == null) {
            return;
        }

        Object details = entry.get("details");
        if (!(details instanceof Map<?, ?> detailsMap)) {
            return;
        }

        Object groups = detailsMap.get("groups");
        if (groups instanceof Iterable<?> iterable) {
            assertThat(iterable)
                    .map(Object::toString)
                    .contains("liveness", "readiness");
        }

        Object components = detailsMap.get("components");
        if (components instanceof Map<?, ?> componentsMap) {
            assertComponentUp(componentsMap, "db");
            assertComponentUp(componentsMap, "redis");
        }
    }

    private void assertComponentUp(Map<?, ?> componentsMap, String key) {
        Object component = componentsMap.get(key);
        if (!(component instanceof Map<?, ?> componentMap)) {
            return;
        }
        assertThat(componentMap.get("status")).isEqualTo("UP");
    }
}
