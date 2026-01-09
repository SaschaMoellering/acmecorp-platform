package com.acmecorp.integration;

import io.restassured.RestAssured;
import io.restassured.common.mapper.TypeRef;
import io.restassured.http.ContentType;
import io.restassured.path.json.JsonPath;
import org.awaitility.Awaitility;
import org.junit.jupiter.api.BeforeAll;

import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static io.restassured.RestAssured.given;

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

        waitForHealth("gateway", gatewayBase + "/actuator/health", Duration.ofSeconds(30));
        waitForHealth("orders", ordersBase + "/actuator/health", Duration.ofSeconds(120));
        waitForHealth("billing", billingBase + "/actuator/health", Duration.ofSeconds(120));
        waitForHealth("notification", gatewayBase.replace("8080", "8083") + "/actuator/health", Duration.ofSeconds(120));
        waitForHealth("catalog", catalogBase + "/q/health", Duration.ofSeconds(120));
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
        String body = String.format(
                "{\n" +
                "  \"customerEmail\": \"%s\",\n" +
                "  \"items\": [\n" +
                "    {\"productId\":\"%s\",\"quantity\":%d}\n" +
                "  ]\n" +
                "}",
                customerEmail,
                productId,
                quantity
        );

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
        return Awaitility.await()
                .atMost(Duration.ofSeconds(30))
                .pollInterval(Duration.ofSeconds(1))
                .ignoreExceptions()
                .until(this::fetchAnalyticsCountersOnce, counters -> counters != null);
    }

    private Map<String, Object> fetchAnalyticsCountersOnce() {
        return given()
                .when()
                .get(gatewayBase + "/api/gateway/analytics/counters")
                .then()
                .statusCode(200)
                .extract()
                .as(new TypeRef<Map<String, Object>>() {});
    }

    private static void waitForHealth(String service, String healthUrl, Duration timeout) {
        long deadline = System.currentTimeMillis() + timeout.toMillis();
        String lastBody = null;
        int lastStatus = -1;
        Exception lastError = null;

        while (System.currentTimeMillis() < deadline) {
            try {
                var response = given()
                        .when()
                        .get(healthUrl);
                lastStatus = response.statusCode();
                lastBody = response.getBody().asString();
                if (lastStatus == 200) {
                    return;
                }
            } catch (Exception ex) {
                lastError = ex;
            }
            sleep(Duration.ofSeconds(2));
        }

        StringBuilder message = new StringBuilder()
                .append("Timed out waiting for ")
                .append(service)
                .append(" health at ")
                .append(healthUrl)
                .append(".");

        if (lastError != null) {
            message.append(" Last error: ").append(lastError.getMessage()).append(".");
        } else {
            message.append(" Last status=").append(lastStatus).append(" body=");
            if (lastBody == null) {
                message.append("<empty>.");
            } else {
                message.append("\"").append(trimBody(lastBody)).append("\".");
            }
        }

        message.append(" Ensure the Docker Compose stack is running (infra/local).");
        throw new IllegalStateException(message.toString());
    }

    private static String trimBody(String body) {
        String trimmed = body.replaceAll("\\s+", " ").trim();
        return trimmed.length() > 200 ? trimmed.substring(0, 200) + "..." : trimmed;
    }

    private static void sleep(Duration duration) {
        try {
            Thread.sleep(duration.toMillis());
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Interrupted while waiting for service health.", ex);
        }
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
