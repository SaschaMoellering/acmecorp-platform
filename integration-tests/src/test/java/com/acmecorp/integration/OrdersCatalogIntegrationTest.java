package com.acmecorp.integration;

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
        String body = """
                {
                  "customerEmail": "invalid@example.com",
                  "items": []
                }
                """;

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
}
