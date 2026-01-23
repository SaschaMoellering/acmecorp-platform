package com.acmecorp.orders.api.error;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;

public class ApiError {

    private final HttpStatus status;
    private final String message;
    private final Instant timestamp;

    private ApiError(HttpStatus status, String message) {
        this.status = status;
        this.message = message;
        this.timestamp = Instant.now();
    }

    public static ApiError fromException(ResponseStatusException ex) {
        String reason = ex.getReason();
        String message = reason != null ? reason : ex.getMessage();
        HttpStatus status = HttpStatus.valueOf(ex.getStatusCode().value());
        if (message == null || message.isEmpty()) {
            message = status.getReasonPhrase();
        }
        return new ApiError(status, message);
    }

    public static ApiError fromException(Exception ex) {
        String message = ex.getMessage();
        if (message == null || message.isEmpty()) {
            message = "Unexpected error";
        }
        return new ApiError(HttpStatus.INTERNAL_SERVER_ERROR, message);
    }

    public static ErrorResponse toResponse(ApiError error) {
        return new ErrorResponse(
                error.status.value(),
                error.status.getReasonPhrase(),
                error.message,
                error.timestamp
        );
    }

    public static HttpStatus toStatus(ApiError error) {
        return error.status;
    }
}
