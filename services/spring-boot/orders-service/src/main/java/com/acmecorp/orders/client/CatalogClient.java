package com.acmecorp.orders.client;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;

@Component
public class CatalogClient {

    private final RestClient restClient;

    public CatalogClient(RestClient.Builder builder,
                         @Value("${acmecorp.services.catalog}") String catalogBaseUrl) {
        this.restClient = builder.baseUrl(catalogBaseUrl).build();
    }

    public CatalogProduct fetchProduct(String productId) {
        try {
            return restClient.get()
                    .uri("/api/catalog/{id}", productId)
                    .retrieve()
                    .body(CatalogProduct.class);
        } catch (Exception ex) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Catalog product not found: " + productId);
        }
    }

    public record CatalogProduct(String id,
                                 String sku,
                                 String name,
                                 String description,
                                 BigDecimal price,
                                 String currency,
                                 String category,
                                 boolean active) {
    }
}
