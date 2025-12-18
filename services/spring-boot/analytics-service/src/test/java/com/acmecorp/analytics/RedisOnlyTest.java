package com.acmecorp.analytics;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.StringRedisTemplate;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE,
    properties = {
        "spring.autoconfigure.exclude=org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration"
    })
class RedisOnlyTest extends BaseRedisTest {

    @Autowired
    private StringRedisTemplate redisTemplate;

    @Test
    void shouldConnectToRedis() {
        assertThat(redis.isRunning()).isTrue();
        assertThat(redisTemplate).isNotNull();
    }

    @Test
    void shouldStoreAndRetrieveData() {
        String key = "test:key";
        String value = "test-value";
        
        redisTemplate.opsForValue().set(key, value);
        String retrieved = redisTemplate.opsForValue().get(key);
        
        assertThat(retrieved).isEqualTo(value);
    }
}