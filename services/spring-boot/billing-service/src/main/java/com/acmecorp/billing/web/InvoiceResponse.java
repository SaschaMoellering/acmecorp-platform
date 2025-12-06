package com.acmecorp.billing.web;

import com.acmecorp.billing.domain.Invoice;
import com.acmecorp.billing.domain.InvoiceStatus;
import com.acmecorp.billing.domain.Payment;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

public record InvoiceResponse(Long id,
                              String invoiceNumber,
                              Long orderId,
                              String orderNumber,
                              String customerEmail,
                              BigDecimal amount,
                              String currency,
                              InvoiceStatus status,
                              Instant createdAt,
                              Instant updatedAt,
                              List<PaymentSummary> payments) {

    public static InvoiceResponse from(Invoice invoice) {
        return new InvoiceResponse(
                invoice.getId(),
                invoice.getInvoiceNumber(),
                invoice.getOrderId(),
                invoice.getOrderNumber(),
                invoice.getCustomerEmail(),
                invoice.getAmount(),
                invoice.getCurrency(),
                invoice.getStatus(),
                invoice.getCreatedAt(),
                invoice.getUpdatedAt(),
                invoice.getPayments().stream().map(PaymentSummary::from).toList()
        );
    }

    public record PaymentSummary(Long id, String paymentMethod, BigDecimal amount, Instant timestamp) {
        public static PaymentSummary from(Payment payment) {
            return new PaymentSummary(
                    payment.getId(),
                    payment.getPaymentMethod().name(),
                    payment.getAmount(),
                    payment.getTimestamp()
            );
        }
    }
}
