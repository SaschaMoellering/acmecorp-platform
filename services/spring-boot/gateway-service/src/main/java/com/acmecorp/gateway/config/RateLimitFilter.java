package com.acmecorp.gateway.config;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.data.redis.core.ReactiveRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import org.springframework.web.server.WebFilter;
import org.springframework.web.server.WebFilterChain;
import reactor.core.publisher.Mono;

import java.time.Duration;

@Component
public class RateLimitFilter implements WebFilter {

    private final ReactiveRedisTemplate<String, String> redisTemplate;
    private static final int REQUESTS_PER_MINUTE = 1000;
    private static final int BURST_CAPACITY = 100;

    public RateLimitFilter(@Qualifier("reactiveStringRedisTemplate") ReactiveRedisTemplate<String, String> redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, WebFilterChain chain) {
        String clientId = getClientId(exchange);
        String key = "rate_limit:" + clientId;
        
        return redisTemplate.opsForValue()
            .increment(key)
            .flatMap(count -> {
                if (count == 1) {
                    return redisTemplate.expire(key, Duration.ofMinutes(1))
                        .then(Mono.just(count));
                }
                return Mono.just(count);
            })
            .flatMap(count -> {
                if (count > REQUESTS_PER_MINUTE) {
                    exchange.getResponse().setStatusCode(HttpStatus.TOO_MANY_REQUESTS);
                    return exchange.getResponse().setComplete();
                }
                return chain.filter(exchange);
            });
    }

    private String getClientId(ServerWebExchange exchange) {
        String forwarded = exchange.getRequest().getHeaders().getFirst("X-Forwarded-For");
        if (forwarded != null && !forwarded.isEmpty()) {
            return forwarded.split(",")[0].trim();
        }
        return exchange.getRequest().getRemoteAddress() != null 
            ? exchange.getRequest().getRemoteAddress().getAddress().getHostAddress()
            : "unknown";
    }
}