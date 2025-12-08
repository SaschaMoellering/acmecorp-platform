package com.acmecorp.integration;

import io.restassured.RestAssured;
import io.restassured.common.mapper.TypeRef;
import io.restassured.http.ContentType;
import io.restassured.path.json.JsonPath;
import org.junit.jupiter.api.BeforeAll;

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
