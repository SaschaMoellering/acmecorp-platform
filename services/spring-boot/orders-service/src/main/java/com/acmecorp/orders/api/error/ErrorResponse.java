package com.acmecorp.orders.api.error;

import java.time.Instant;

public class ErrorResponse {

    private final int status;
    private final String error;
    private final String message;
    private final Instant timestamp;

    public ErrorResponse(int status, String error, String message, Instant timestamp) {
        this.status = status;
        this.error = error;
        this.message = message;
        this.timestamp = timestamp;
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

    public Instant getTimestamp() {
        return timestamp;
    }
}
