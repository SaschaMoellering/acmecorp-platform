package com.acmecorp.catalog.error;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.time.Instant;
import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_NULL)
public class ApiErrorResponse {

    public Instant timestamp;
    public String traceId;
    public int status;
    public String error;
    public String message;
    public String path;
    public Map<String, String> fields;

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
}
