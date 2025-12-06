package com.acmecorp.catalog;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.greaterThan;

@QuarkusTest
class CatalogResourceTest {

    @Test
    void statusEndpointShouldReturnOk() {
        given()
                .when().get("/api/catalog/status")
                .then()
                .statusCode(200)
                .body(containsString("catalog-service"));
    }

    @Test
    void listShouldReturnProducts() {
        given()
                .when().get("/api/catalog")
                .then()
                .statusCode(200)
                .body("size()", greaterThan(0));
    }
}
