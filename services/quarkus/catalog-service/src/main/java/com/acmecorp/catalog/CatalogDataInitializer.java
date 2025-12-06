package com.acmecorp.catalog;

import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.transaction.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

@ApplicationScoped
public class CatalogDataInitializer {

    private final ProductRepository repository;

    public CatalogDataInitializer(ProductRepository repository) {
        this.repository = repository;
    }

    @Transactional
    void onStart(@Observes StartupEvent event) {
        if (repository.count() > 0) {
            return;
        }
        List<Product> products = List.of(
                build("ACME-STREAM-001", "Acme Streamer Pro", "HD streaming subscription with analytics dashboard", "SAAS", new BigDecimal("49.00")),
                build("ACME-ALERT-001", "Alerting Add-on", "Real-time alerts and incidents with on-call rotation", "ADDON", new BigDecimal("19.00")),
                build("ACME-STORAGE-010", "Secure Storage 1TB", "Encrypted cloud storage for media and backups", "STORAGE", new BigDecimal("29.00")),
                build("ACME-AI-001", "AI Insights", "Predictive recommendations for digital storefronts", "SAAS", new BigDecimal("59.00"))
        );
        products.forEach(product -> product.persist());
    }

    private Product build(String sku, String name, String description, String category, BigDecimal price) {
        Product product = new Product();
        product.sku = sku;
        product.name = name;
        product.description = description;
        product.category = category;
        product.price = price;
        product.currency = "USD";
        product.active = true;
        product.createdAt = Instant.now();
        product.updatedAt = product.createdAt;
        product.id = java.util.UUID.randomUUID();
        return product;
    }
}
