package com.acmecorp.billing.api.error;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.time.Instant;
import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_NULL)
public class ApiErrorResponse {

    private final Instant timestamp;
    private final String traceId;
    private final int status;
    private final String error;
    private final String message;
    private final String path;
    private final Map<String, String> fields;

    public ApiErrorResponse(Instant timestamp,
                            String traceId,
                            int status,
                            String error,
                            String message,
                            String path,
                            Map<String, String> fields) {
        this.timestamp = timestamp;
        this.traceId = traceId;
        this.status = status;
        this.error = error;
        this.message = message;
        this.path = path;
        this.fields = fields;
    }

    public Instant getTimestamp() {
        return timestamp;
    }

    public String getTraceId() {
        return traceId;
    }

    public int getStatus() {
        return status;
    }

    public String getError() {
        return error;
    }

    public String getMessage() {
        return message;
    }

    public String getPath() {
        return path;
    }

    public Map<String, String> getFields() {
        return fields;
    }
}
