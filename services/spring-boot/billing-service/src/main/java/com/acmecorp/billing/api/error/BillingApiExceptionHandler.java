package com.acmecorp.billing.api.error;

import javax.servlet.http.HttpServletRequest;
import javax.validation.ConstraintViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestControllerAdvice
public class BillingApiExceptionHandler {

    private static final List<String> TRACE_HEADERS = List.of(
            "X-B3-TraceId",
            "X-Request-Id",
            "traceparent"
    );

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiErrorResponse> handleValidation(MethodArgumentNotValidException ex,
                                                             HttpServletRequest request) {
        Map<String, String> fields = new LinkedHashMap<>();
        for (FieldError error : ex.getBindingResult().getFieldErrors()) {
            String message = Optional.ofNullable(error.getDefaultMessage()).orElse("Invalid value");
            fields.putIfAbsent(error.getField(), message);
        }
        return buildResponse(request, HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", validationMessage(fields), fields);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ApiErrorResponse> handleConstraintViolation(ConstraintViolationException ex,
                                                                      HttpServletRequest request) {
        Map<String, String> fields = new LinkedHashMap<>();
        ex.getConstraintViolations().stream()
                .sorted(Comparator.comparing(violation -> violation.getPropertyPath().toString()))
                .forEach(violation -> fields.putIfAbsent(
                        violation.getPropertyPath().toString(),
                        Optional.ofNullable(violation.getMessage()).orElse("Invalid value")
                ));
        return buildResponse(request, HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", validationMessage(fields), fields);
    }

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<ApiErrorResponse> handleStatus(ResponseStatusException ex, HttpServletRequest request) {
        HttpStatus status = ex.getStatus();
        String message = Optional.ofNullable(ex.getReason()).orElse(status.getReasonPhrase());
        String errorCode = mapStatusToError(status);
        return buildResponse(request, status, errorCode, message, null);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiErrorResponse> handle(Exception ex, HttpServletRequest request) {
        return buildResponse(request, HttpStatus.INTERNAL_SERVER_ERROR, "INTERNAL_ERROR", "Internal server error", null);
    }

    private static String validationMessage(Map<String, String> fields) {
        if (fields.isEmpty()) {
            return "Validation failed";
        }
        Map.Entry<String, String> entry = fields.entrySet().iterator().next();
        return entry.getKey() + ": " + entry.getValue();
    }

    private static String mapStatusToError(HttpStatus status) {
        if (status == HttpStatus.BAD_GATEWAY
                || status == HttpStatus.SERVICE_UNAVAILABLE
                || status == HttpStatus.GATEWAY_TIMEOUT) {
            return "UPSTREAM_ERROR";
        }
        if (status == HttpStatus.NOT_FOUND) {
            return "NOT_FOUND";
        }
        if (status == HttpStatus.CONFLICT) {
            return "CONFLICT";
        }
        if (status.is4xxClientError()) {
            return "BAD_REQUEST";
        }
        return "INTERNAL_ERROR";
    }

    private ResponseEntity<ApiErrorResponse> buildResponse(HttpServletRequest request,
                                                           HttpStatus status,
                                                           String error,
                                                           String message,
                                                           Map<String, String> fields) {
        ApiErrorResponse response = new ApiErrorResponse(
                Instant.now(),
                resolveTraceId(request),
                status.value(),
                error,
                message,
                request.getRequestURI(),
                fields
        );
        return ResponseEntity.status(status).body(response);
    }

    private String resolveTraceId(HttpServletRequest request) {
        for (String header : TRACE_HEADERS) {
            String value = request.getHeader(header);
            if (value != null && !value.isBlank()) {
                return value;
            }
        }
        return null;
    }
}
