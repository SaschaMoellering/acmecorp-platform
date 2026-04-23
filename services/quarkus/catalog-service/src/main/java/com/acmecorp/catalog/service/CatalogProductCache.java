package com.acmecorp.catalog.service;

import com.acmecorp.catalog.Product;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.quarkus.redis.datasource.RedisDataSource;
import io.quarkus.redis.datasource.keys.KeyCommands;
import io.quarkus.redis.datasource.string.SetArgs;
import io.quarkus.redis.datasource.string.StringCommands;
import jakarta.enterprise.context.ApplicationScoped;

import java.util.Optional;
import java.util.UUID;

@ApplicationScoped
public class CatalogProductCache {

    private static final String PRODUCT_KEY_PREFIX = "catalog:product:";

    private final StringCommands<String, String> stringCommands;
    private final KeyCommands<String> keyCommands;
    private final ObjectMapper objectMapper;
    private final CatalogCacheProperties cacheProperties;
    private final CatalogCacheMetrics cacheMetrics;

    public CatalogProductCache(RedisDataSource redisDataSource,
                               ObjectMapper objectMapper,
                               CatalogCacheProperties cacheProperties,
                               CatalogCacheMetrics cacheMetrics) {
        this.stringCommands = redisDataSource.string(String.class);
        this.keyCommands = redisDataSource.key();
        this.objectMapper = objectMapper;
        this.cacheProperties = cacheProperties;
        this.cacheMetrics = cacheMetrics;
    }

    public Optional<Product> get(UUID productId) {
        String cacheKey = productKey(productId);
        try {
            String cachedPayload = stringCommands.get(cacheKey);
            if (cachedPayload == null) {
                cacheMetrics.recordMiss();
                return Optional.empty();
            }

            CachedProduct cachedProduct = objectMapper.readValue(cachedPayload, CachedProduct.class);
            cacheMetrics.recordHit();
            return Optional.of(cachedProduct.toProduct());
        } catch (RuntimeException | JsonProcessingException exception) {
            cacheMetrics.recordMiss();
            cacheMetrics.recordError();
            deleteQuietly(cacheKey);
            return Optional.empty();
        }
    }

    public void put(Product product) {
        String cacheKey = productKey(product.id);
        try {
            String payload = objectMapper.writeValueAsString(CachedProduct.from(product));
            stringCommands.set(cacheKey, payload, new SetArgs().ex(cacheProperties.productTtl()));
            cacheMetrics.recordPut();
        } catch (RuntimeException | JsonProcessingException exception) {
            cacheMetrics.recordError();
        }
    }

    public void invalidate(UUID productId) {
        try {
            keyCommands.del(productKey(productId));
        } catch (RuntimeException exception) {
            cacheMetrics.recordError();
        }
    }

    public static String productKey(UUID productId) {
        return PRODUCT_KEY_PREFIX + productId;
    }

    private void deleteQuietly(String cacheKey) {
        try {
            keyCommands.del(cacheKey);
        } catch (RuntimeException ignored) {
            // The original cache failure is the important signal.
        }
    }
}
