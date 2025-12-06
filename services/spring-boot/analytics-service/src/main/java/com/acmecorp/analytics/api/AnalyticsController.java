package com.acmecorp.analytics.api;

import com.acmecorp.analytics.service.AnalyticsService;
import com.acmecorp.analytics.web.TrackEventRequest;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/analytics")
public class AnalyticsController {

    private final AnalyticsService analyticsService;

    public AnalyticsController(AnalyticsService analyticsService) {
        this.analyticsService = analyticsService;
    }

    @GetMapping("/status")
    public Map<String, Object> status() {
        return Map.of(
                "service", "analytics-service",
                "status", "OK"
        );
    }

    @PostMapping("/track")
    public ResponseEntity<Void> track(@Valid @RequestBody TrackEventRequest request) {
        analyticsService.track(request.event());
        return ResponseEntity.accepted().build();
    }

    @GetMapping("/counters")
    public Map<String, Long> all() {
        return analyticsService.allCounters();
    }

    @GetMapping("/counters/{event}")
    public Map<String, Object> counter(@PathVariable String event) {
        return Map.of("event", event, "count", analyticsService.getCounter(event));
    }
}
