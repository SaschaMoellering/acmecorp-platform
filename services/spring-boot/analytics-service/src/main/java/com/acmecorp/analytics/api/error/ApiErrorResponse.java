package com.acmecorp.analytics.api.error;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.time.Instant;
import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record ApiErrorResponse(Instant timestamp,
                               String traceId,
                               int status,
                               String error,
                               String message,
                               String path,
                               Map<String, String> fields) {
}
