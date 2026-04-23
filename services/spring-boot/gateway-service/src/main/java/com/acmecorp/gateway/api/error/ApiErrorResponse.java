package com.acmecorp.gateway.api.error;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.time.Instant;
import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_NULL)
public class ApiErrorResponse {

    private Instant timestamp;
    private String traceId;
    private int status;
    private String error;
    private String message;
    private String path;
    private Map<String, String> fields;

    public ApiErrorResponse() {
    }

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
