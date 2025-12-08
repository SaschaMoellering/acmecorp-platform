package com.acmecorp.catalog;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.greaterThan;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.notNullValue;
import static org.hamcrest.Matchers.is;

import java.util.UUID;

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
        // seed a product
        var productId = given()
                .contentType("application/json")
                .body("""
                        {
                          "sku": "SKU-1",
                          "name": "Demo Product",
                          "description": "Test item",
                          "price": 9.99,
                          "currency": "USD",
                          "category": "demo",
                          "active": true
                        }
                        """)
                .when().post("/api/catalog")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        given()
                .when().get("/api/catalog")
                .then()
                .statusCode(200)
                .body("size()", greaterThan(0))
                .body("[0].id", notNullValue());
    }

    @Test
    void createAndFetchProductById() {
        var productId = given()
                .contentType("application/json")
                .body("""
                        {
                          "sku": "SKU-2",
                          "name": "Another Product",
                          "description": "Another test item",
                          "price": 19.99,
                          "currency": "USD",
                          "category": "demo",
                          "active": true
                        }
                        """)
                .when().post("/api/catalog")
                .then()
                .statusCode(200)
                .body("sku", equalTo("SKU-2"))
                .extract()
                .path("id");

        given()
                .when().get("/api/catalog/" + productId)
                .then()
                .statusCode(200)
                .body("sku", equalTo("SKU-2"))
                .body("name", equalTo("Another Product"));
    }

    @Test
    void updateProductShouldPersistChanges() {
        var productId = given()
                .contentType("application/json")
                .body("""
                        {
                          "sku": "SKU-3",
                          "name": "Updatable",
                          "description": "Before update",
                          "price": 5.00,
                          "currency": "USD",
                          "category": "updates",
                          "active": true
                        }
                        """)
                .when().post("/api/catalog")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        given()
                .contentType("application/json")
                .body("""
                        {
                          "sku": "SKU-3",
                          "name": "Updated Name",
                          "description": "After update",
                          "price": 6.00,
                          "currency": "USD",
                          "category": "updates",
                          "active": false
                        }
                        """)
                .when().put("/api/catalog/" + productId)
                .then()
                .statusCode(200)
                .body("name", equalTo("Updated Name"))
                .body("active", is(false));
    }

    @Test
    void deleteProductShouldRemoveFromActiveList() {
        var productId = given()
                .contentType("application/json")
                .body("""
                        {
                          "sku": "SKU-DELETE",
                          "name": "ToDelete",
                          "description": "Temporary",
                          "price": 3.00,
                          "currency": "USD",
                          "category": "temp",
                          "active": true
                        }
                        """)
                .when().post("/api/catalog")
                .then()
                .statusCode(200)
                .extract()
                .path("id");

        given()
                .when().delete("/api/catalog/" + productId)
                .then()
                .statusCode(204);

        given()
                .when().get("/api/catalog?search=ToDelete")
                .then()
                .statusCode(200)
                .body("findAll { it.id == '%s' }.size()".formatted(productId), equalTo(0));
    }

    @Test
    void getNonExistingProductShouldReturn404() {
        given()
                .when().get("/api/catalog/" + UUID.randomUUID())
                .then()
                .statusCode(404);
    }
}
