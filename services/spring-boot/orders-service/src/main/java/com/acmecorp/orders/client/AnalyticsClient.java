package com.acmecorp.orders.client;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

@Component
public class AnalyticsClient {

    private final RestTemplate restTemplate;

    public AnalyticsClient(RestTemplateBuilder builder,
                           @Value("${acmecorp.services.analytics}") String analyticsBaseUrl) {
        this.restTemplate = builder.rootUri(analyticsBaseUrl).build();
    }

    public void track(String event, Map<String, Object> metadata) {
        try {
            restTemplate.postForEntity("/api/analytics/track", Map.of("event", event, "metadata", metadata), Void.class);
        } catch (Exception ignored) {
            // Tracking should not break order flow; ignore failures.
        }
    }
}
