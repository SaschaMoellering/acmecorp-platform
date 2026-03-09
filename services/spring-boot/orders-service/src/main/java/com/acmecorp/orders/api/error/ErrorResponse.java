package com.acmecorp.orders.api.error;

import java.util.Map;

public class ErrorResponse {
    public String code;
    public String message;
    public Map<String, Object> details;

    public ErrorResponse() {
    }

    public ErrorResponse(String code, String message, Map<String, Object> details) {
        this.code = code;
        this.message = message;
        this.details = details;
    }
}
