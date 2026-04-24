package com.acmecorp.catalog.service;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class CatalogCacheMetrics {

    public static final String CACHE_NAME = "catalog";
    public static final String GET_PRODUCT_BY_ID = "getProductById";

    private final Counter cacheHits;
    private final Counter cacheMisses;
    private final Counter cachePuts;
    private final Counter cacheErrors;
    private final Counter datasourceReads;
    private final Timer cachedReadTimer;

    public CatalogCacheMetrics(MeterRegistry meterRegistry) {
        this.cacheHits = Counter.builder("acmecorp.catalog.cache.hits").tag("cache", CACHE_NAME).tag("operation", GET_PRODUCT_BY_ID).register(meterRegistry);
        this.cacheMisses = Counter.builder("acmecorp.catalog.cache.misses").tag("cache", CACHE_NAME).tag("operation", GET_PRODUCT_BY_ID).register(meterRegistry);
        this.cachePuts = Counter.builder("acmecorp.catalog.cache.puts").tag("cache", CACHE_NAME).tag("operation", GET_PRODUCT_BY_ID).register(meterRegistry);
        this.cacheErrors = Counter.builder("acmecorp.catalog.cache.errors").tag("cache", CACHE_NAME).tag("operation", GET_PRODUCT_BY_ID).register(meterRegistry);
        this.datasourceReads = Counter.builder("acmecorp.catalog.datasource.reads").tag("operation", GET_PRODUCT_BY_ID).register(meterRegistry);
        this.cachedReadTimer = Timer.builder("acmecorp.catalog.cache.read").tag("cache", CACHE_NAME).tag("operation", GET_PRODUCT_BY_ID).register(meterRegistry);
    }

    public void recordHit() {
        cacheHits.increment();
    }

    public void recordMiss() {
        cacheMisses.increment();
    }

    public void recordPut() {
        cachePuts.increment();
    }

    public void recordError() {
        cacheErrors.increment();
    }

    public void recordDatasourceRead() {
        datasourceReads.increment();
    }

    public <T> T recordCachedRead(java.util.function.Supplier<T> supplier) {
        return cachedReadTimer.record(supplier);
    }
}
