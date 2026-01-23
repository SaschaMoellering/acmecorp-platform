package com.acmecorp.integration;

import io.restassured.RestAssured;
import io.restassured.common.mapper.TypeRef;
import io.restassured.http.ContentType;
import io.restassured.path.json.JsonPath;
import org.awaitility.core.ConditionTimeoutException;
import org.junit.jupiter.api.BeforeAll;

import java.net.URI;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;

import static io.restassured.RestAssured.given;

public abstract class AbstractIntegrationTest {

    protected static String gatewayBase;
    protected static String gatewayApiBase;
    private static final Set<String> EXPECTED_SERVICES = Set.of(
            "orders",
            "billing",
            "notification",
            "analytics",
            "catalog"
    );

    @BeforeAll
    static void setupBase() {
        gatewayBase = resolveBaseUrl();
        gatewayApiBase = gatewayBase + "/api/gateway";
        RestAssured.baseURI = gatewayBase;

        waitForServiceHealth("gateway-service", gatewayBase + "/actuator/health");
        waitForGatewaySystemStatus();
    }

    private static void waitForServiceHealth(String serviceName, String url) {
        List<String> candidates = healthCandidates(url);
        AtomicReference<AttemptResult> lastAttempt = new AtomicReference<>();
        try {
            org.awaitility.Awaitility.await()
                    .atMost(Duration.ofSeconds(120))
                    .pollInterval(Duration.ofSeconds(2))
                    .until(() -> isAnyHealthUp(candidates, lastAttempt));
        } catch (ConditionTimeoutException ex) {
            AttemptResult attempt = lastAttempt.get();
            String lastInfo = attempt == null
                    ? "no responses captured"
                    : "last response from " + attempt.url + " status=" + attempt.statusCode
                    + " body=" + attempt.bodySnippet;
            throw new IllegalStateException(
                    "Timed out waiting for " + serviceName + " at " + url
                            + "; tried " + candidates
                            + "; " + lastInfo,
                    ex);
        }
    }

    private static List<String> healthCandidates(String healthUrl) {
        Set<String> candidates = new LinkedHashSet<>();
        if (healthUrl.endsWith("/actuator/health")) {
            candidates.add(healthUrl.replace("/actuator/health", "/actuator/health/readiness"));
        }
        candidates.add(healthUrl);
        String base = baseUrl(healthUrl);
        candidates.add(base + "/q/health/ready");
        candidates.add(base + "/q/health");
        return new ArrayList<>(candidates);
    }

    private static String baseUrl(String url) {
        URI uri = URI.create(url);
        return uri.getScheme() + "://" + uri.getAuthority();
    }

    private static String resolveBaseUrl() {
        String base = System.getProperty("acmecorp.baseUrl");
        if (base == null || base.isBlank()) {
            base = System.getenv("ACMECORP_BASE_URL");
        }
        if (base == null || base.isBlank()) {
            base = "http://localhost:8080";
        }
        return base.endsWith("/") ? base.substring(0, base.length() - 1) : base;
    }

    private static boolean isAnyHealthUp(List<String> urls, AtomicReference<AttemptResult> lastAttempt) {
        for (String url : urls) {
            io.restassured.response.Response response = given()
                    .when()
                    .get(url);
            int statusCode = response.getStatusCode();
            String body = response.getBody().asString();
            lastAttempt.set(new AttemptResult(url, statusCode, snippet(body)));
            if (statusCode != 200) {
                continue;
            }
            try {
                Map<String, Object> health = response.as(new TypeRef<Map<String, Object>>() {});
                if ("UP".equals(health.get("status"))) {
                    return true;
                }
            } catch (Exception ignored) {
                // Try next candidate if JSON parsing fails.
            }
        }
        return false;
    }

    private static String snippet(String body) {
        if (body == null) {
            return "<empty>";
        }
        String trimmed = body.trim();
        if (trimmed.isEmpty()) {
            return "<empty>";
        }
        int max = 200;
        return trimmed.length() <= max ? trimmed : trimmed.substring(0, max) + "...";
    }

    private static final class AttemptResult {
        private final String url;
        private final int statusCode;
        private final String bodySnippet;

        private AttemptResult(String url, int statusCode, String bodySnippet) {
            this.url = url;
            this.statusCode = statusCode;
            this.bodySnippet = bodySnippet;
        }
    }

    private static void waitForGatewaySystemStatus() {
        String url = gatewayApiBase + "/system/status";
        try {
            org.awaitility.Awaitility.await()
                    .atMost(Duration.ofSeconds(120))
                    .pollInterval(Duration.ofSeconds(2))
                    .until(() -> {
                        List<Map<String, Object>> statuses = given()
                                .when()
                                .get(url)
                                .then()
                                .statusCode(200)
                                .extract()
                                .as(new TypeRef<List<Map<String, Object>>>() {});

                        if (statuses == null || statuses.isEmpty()) {
                            return false;
                        }

                        Set<String> seen = new LinkedHashSet<>();
                        for (Map<String, Object> status : statuses) {
                            Object service = status.get("service");
                            Object health = status.get("status");
                            if (service != null) {
                                seen.add(service.toString());
                            }
                            if (health == null || !"UP".equalsIgnoreCase(health.toString())) {
                                return false;
                            }
                        }
                        return seen.containsAll(EXPECTED_SERVICES);
                    });
        } catch (ConditionTimeoutException ex) {
            throw new IllegalStateException("Timed out waiting for gateway system status at " + url, ex);
        }
    }

    protected List<Map<String, Object>> fetchCatalogItems() {
        return given()
                .when()
                .get(gatewayApiBase + "/catalog")
                .then()
                .statusCode(200)
                .extract()
                .as(new TypeRef<List<Map<String, Object>>>() {});
    }

    protected Map<String, Object> fetchGatewayHealth() {
        return given()
                .when()
                .get(gatewayBase + "/actuator/health")
                .then()
                .statusCode(200)
                .extract()
                .as(new TypeRef<Map<String, Object>>() {});
    }

    protected JsonPath createOrder(String customerEmail, UUID productId, int quantity) {
        String body = """
                {
                  "customerEmail": "%s",
                  "items": [
                    {"productId":"%s","quantity":%d}
                  ]
                }
                """.formatted(customerEmail, productId, quantity);

        return given()
                .contentType(ContentType.JSON)
                .body(body)
                .when()
                .post(gatewayApiBase + "/orders")
                .then()
                .statusCode(200)
                .extract()
                .jsonPath();
    }

    protected JsonPath confirmOrder(long orderId) {
        return given()
                .when()
                .post(gatewayApiBase + "/orders/{id}/confirm", orderId)
                .then()
                .statusCode(200)
                .extract()
                .jsonPath();
    }

    protected List<Map<String, Object>> listOrders() {
        // RestAssured returns raw maps; cast to a typed list for convenience.
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> orders = (List<Map<String, Object>>) (List<?>) given()
                .when()
                .get(gatewayApiBase + "/orders")
                .then()
                .statusCode(200)
                .extract()
                .jsonPath()
                .getList("content", Map.class);
        return orders;
    }

    protected Map<String, Object> fetchAnalyticsCounters() {
        return given()
                .when()
                .get(gatewayApiBase + "/analytics/counters")
                .then()
                .statusCode(200)
                .extract()
                .as(new TypeRef<Map<String, Object>>() {});
    }

    protected List<Map<String, Object>> fetchSystemStatus() {
        return given()
                .when()
                .get(gatewayApiBase + "/system/status")
                .then()
                .statusCode(200)
                .extract()
                .as(new TypeRef<List<Map<String, Object>>>() {});
    }

    protected List<Map<String, Object>> findInvoicesForOrder(long orderId) {
        @SuppressWarnings("unchecked")
        Map<String, Object> orderDetails = (Map<String, Object>) (Map<?, ?>) given()
                .when()
                .get(gatewayApiBase + "/orders/{id}", orderId)
                .then()
                .statusCode(200)
                .extract()
                .jsonPath()
                .getMap("$");

        if (orderDetails == null) {
            return List.of();
        }
        Object invoiceData = orderDetails.get("invoices");
        if (invoiceData instanceof List<?> list) {
            return (List<Map<String, Object>>) (List<?>) list;
        }
        return List.of();
    }
}
