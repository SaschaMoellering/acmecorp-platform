package com.acmecorp.orders.client;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;

@Component
public class CatalogClient {

    private final RestTemplate restTemplate;

    public CatalogClient(RestTemplateBuilder builder,
                         @Value("${acmecorp.services.catalog}") String catalogBaseUrl) {
        this.restTemplate = builder.rootUri(catalogBaseUrl).build();
    }

    public CatalogProduct fetchProduct(String productId) {
        try {
            return restTemplate.getForObject("/api/catalog/{id}", CatalogProduct.class, productId);
        } catch (Exception ex) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Catalog product not found: " + productId);
        }
    }

    public static class CatalogProduct {
        private String id;
        private String sku;
        private String name;
        private String description;
        private BigDecimal price;
        private String currency;
        private String category;
        private boolean active;

        public CatalogProduct() {
        }

        public CatalogProduct(String id,
                              String sku,
                              String name,
                              String description,
                              BigDecimal price,
                              String currency,
                              String category,
                              boolean active) {
            this.id = id;
            this.sku = sku;
            this.name = name;
            this.description = description;
            this.price = price;
            this.currency = currency;
            this.category = category;
            this.active = active;
        }

        public String getId() {
            return id;
        }

        public String getSku() {
            return sku;
        }

        public String getName() {
            return name;
        }

        public String getDescription() {
            return description;
        }

        public BigDecimal getPrice() {
            return price;
        }

        public String getCurrency() {
            return currency;
        }

        public String getCategory() {
            return category;
        }

        public boolean isActive() {
            return active;
        }
    }
}
