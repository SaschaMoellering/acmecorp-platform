package com.acmecorp.catalog;

import com.acmecorp.catalog.service.CatalogCacheMetrics;
import com.acmecorp.catalog.service.CatalogService;
import io.micrometer.core.instrument.MeterRegistry;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.TestProfile;
import jakarta.inject.Inject;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;

@QuarkusTest
@TestProfile(RedisUnavailableProfile.class)
class CatalogCacheFailureTest {

    private static final UUID PRODUCT_ID = UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");

    @Inject
    CatalogService catalogService;

    @Inject
    ProductRepository productRepository;

    @Inject
    MeterRegistry meterRegistry;

    @BeforeEach
    void setUp() {
        QuarkusTransaction.requiringNew().run(() -> {
            productRepository.deleteAll();
            Product product = new Product();
            product.id = PRODUCT_ID;
            product.sku = "FAIL-SKU-1";
            product.name = "Failure Test Product";
            product.description = "Product used for cache failure fallback tests";
            product.price = new BigDecimal("9.00");
            product.currency = "USD";
            product.category = "failure-tests";
            product.active = true;
            product.createdAt = Instant.now();
            product.updatedAt = product.createdAt;
            product.persist();
        });
    }

    @Test
    void unavailableRedisShouldStillServeDatasourceResultAndIncrementErrorMetric() {
        double readsBefore = datasourceCounterValue();
        double missesBefore = cacheCounterValue("acmecorp.catalog.cache.misses");
        double errorsBefore = cacheCounterValue("acmecorp.catalog.cache.errors");

        Product product = catalogService.getProductById(PRODUCT_ID);

        assertEquals("FAIL-SKU-1", product.sku);
        assertEquals(readsBefore + 1.0d, datasourceCounterValue());
        assertEquals(missesBefore + 1.0d, cacheCounterValue("acmecorp.catalog.cache.misses"));
        assertEquals(errorsBefore + 2.0d, cacheCounterValue("acmecorp.catalog.cache.errors"));
    }

    @Test
    void updateShouldCommitEvenWhenPostCommitInvalidationFails() {
        double errorsBefore = cacheCounterValue("acmecorp.catalog.cache.errors");

        Product updated = catalogService.updateProduct(PRODUCT_ID, new ProductRequest(
                "FAIL-SKU-1",
                "Updated Despite Redis Failure",
                "Product used for cache failure fallback tests",
                new BigDecimal("11.00"),
                "USD",
                "failure-tests",
                true
        ));

        assertEquals("Updated Despite Redis Failure", updated.name);
        assertEquals("Updated Despite Redis Failure", productRepository.findByIdOptional(PRODUCT_ID).orElseThrow().name);
        assertEquals(errorsBefore + 1.0d, cacheCounterValue("acmecorp.catalog.cache.errors"));
    }

    private double cacheCounterValue(String name) {
        io.micrometer.core.instrument.Counter counter = meterRegistry.find(name)
                .tags("cache", CatalogCacheMetrics.CACHE_NAME, "operation", CatalogCacheMetrics.GET_PRODUCT_BY_ID)
                .counter();
        return counter == null ? 0.0d : counter.count();
    }

    private double datasourceCounterValue() {
        io.micrometer.core.instrument.Counter counter = meterRegistry.find("acmecorp.catalog.datasource.reads")
                .tags("operation", CatalogCacheMetrics.GET_PRODUCT_BY_ID)
                .counter();
        return counter == null ? 0.0d : counter.count();
    }
}
