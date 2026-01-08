package com.acmecorp.billing.api.error;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class BillingApiExceptionHandler {

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handle(Exception ex) {
        ApiError error = ApiError.fromException(ex);
        return ResponseEntity.status(ApiError.toStatus(error)).body(ApiError.toResponse(error));
    }
}
