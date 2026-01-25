package com.acmecorp.billing.web;

import com.acmecorp.billing.domain.PaymentMethod;
import javax.validation.constraints.Positive;

import java.math.BigDecimal;
import java.util.Map;

public class PaymentRequest {

    @Positive
    private BigDecimal amount;

    private PaymentMethod paymentMethod;

    public PaymentRequest() {
    }

    public PaymentRequest(BigDecimal amount, PaymentMethod paymentMethod) {
        this.amount = amount;
        this.paymentMethod = paymentMethod;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public void setAmount(BigDecimal amount) {
        this.amount = amount;
    }

    public PaymentMethod getPaymentMethod() {
        return paymentMethod;
    }

    public void setPaymentMethod(PaymentMethod paymentMethod) {
        this.paymentMethod = paymentMethod;
    }

    public Map<String, Object> asMetadata(Long invoiceId, String invoiceNumber) {
        return Map.of(
                "invoiceId", invoiceId,
                "invoiceNumber", invoiceNumber
        );
    }
}
