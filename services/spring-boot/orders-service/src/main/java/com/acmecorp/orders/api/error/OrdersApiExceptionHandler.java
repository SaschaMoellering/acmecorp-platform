package com.acmecorp.orders.api.error;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

@RestControllerAdvice
public class OrdersApiExceptionHandler {

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<ErrorResponse> handle(ResponseStatusException ex) {
        ApiError error = ApiError.fromException(ex);
        return ResponseEntity.status(ex.getStatus()).body(ApiError.toResponse(error));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handle(Exception ex) {
        ApiError error = ApiError.fromException(ex);
        return ResponseEntity.status(ApiError.toStatus(error)).body(ApiError.toResponse(error));
    }
}
