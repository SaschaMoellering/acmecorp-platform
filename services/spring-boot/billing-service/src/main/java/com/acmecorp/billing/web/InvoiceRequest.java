package com.acmecorp.billing.web;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

public record InvoiceRequest(
        @NotNull Long orderId,
        @NotBlank String orderNumber,
        @Email String customerEmail,
        @Positive BigDecimal amount,
        @NotBlank String currency,
        List<InvoiceLine> items
) {
    public record InvoiceLine(String productId, String productName, int quantity, BigDecimal unitPrice, BigDecimal lineTotal) {
    }

    public Map<String, Object> asMetadata(Long invoiceId) {
        return Map.of(
                "invoiceId", invoiceId,
                "orderId", orderId,
                "orderNumber", orderNumber
        );
    }
}
