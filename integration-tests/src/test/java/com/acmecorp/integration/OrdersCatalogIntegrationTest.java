package com.acmecorp.integration;

import io.restassured.common.mapper.TypeRef;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.assertj.core.api.Assertions.assertThat;

class OrdersCatalogIntegrationTest extends AbstractIntegrationTest {

    @Test
    void catalogShouldListItemsAndOrdersCanBeCreatedAndFetched() {
        List<Map<String, Object>> catalog = fetchCatalogItems();
        assertThat(catalog).isNotEmpty();

        Map<String, Object> first = catalog.get(0);
        UUID productId = UUID.fromString(first.get("id").toString());

        var createResponse = createOrder("integration@example.com", productId, 1);
        long orderId = createResponse.getLong("id");
        assertThat(orderId).isPositive();
        assertThat(createResponse.getString("items[0].productId")).isEqualTo(productId.toString());

        var orders = listOrders();
        assertThat(orders)
                .anySatisfy(order -> assertThat(((Number) order.get("id")).longValue()).isEqualTo(orderId));

        given()
                .when()
                .get(gatewayApiBase + "/orders/{id}", orderId)
                .then()
                .statusCode(200)
                .body("order.id", org.hamcrest.Matchers.equalTo((int) orderId))
                .body("order.items[0].productId", org.hamcrest.Matchers.equalTo(productId.toString()));
    }

    @Test
    void creatingOrderWithEmptyItemsShouldFailValidation() {
        String body = "{\n" +
                "  \"customerEmail\": \"invalid@example.com\",\n" +
                "  \"items\": []\n" +
                "}";

        given()
                .contentType(ContentType.JSON)
                .body(body)
                .when()
                .post(gatewayApiBase + "/orders")
                .then()
                .statusCode(400)
                .body("error", org.hamcrest.Matchers.equalTo("VALIDATION_ERROR"))
                .body("fields.items", org.hamcrest.Matchers.notNullValue());
    }

    @Test
    void fetchingMissingOrderShouldReturnNotFound() {
        long missingId = 999999L;

        given()
                .when()
                .get(ordersBase + "/api/orders/{id}", missingId)
                .then()
                .statusCode(404)
                .body("error", org.hamcrest.Matchers.equalTo("NOT_FOUND"))
                .body("status", org.hamcrest.Matchers.equalTo(404));
    }

    @Test
    void createOrderIsIdempotentWithSameKey() {
        List<Map<String, Object>> catalog = fetchCatalogItems();
        assertThat(catalog).isNotEmpty();

        Map<String, Object> first = catalog.get(0);
        UUID productId = UUID.fromString(first.get("id").toString());

        String body = String.format(
                "{\n" +
                        "  \"customerEmail\": \"idempotent@example.com\",\n" +
                        "  \"items\": [\n" +
                        "    {\"productId\":\"%s\",\"quantity\":1}\n" +
                        "  ]\n" +
                        "}",
                productId
        );

        String key = "idem-" + java.util.UUID.randomUUID();

        long firstId = given()
                .contentType(ContentType.JSON)
                .header("Idempotency-Key", key)
                .body(body)
                .when()
                .post(gatewayApiBase + "/orders")
                .then()
                .statusCode(200)
                .extract()
                .jsonPath()
                .getLong("id");

        long secondId = given()
                .contentType(ContentType.JSON)
                .header("Idempotency-Key", key)
                .body(body)
                .when()
                .post(gatewayApiBase + "/orders")
                .then()
                .statusCode(200)
                .extract()
                .jsonPath()
                .getLong("id");

        assertThat(secondId).isEqualTo(firstId);

        String differentBody = String.format(
                "{\n" +
                        "  \"customerEmail\": \"idempotent@example.com\",\n" +
                        "  \"items\": [\n" +
                        "    {\"productId\":\"%s\",\"quantity\":2}\n" +
                        "  ]\n" +
                        "}",
                productId
        );

        given()
                .contentType(ContentType.JSON)
                .header("Idempotency-Key", key)
                .body(differentBody)
                .when()
                .post(gatewayApiBase + "/orders")
                .then()
                .statusCode(409)
                .body("error", org.hamcrest.Matchers.equalTo("CONFLICT"));
    }

    @Test
    void orderHistoryTracksStatusChanges() {
        List<Map<String, Object>> catalog = fetchCatalogItems();
        assertThat(catalog).isNotEmpty();

        Map<String, Object> first = catalog.get(0);
        UUID productId = UUID.fromString(first.get("id").toString());

        var createResponse = createOrder("timeline@example.com", productId, 1);
        long orderId = createResponse.getLong("id");

        confirmOrder(orderId);

        List<Map<String, Object>> history = given()
                .when()
                .get(gatewayApiBase + "/orders/{id}/history", orderId)
                .then()
                .statusCode(200)
                .extract()
                .as(new TypeRef<List<Map<String, Object>>>() {});

        assertThat(history).hasSizeGreaterThanOrEqualTo(2);
        Map<String, Object> created = history.get(0);
        Map<String, Object> confirmed = history.get(1);
        assertThat(created.get("oldStatus")).isNull();
        assertThat(created.get("newStatus")).isEqualTo("NEW");
        assertThat(created.get("reason")).isEqualTo("created");
        assertThat(confirmed.get("oldStatus")).isEqualTo("NEW");
        assertThat(confirmed.get("newStatus")).isEqualTo("CONFIRMED");
        assertThat(confirmed.get("reason")).isEqualTo("confirmed");
    }
}
