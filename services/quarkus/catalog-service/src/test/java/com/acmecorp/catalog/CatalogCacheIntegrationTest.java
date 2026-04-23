package com.acmecorp.catalog;

import com.acmecorp.catalog.service.CatalogCacheMetrics;
import com.acmecorp.catalog.service.CatalogProductCache;
import com.acmecorp.catalog.service.CatalogService;
import io.micrometer.core.instrument.MeterRegistry;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.redis.datasource.RedisDataSource;
import io.quarkus.redis.datasource.string.StringCommands;
import io.quarkus.test.common.QuarkusTestResource;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.transaction.UserTransaction;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

@QuarkusTest
@QuarkusTestResource(value = RedisTestResource.class, restrictToAnnotatedClass = true)
class CatalogCacheIntegrationTest {

    @Inject
    CatalogService catalogService;

    @Inject
    ProductRepository productRepository;

    @Inject
    RedisDataSource redisDataSource;

    @Inject
    MeterRegistry meterRegistry;

    @Inject
    UserTransaction userTransaction;

    private UUID productId;
    private StringCommands<String, String> stringCommands;

    @BeforeEach
    void setUp() {
        stringCommands = redisDataSource.string(String.class);
        redisDataSource.flushall();
        QuarkusTransaction.requiringNew().run(() -> {
            productRepository.deleteAll();
            Product product = new Product();
            product.sku = "CACHE-SKU-1";
            product.name = "Cached Product";
            product.description = "Redis-backed cache test product";
            product.price = new BigDecimal("18.00");
            product.currency = "USD";
            product.category = "cache-tests";
            product.active = true;
            product.persist();
            productId = product.id;
        });
    }

    @Test
    void coldReadShouldMissCachePopulateRedisAndIncrementMetrics() {
        double missesBefore = cacheCounterValue("acmecorp.catalog.cache.misses");
        double putsBefore = cacheCounterValue("acmecorp.catalog.cache.puts");
        double hitsBefore = cacheCounterValue("acmecorp.catalog.cache.hits");
        double readsBefore = datasourceCounterValue();

        Product product = catalogService.getProductById(productId);

        assertEquals(productId, product.id);
        assertNotNull(stringCommands.get(CatalogProductCache.productKey(productId)));
        assertEquals(missesBefore + 1.0d, cacheCounterValue("acmecorp.catalog.cache.misses"));
        assertEquals(putsBefore + 1.0d, cacheCounterValue("acmecorp.catalog.cache.puts"));
        assertEquals(hitsBefore, cacheCounterValue("acmecorp.catalog.cache.hits"));
        assertEquals(readsBefore + 1.0d, datasourceCounterValue());
    }

    @Test
    void repeatedReadShouldHitCacheAndAvoidAnotherDatasourceRead() {
        catalogService.getProductById(productId);

        double hitsBefore = cacheCounterValue("acmecorp.catalog.cache.hits");
        double readsBefore = datasourceCounterValue();

        Product product = catalogService.getProductById(productId);

        assertEquals(productId, product.id);
        assertEquals(hitsBefore + 1.0d, cacheCounterValue("acmecorp.catalog.cache.hits"));
        assertEquals(readsBefore, datasourceCounterValue());
    }

    @Test
    void updateShouldInvalidateCacheAndRepopulateOnNextRead() {
        catalogService.getProductById(productId);
        assertNotNull(stringCommands.get(CatalogProductCache.productKey(productId)));

        ProductRequest request = new ProductRequest(
                "CACHE-SKU-1",
                "Updated Cached Product",
                "Redis-backed cache test product",
                new BigDecimal("18.00"),
                "USD",
                "cache-tests",
                true
        );
        given()
                .contentType("application/json")
                .body(request)
                .when().put("/api/catalog/" + productId)
                .then()
                .statusCode(200);

        assertFalse(redisDataSource.key().exists(CatalogProductCache.productKey(productId)));

        double missesBefore = cacheCounterValue("acmecorp.catalog.cache.misses");
        double putsBefore = cacheCounterValue("acmecorp.catalog.cache.puts");
        double readsBefore = datasourceCounterValue();

        String refreshedName = given()
                .when().get("/api/catalog/" + productId)
                .then()
                .statusCode(200)
                .extract()
                .path("name");

        assertEquals("Updated Cached Product", refreshedName);
        assertEquals(missesBefore + 1.0d, cacheCounterValue("acmecorp.catalog.cache.misses"));
        assertEquals(putsBefore + 1.0d, cacheCounterValue("acmecorp.catalog.cache.puts"));
        assertEquals(readsBefore + 1.0d, datasourceCounterValue());
        assertNotNull(stringCommands.get(CatalogProductCache.productKey(productId)));
    }

    @Test
    void updateShouldKeepExistingCacheEntryUntilTransactionCommits() throws Exception {
        catalogService.getProductById(productId);
        assertNotNull(stringCommands.get(CatalogProductCache.productKey(productId)));

        ProductRequest request = new ProductRequest(
                "CACHE-SKU-1",
                "Updated Cached Product",
                "Redis-backed cache test product",
                new BigDecimal("18.00"),
                "USD",
                "cache-tests",
                true
        );

        userTransaction.begin();
        catalogService.updateProduct(productId, request);

        assertNotNull(stringCommands.get(CatalogProductCache.productKey(productId)));
        String preCommitName = given()
                .when().get("/api/catalog/" + productId)
                .then()
                .statusCode(200)
                .extract()
                .path("name");
        assertEquals("Cached Product", preCommitName);

        userTransaction.commit();

        assertFalse(redisDataSource.key().exists(CatalogProductCache.productKey(productId)));
    }

    @Test
    void logicalDeactivationShouldInvalidateCacheAndAllowColdReadOfInactiveProduct() {
        catalogService.getProductById(productId);
        assertTrue(redisDataSource.key().exists(CatalogProductCache.productKey(productId)));

        given()
                .when().delete("/api/catalog/" + productId)
                .then()
                .statusCode(204);

        assertFalse(redisDataSource.key().exists(CatalogProductCache.productKey(productId)));

        boolean active = given()
                .when().get("/api/catalog/" + productId)
                .then()
                .statusCode(200)
                .extract()
                .path("active");

        given()
                .when().get("/api/catalog?search=Cached Product")
                .then()
                .statusCode(200)
                .body("findAll { it.id == '%s' }.size()".formatted(productId), org.hamcrest.Matchers.equalTo(0));

        assertFalse(active);
        assertTrue(redisDataSource.key().exists(CatalogProductCache.productKey(productId)));
    }

    @Test
    void logicalDeactivationShouldKeepExistingCacheEntryUntilTransactionCommits() throws Exception {
        catalogService.getProductById(productId);
        assertTrue(redisDataSource.key().exists(CatalogProductCache.productKey(productId)));

        userTransaction.begin();
        catalogService.deleteProduct(productId);

        assertTrue(redisDataSource.key().exists(CatalogProductCache.productKey(productId)));
        boolean preCommitActive = given()
                .when().get("/api/catalog/" + productId)
                .then()
                .statusCode(200)
                .extract()
                .path("active");
        assertTrue(preCommitActive);

        userTransaction.commit();

        assertFalse(redisDataSource.key().exists(CatalogProductCache.productKey(productId)));
    }

    @Test
    void seedShouldKeepExistingCacheEntriesUntilTransactionCommits() throws Exception {
        given()
                .contentType("application/json")
                .body("{}")
                .when().post("/api/catalog/seed")
                .then()
                .statusCode(200);

        List<String> seededIds = List.of(
                "11111111-1111-1111-1111-111111111111",
                "22222222-2222-2222-2222-222222222222"
        );
        seededIds.forEach(id -> given().when().get("/api/catalog/" + id).then().statusCode(200));
        seededIds.forEach(id -> assertTrue(redisDataSource.key().exists("catalog:product:" + id)));

        userTransaction.begin();
        catalogService.seedProducts();

        seededIds.forEach(id -> assertTrue(redisDataSource.key().exists("catalog:product:" + id)));

        userTransaction.commit();

        seededIds.forEach(id -> assertFalse(redisDataSource.key().exists("catalog:product:" + id)));
    }

    @Test
    void cachedReadTimerShouldRecordColdAndWarmReads() {
        double countBefore = timerCount("acmecorp.catalog.cache.read");

        catalogService.getProductById(productId);
        catalogService.getProductById(productId);

        assertEquals(countBefore + 2.0d, timerCount("acmecorp.catalog.cache.read"));
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

    private double timerCount(String name) {
        io.micrometer.core.instrument.Timer timer = meterRegistry.find(name)
                .tags("cache", CatalogCacheMetrics.CACHE_NAME, "operation", CatalogCacheMetrics.GET_PRODUCT_BY_ID)
                .timer();
        return timer == null ? 0.0d : timer.count();
    }
}
