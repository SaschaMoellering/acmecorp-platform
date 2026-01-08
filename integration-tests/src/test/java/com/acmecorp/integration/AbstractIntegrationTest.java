package com.acmecorp.integration;

import io.restassured.RestAssured;
import io.restassured.common.mapper.TypeRef;
import io.restassured.http.ContentType;
import io.restassured.path.json.JsonPath;
import org.awaitility.core.ConditionTimeoutException;
import org.junit.jupiter.api.BeforeAll;

import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.assertj.core.api.Assertions.assertThat;

public abstract class AbstractIntegrationTest {

    protected static String gatewayBase;
    protected static String ordersBase;
    protected static String catalogBase;
    protected static String billingBase;
    protected static String analyticsBase;

    @BeforeAll
    static void setupBase() {
        gatewayBase = System.getenv().getOrDefault("ACMECORP_BASE_URL", "http://localhost:8080");
        ordersBase = gatewayBase.replace("8080", "8081");
        catalogBase = gatewayBase.replace("8080", "8085");
        billingBase = gatewayBase.replace("8080", "8082");
        analyticsBase = gatewayBase.replace("8080", "8084");
        RestAssured.baseURI = gatewayBase;

        waitForServiceHealth("gateway-service", gatewayBase + "/actuator/health");
        waitForServiceHealth("orders-service", ordersBase + "/actuator/health");
        waitForServiceHealth("billing-service", billingBase + "/actuator/health");
        waitForServiceHealth("notification-service", gatewayBase.replace("8080", "8083") + "/actuator/health");
        waitForServiceHealth("analytics-service", analyticsBase + "/actuator/health");
        waitForServiceHealth("catalog-service", catalogBase + "/actuator/health");
        waitForGatewaySystemStatus();
    }

    private static void waitForServiceHealth(String serviceName, String url) {
        try {
            org.awaitility.Awaitility.await()
                    .atMost(Duration.ofSeconds(120))
                    .pollInterval(Duration.ofSeconds(2))
                    .untilAsserted(() -> {
                        Map<String, Object> health = given()
                                .when()
                                .get(url)
                                .then()
                                .statusCode(200)
                                .extract()
                                .as(new TypeRef<Map<String, Object>>() {});
                        assertThat(health.get("status"))
                                .withFailMessage("Health status for %s at %s was not UP", serviceName, url)
                                .isEqualTo("UP");
                    });
        } catch (ConditionTimeoutException ex) {
            throw new IllegalStateException("Timed out waiting for " + serviceName + " at " + url, ex);
        }
    }

    private static void waitForGatewaySystemStatus() {
        String url = gatewayBase + "/api/gateway/system/status";
        try {
            org.awaitility.Awaitility.await()
                    .atMost(Duration.ofSeconds(120))
                    .pollInterval(Duration.ofSeconds(2))
                    .untilAsserted(() -> given()
                            .when()
                            .get(url)
                            .then()
                            .statusCode(200));
        } catch (ConditionTimeoutException ex) {
            throw new IllegalStateException("Timed out waiting for gateway system status at " + url, ex);
        }
    }

    protected List<Map<String, Object>> fetchCatalogItems() {
        return given()
                .when()
                .get(catalogBase + "/api/catalog")
                .then()
                .statusCode(200)
                .extract()
                .as(new TypeRef<List<Map<String, Object>>>() {});
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
                .post(ordersBase + "/api/orders")
                .then()
                .statusCode(200)
                .extract()
                .jsonPath();
    }

    protected JsonPath confirmOrder(long orderId) {
        return given()
                .when()
                .post(ordersBase + "/api/orders/{id}/confirm", orderId)
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
                .get(ordersBase + "/api/orders")
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
                .get(gatewayBase + "/api/gateway/analytics/counters")
                .then()
                .statusCode(200)
                .extract()
                .as(new TypeRef<Map<String, Object>>() {});
    }

    protected List<Map<String, Object>> fetchSystemStatus() {
        return given()
                .when()
                .get(gatewayBase + "/api/gateway/system/status")
                .then()
                .statusCode(200)
                .extract()
                .as(new TypeRef<List<Map<String, Object>>>() {});
    }

    protected List<Map<String, Object>> findInvoicesForOrder(long orderId) {
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> invoices = (List<Map<String, Object>>) (List<?>) given()
                .when()
                .get(billingBase + "/api/billing/invoices?orderId={orderId}", orderId)
                .then()
                .statusCode(200)
                .extract()
                .jsonPath()
                .getList("content", Map.class);
        return invoices;
    }
}
