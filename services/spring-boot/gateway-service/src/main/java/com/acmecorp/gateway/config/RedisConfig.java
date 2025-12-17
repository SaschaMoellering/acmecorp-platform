package com.acmecorp.gateway.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.ReactiveRedisConnectionFactory;
import org.springframework.data.redis.core.ReactiveRedisTemplate;
import org.springframework.data.redis.serializer.RedisSerializationContext;
import org.springframework.data.redis.serializer.StringRedisSerializer;
import org.springframework.session.data.redis.config.annotation.web.server.EnableRedisWebSession;

@Configuration
@EnableRedisWebSession(maxInactiveIntervalInSeconds = 1800)
public class RedisConfig {

    private final ReactiveRedisTemplate<String, String> redisTemplate;

    public RedisConfig(ReactiveRedisTemplate<String, String> redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    @Bean
    public ReactiveRedisTemplate<String, String> reactiveRedisTemplate(
            ReactiveRedisConnectionFactory connectionFactory) {
        
        RedisSerializationContext<String, String> serializationContext = 
            RedisSerializationContext.<String, String>newSerializationContext()
                .key(StringRedisSerializer.UTF_8)
                .value(StringRedisSerializer.UTF_8)
                .hashKey(StringRedisSerializer.UTF_8)
                .hashValue(StringRedisSerializer.UTF_8)
                .build();
        
        return new ReactiveRedisTemplate<>(connectionFactory, serializationContext);
    }
}