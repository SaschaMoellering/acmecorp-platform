package com.acmecorp.analytics.web;

import jakarta.validation.constraints.NotBlank;

import java.util.Map;

public record TrackEventRequest(@NotBlank String event, Map<String, Object> metadata) {
}
