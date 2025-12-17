package com.acmecorp.gateway;

import com.acmecorp.gateway.config.RateLimitFilter;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.redis.core.ReactiveRedisTemplate;
import org.springframework.data.redis.core.ReactiveValueOperations;
import org.springframework.http.HttpStatus;
import org.springframework.mock.http.server.reactive.MockServerHttpRequest;
import org.springframework.mock.web.server.MockServerWebExchange;
import org.springframework.web.server.WebFilterChain;
import reactor.core.publisher.Mono;
import reactor.test.StepVerifier;

import java.time.Duration;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@SpringBootTest
class RateLimitFilterTest {

    @MockBean(name = "reactiveStringRedisTemplate")
    private ReactiveRedisTemplate<String, String> redisTemplate;

    @MockBean
    private ReactiveValueOperations<String, String> valueOps;

    @MockBean
    private WebFilterChain filterChain;

    @Test
    void shouldAllowRequestUnderLimit() {
        when(redisTemplate.opsForValue()).thenReturn(valueOps);
        when(valueOps.increment(anyString())).thenReturn(Mono.just(1L));
        when(redisTemplate.expire(anyString(), any(Duration.class))).thenReturn(Mono.just(true));
        when(filterChain.filter(any())).thenReturn(Mono.empty());

        RateLimitFilter filter = new RateLimitFilter(redisTemplate);
        MockServerWebExchange exchange = MockServerWebExchange.from(
            MockServerHttpRequest.get("/test").build());

        StepVerifier.create(filter.filter(exchange, filterChain))
            .verifyComplete();

        verify(filterChain).filter(exchange);
    }

    @Test
    void shouldBlockRequestOverLimit() {
        when(redisTemplate.opsForValue()).thenReturn(valueOps);
        when(valueOps.increment(anyString())).thenReturn(Mono.just(1001L));

        RateLimitFilter filter = new RateLimitFilter(redisTemplate);
        MockServerWebExchange exchange = MockServerWebExchange.from(
            MockServerHttpRequest.get("/test").build());

        StepVerifier.create(filter.filter(exchange, filterChain))
            .verifyComplete();

        assert exchange.getResponse().getStatusCode() == HttpStatus.TOO_MANY_REQUESTS;
        verify(filterChain, never()).filter(exchange);
    }
}