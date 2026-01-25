package com.acmecorp.gateway.api.error;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.bind.support.WebExchangeBindException;
import org.springframework.web.reactive.function.client.WebClientResponseException;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.server.ServerWebExchange;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestControllerAdvice
public class GatewayApiExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GatewayApiExceptionHandler.class);
    private static final List<String> TRACE_HEADERS = List.of(
            "X-B3-TraceId",
            "X-Request-Id",
            "traceparent"
    );

    private final ObjectMapper objectMapper;

    public GatewayApiExceptionHandler(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @ExceptionHandler(WebClientResponseException.class)
    public ResponseEntity<ApiErrorResponse> handleWebClientResponseException(WebClientResponseException ex,
                                                                             ServerWebExchange exchange) {
        String body = ex.getResponseBodyAsString();
        log.warn("Downstream request failed with status {}", ex.getStatusCode().value());
        ApiErrorResponse upstream = parseUpstream(body);
        if (upstream != null && upstream.getError() != null) {
            ApiErrorResponse response = new ApiErrorResponse(
                    Instant.now(),
                    resolveTraceId(exchange),
                    ex.getStatusCode().value(),
                    upstream.getError(),
                    upstream.getMessage(),
                    exchange.getRequest().getPath().value(),
                    upstream.getFields()
            );
            return ResponseEntity.status(ex.getStatusCode()).body(response);
        }

        String message = "Upstream error (" + ex.getStatusCode().value() + ")";
        if (body != null && !body.isBlank()) {
            message = message + ": " + body.trim();
        }
        return buildResponse(exchange, ex.getStatusCode(), "UPSTREAM_ERROR", message, null);
    }

    @ExceptionHandler({MethodArgumentNotValidException.class, WebExchangeBindException.class})
    public ResponseEntity<ApiErrorResponse> handleValidation(Exception ex, ServerWebExchange exchange) {
        Map<String, String> fields = new LinkedHashMap<>();
        if (ex instanceof MethodArgumentNotValidException) {
            MethodArgumentNotValidException validation = (MethodArgumentNotValidException) ex;
            for (FieldError error : validation.getBindingResult().getFieldErrors()) {
                String message = Optional.ofNullable(error.getDefaultMessage()).orElse("Invalid value");
                fields.putIfAbsent(error.getField(), message);
            }
        } else if (ex instanceof WebExchangeBindException) {
            WebExchangeBindException exchangeBind = (WebExchangeBindException) ex;
            for (FieldError error : exchangeBind.getBindingResult().getFieldErrors()) {
                String message = Optional.ofNullable(error.getDefaultMessage()).orElse("Invalid value");
                fields.putIfAbsent(error.getField(), message);
            }
        }
        return buildResponse(exchange, HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", validationMessage(fields), fields);
    }

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<ApiErrorResponse> handleStatus(ResponseStatusException ex, ServerWebExchange exchange) {
        HttpStatus status = ex.getStatus();
        String message = Optional.ofNullable(ex.getReason()).orElse(status.getReasonPhrase());
        String errorCode = mapStatusToError(status);
        return buildResponse(exchange, status, errorCode, message, null);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiErrorResponse> handle(Exception ex, ServerWebExchange exchange) {
        return buildResponse(exchange, HttpStatus.INTERNAL_SERVER_ERROR, "INTERNAL_ERROR", "Internal server error", null);
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

    private ResponseEntity<ApiErrorResponse> buildResponse(ServerWebExchange exchange,
                                                           HttpStatus status,
                                                           String error,
                                                           String message,
                                                           Map<String, String> fields) {
        ApiErrorResponse response = new ApiErrorResponse(
                Instant.now(),
                resolveTraceId(exchange),
                status.value(),
                error,
                message,
                exchange.getRequest().getPath().value(),
                fields
        );
        return ResponseEntity.status(status).body(response);
    }

    private String resolveTraceId(ServerWebExchange exchange) {
        for (String header : TRACE_HEADERS) {
            String value = exchange.getRequest().getHeaders().getFirst(header);
            if (value != null && !value.isBlank()) {
                return value;
            }
        }
        return null;
    }

    private ApiErrorResponse parseUpstream(String body) {
        if (body == null || body.isBlank()) {
            return null;
        }
        try {
            return objectMapper.readValue(body, ApiErrorResponse.class);
        } catch (Exception ex) {
            return null;
        }
    }
}
