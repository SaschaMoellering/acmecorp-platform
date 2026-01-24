package com.acmecorp.notification.client;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.Map;

@Component
public class AnalyticsClient {

    private final RestClient restClient;

    public AnalyticsClient(RestClient.Builder builder,
                           @Value("${acmecorp.services.analytics}") String analyticsBaseUrl) {
        this.restClient = builder.baseUrl(analyticsBaseUrl).build();
    }

    public void track(String event, Map<String, Object> metadata) {
        try {
            restClient.post()
                    .uri("/api/analytics/track")
                    .body(Map.of("event", event, "metadata", metadata))
                    .retrieve()
                    .toBodilessEntity();
        } catch (Exception ignored) {
        }
    }
}
