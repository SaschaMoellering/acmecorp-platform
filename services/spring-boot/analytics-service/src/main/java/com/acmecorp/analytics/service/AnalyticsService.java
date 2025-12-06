package com.acmecorp.analytics.service;

import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class AnalyticsService {

    public static final List<String> KNOWN_EVENTS = List.of(
            "orders.created",
            "orders.confirmed",
            "orders.cancelled",
            "billing.invoice.created",
            "billing.invoice.paid",
            "notification.sent"
    );

    private final StringRedisTemplate redisTemplate;

    public AnalyticsService(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    public void track(String event) {
        String key = toKey(event);
        redisTemplate.opsForValue().increment(key);
    }

    public Map<String, Long> allCounters() {
        Map<String, Long> counters = new LinkedHashMap<>();
        for (String event : KNOWN_EVENTS) {
            counters.put(event, getCounter(event));
        }
        return counters;
    }

    public long getCounter(String event) {
        String key = toKey(event);
        String value = redisTemplate.opsForValue().get(key);
        return value != null ? Long.parseLong(value) : 0L;
    }

    private String toKey(String event) {
        return "analytics:event:" + event;
    }
}
