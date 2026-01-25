package com.acmecorp.billing.web;

import com.acmecorp.billing.domain.Invoice;
import com.acmecorp.billing.domain.InvoiceStatus;
import com.acmecorp.billing.domain.Payment;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.stream.Collectors;

public class InvoiceResponse {
    private final Long id;
    private final String invoiceNumber;
    private final Long orderId;
    private final String orderNumber;
    private final String customerEmail;
    private final BigDecimal amount;
    private final String currency;
    private final InvoiceStatus status;
    private final Instant createdAt;
    private final Instant updatedAt;
    private final List<PaymentSummary> payments;

    public InvoiceResponse(Long id,
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
        this.id = id;
        this.invoiceNumber = invoiceNumber;
        this.orderId = orderId;
        this.orderNumber = orderNumber;
        this.customerEmail = customerEmail;
        this.amount = amount;
        this.currency = currency;
        this.status = status;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
        this.payments = payments;
    }

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
                invoice.getPayments().stream()
                        .map(PaymentSummary::from)
                        .collect(Collectors.toList())
        );
    }

    public Long getId() {
        return id;
    }

    public String getInvoiceNumber() {
        return invoiceNumber;
    }

    public Long getOrderId() {
        return orderId;
    }

    public String getOrderNumber() {
        return orderNumber;
    }

    public String getCustomerEmail() {
        return customerEmail;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public String getCurrency() {
        return currency;
    }

    public InvoiceStatus getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public List<PaymentSummary> getPayments() {
        return payments;
    }

    public static class PaymentSummary {
        private final Long id;
        private final String paymentMethod;
        private final BigDecimal amount;
        private final Instant timestamp;

        public PaymentSummary(Long id, String paymentMethod, BigDecimal amount, Instant timestamp) {
            this.id = id;
            this.paymentMethod = paymentMethod;
            this.amount = amount;
            this.timestamp = timestamp;
        }

        public static PaymentSummary from(Payment payment) {
            return new PaymentSummary(
                    payment.getId(),
                    payment.getPaymentMethod().name(),
                    payment.getAmount(),
                    payment.getTimestamp()
            );
        }

        public Long getId() {
            return id;
        }

        public String getPaymentMethod() {
            return paymentMethod;
        }

        public BigDecimal getAmount() {
            return amount;
        }

        public Instant getTimestamp() {
            return timestamp;
        }
    }
}
