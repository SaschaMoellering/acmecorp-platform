package com.acmecorp.gateway.api.error;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.reactive.function.client.WebClientResponseException;

@RestControllerAdvice
public class GatewayApiExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GatewayApiExceptionHandler.class);

    @ExceptionHandler(WebClientResponseException.class)
    public ResponseEntity<String> handleWebClientResponseException(WebClientResponseException ex) {
        HttpHeaders headers = new HttpHeaders();
        MediaType contentType = ex.getHeaders().getContentType();
        if (contentType != null) {
            headers.setContentType(contentType);
        }

        log.warn("Downstream request failed with status {}", ex.getStatusCode().value());
        return ResponseEntity.status(ex.getStatusCode())
                .headers(headers)
                .body(ex.getResponseBodyAsString());
    }
}
