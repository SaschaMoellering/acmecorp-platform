package com.acmecorp.orders.api.error;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.server.ResponseStatusException;

import java.util.Map;
import java.util.Optional;

public class ApiError {
    private final String code;
    private final String message;
    private final HttpStatus status;
    private final Map<String, Object> details;

    private ApiError(String code, String message, HttpStatus status, Map<String, Object> details) {
        this.code = code;
        this.message = message;
        this.status = status;
        this.details = details;
    }

    public static ApiError fromException(Exception ex) {
        if (ex instanceof MethodArgumentNotValidException validation) {
            return new ApiError(
                    "VALIDATION_ERROR",
                    "Validation failed",
                    HttpStatus.BAD_REQUEST,
                    Map.of(
                            "violations",
                            validation.getBindingResult().getFieldErrors().stream()
                                    .map(error -> Map.of(
                                            "field", error.getField(),
                                            "message", error.getDefaultMessage()
                                    ))
                                    .toList()
                    )
            );
        }
        if (ex instanceof ResponseStatusException statusException) {
            HttpStatus status = HttpStatus.valueOf(statusException.getStatusCode().value());
            String message = Optional.ofNullable(statusException.getReason()).orElse(status.getReasonPhrase());
            return new ApiError(status.name(), message, status, Map.of());
        }
        return new ApiError("UNEXPECTED", "Unexpected error", HttpStatus.INTERNAL_SERVER_ERROR, Map.of());
    }

    public static HttpStatus toStatus(ApiError error) {
        return error.status;
    }

    public static ErrorResponse toResponse(ApiError error) {
        return new ErrorResponse(error.code, error.message, error.details);
    }
}
