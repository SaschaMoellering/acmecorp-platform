package com.acmecorp.orders.api.error;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;

@RestControllerAdvice
public class OrdersApiExceptionHandler {

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<ErrorResponse> handle(ResponseStatusException ex) {
        ApiError error = ApiError.fromException(ex);
        return ResponseEntity.status(ex.getStatusCode()).body(ApiError.toResponse(error));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handle(MethodArgumentNotValidException ex) {
        String message = "Validation failed";
        FieldError fieldError = ex.getBindingResult().getFieldError();
        if (fieldError != null) {
            String defaultMessage = fieldError.getDefaultMessage();
            if (defaultMessage == null || defaultMessage.isEmpty()) {
                defaultMessage = "is invalid";
            }
            message = fieldError.getField() + ": " + defaultMessage;
        }

        ErrorResponse response = new ErrorResponse(
                HttpStatus.BAD_REQUEST.value(),
                HttpStatus.BAD_REQUEST.getReasonPhrase(),
                message,
                Instant.now()
        );
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handle(Exception ex) {
        ApiError error = ApiError.fromException(ex);
        return ResponseEntity.status(ApiError.toStatus(error)).body(ApiError.toResponse(error));
    }
}
