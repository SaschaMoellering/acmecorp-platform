package com.acmecorp.billing.web;

import com.acmecorp.billing.domain.PaymentMethod;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;
import java.util.Map;

public record PaymentRequest(@Positive BigDecimal amount, PaymentMethod paymentMethod) {
    public Map<String, Object> asMetadata(Long invoiceId, String invoiceNumber) {
        return Map.of(
                "invoiceId", invoiceId,
                "invoiceNumber", invoiceNumber
        );
    }
}
