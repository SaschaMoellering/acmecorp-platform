package com.acmecorp.orders;

import com.acmecorp.orders.client.CatalogClient;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.cache.CacheManager;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(properties = {
    "acmecorp.services.catalog=http://localhost:8080",
    "acmecorp.services.billing=http://localhost:8081",
    "acmecorp.services.analytics=http://localhost:8082"
})
@Testcontainers
class CacheIntegrationTest {

    @MockBean
    private CatalogClient catalogClient;
    
    @MockBean
    private com.acmecorp.orders.client.BillingClient billingClient;
    
    @MockBean
    private com.acmecorp.orders.client.AnalyticsClient analyticsClient;

    @Container
    static GenericContainer<?> redis = new GenericContainer<>(DockerImageName.parse("redis:7"))
        .withExposedPorts(6379);

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.data.redis.host", redis::getHost);
        registry.add("spring.data.redis.port", redis::getFirstMappedPort);
    }

    @Autowired
    private CacheManager cacheManager;

    @Autowired
    private RedisTemplate<String, Object> redisTemplate;

    @Test
    void shouldConnectToRedis() {
        assertThat(redis.isRunning()).isTrue();
        assertThat(cacheManager).isNotNull();
    }

    @Test
    void shouldCacheData() {
        String key = "test:key";
        String value = "test-value";
        
        redisTemplate.opsForValue().set(key, value);
        String cached = (String) redisTemplate.opsForValue().get(key);
        
        assertThat(cached).isEqualTo(value);
    }
}