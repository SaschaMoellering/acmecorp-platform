package com.acmecorp.orders.api.error;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;
import java.util.Optional;

public sealed interface ApiError
        permits ApiError.BadRequest, ApiError.NotFound, ApiError.Validation, ApiError.Conflict, ApiError.Unexpected {

    record BadRequest(String message) implements ApiError {
    }

    record NotFound(String resource, String detail) implements ApiError {
    }

    record Validation(List<FieldViolation> violations) implements ApiError {
    }

    record Conflict(String message) implements ApiError {
    }

    record Unexpected(String message) implements ApiError {
    }

    record FieldViolation(String field, String message) {
    }

    static ApiError fromException(Exception ex) {
        return switch (ex) {
            case MethodArgumentNotValidException validation -> new Validation(
                    validation.getBindingResult().getFieldErrors().stream()
                            .map(error -> new FieldViolation(error.getField(), error.getDefaultMessage()))
                            .toList()
            );
            case ResponseStatusException statusException -> fromStatusException(statusException);
            case IllegalArgumentException badRequest -> new BadRequest(badRequest.getMessage());
            default -> new Unexpected("Unexpected error");
        };
    }

    static HttpStatus toStatus(ApiError error) {
        return switch (error) {
            case BadRequest ignored -> HttpStatus.BAD_REQUEST;
            case Validation ignored -> HttpStatus.BAD_REQUEST;
            case NotFound ignored -> HttpStatus.NOT_FOUND;
            case Conflict ignored -> HttpStatus.CONFLICT;
            case Unexpected ignored -> HttpStatus.INTERNAL_SERVER_ERROR;
        };
    }

    static ErrorResponse toResponse(ApiError error) {
        return switch (error) {
            case BadRequest(var message) -> new ErrorResponse("BAD_REQUEST", message, Map.of());
            case Validation(var violations) -> new ErrorResponse(
                    "VALIDATION_ERROR",
                    "Validation failed",
                    Map.of("violations", violations)
            );
            case NotFound(var resource, var detail) -> new ErrorResponse(
                    "NOT_FOUND",
                    detail,
                    Map.of("resource", resource)
            );
            case Conflict(var message) -> new ErrorResponse("CONFLICT", message, Map.of());
            case Unexpected(var message) -> new ErrorResponse("UNEXPECTED", message, Map.of());
        };
    }

    private static ApiError fromStatusException(ResponseStatusException ex) {
        var reason = Optional.ofNullable(ex.getReason()).orElse("Unexpected error");
        return switch (ex.getStatusCode().value()) {
            case 400 -> new BadRequest(reason);
            case 404 -> new NotFound("order", reason);
            case 409 -> new Conflict(reason);
            default -> new Unexpected(reason);
        };
    }
}
