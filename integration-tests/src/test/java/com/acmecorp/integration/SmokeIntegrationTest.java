package com.acmecorp.integration;

import io.restassured.common.mapper.TypeRef;
import io.restassured.http.ContentType;
import io.restassured.response.Response;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.assertj.core.api.Assertions.assertThat;

class SmokeIntegrationTest extends AbstractIntegrationTest {

    @Test
    void systemStatusIsHealthy() {
        List<Map<String, Object>> statuses = fetchSystemStatus(gatewayApiBase + "/system/status");
        assertThat(statuses).isNotNull().isNotEmpty();

        Map<String, String> statusByService = new java.util.HashMap<>();
        for (Map<String, Object> entry : statuses) {
            Object service = entry.get("service");
            Object status = entry.get("status");
            if (service != null && status != null) {
                statusByService.put(service.toString(), status.toString());
            }
        }

        assertThat(statusByService).containsKeys("orders", "billing", "notification", "analytics", "catalog");
        statusByService.forEach((svc, state) -> assertThat(isHealthyState(state))
                .as("service %s should be UP or READY but was %s", svc, state)
                .isTrue());
    }

    @Test
    void contractSmokeFlowWorks() {
        List<Map<String, Object>> catalog = fetchCatalogItems();
        assertThat(catalog).isNotEmpty();

        Map<String, Object> first = catalog.get(0);
        UUID productId = UUID.fromString(first.get("id").toString());

        String body = String.format(
                "{\"customerEmail\":\"smoke@acme.test\",\"items\":[{\"productId\":\"%s\",\"quantity\":1}]}",
                productId
        );

        Response createResponse = given()
                .contentType(ContentType.JSON)
                .body(body)
                .when()
                .post(gatewayApiBase + "/orders");
        assertStatus(createResponse, 200, "POST " + gatewayApiBase + "/orders");

        long orderId = createResponse.jsonPath().getLong("id");

        Response fetchResponse = given()
                .when()
                .get(gatewayApiBase + "/orders/{id}", orderId);
        assertStatus(fetchResponse, 200, "GET " + gatewayApiBase + "/orders/{id}");

        Response confirmResponse = given()
                .when()
                .post(gatewayApiBase + "/orders/{id}/confirm", orderId);
        assertStatus(confirmResponse, 200, "POST " + gatewayApiBase + "/orders/{id}/confirm");

        Response detailsResponse = given()
                .when()
                .get(gatewayApiBase + "/orders/{id}", orderId);
        assertStatus(detailsResponse, 200, "GET " + gatewayApiBase + "/orders/{id}");

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> invoices = (List<Map<String, Object>>) (List<?>)
                detailsResponse.jsonPath().getList("invoices", Map.class);
        assertThat(invoices)
                .as("expected billing invoice after confirm")
                .isNotNull()
                .isNotEmpty();

        Response countersResponse = given()
                .when()
                .get(gatewayApiBase + "/analytics/counters");
        assertStatus(countersResponse, 200, "GET " + gatewayApiBase + "/analytics/counters");
    }
}
