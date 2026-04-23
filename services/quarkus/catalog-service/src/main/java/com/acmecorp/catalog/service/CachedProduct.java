package com.acmecorp.catalog.service;

import com.acmecorp.catalog.Product;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record CachedProduct(
        UUID id,
        String sku,
        String name,
        String description,
        BigDecimal price,
        String currency,
        String category,
        boolean active,
        Instant createdAt,
        Instant updatedAt
) {

    static CachedProduct from(Product product) {
        return new CachedProduct(
                product.id,
                product.sku,
                product.name,
                product.description,
                product.price,
                product.currency,
                product.category,
                product.active,
                product.createdAt,
                product.updatedAt
        );
    }

    Product toProduct() {
        Product product = new Product();
        product.id = id;
        product.sku = sku;
        product.name = name;
        product.description = description;
        product.price = price;
        product.currency = currency;
        product.category = category;
        product.active = active;
        product.createdAt = createdAt;
        product.updatedAt = updatedAt;
        return product;
    }
}
