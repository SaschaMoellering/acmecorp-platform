package com.acmecorp.billing.web;

import javax.validation.constraints.Email;
import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;
import javax.validation.constraints.Positive;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

public class InvoiceRequest {

    @NotNull
    private Long orderId;

    @NotBlank
    private String orderNumber;

    @Email
    private String customerEmail;

    @Positive
    private BigDecimal amount;

    @NotBlank
    private String currency;

    private List<InvoiceLine> items;

    public InvoiceRequest() {
    }

    public InvoiceRequest(Long orderId,
                          String orderNumber,
                          String customerEmail,
                          BigDecimal amount,
                          String currency,
                          List<InvoiceLine> items) {
        this.orderId = orderId;
        this.orderNumber = orderNumber;
        this.customerEmail = customerEmail;
        this.amount = amount;
        this.currency = currency;
        this.items = items;
    }

    public Long getOrderId() {
        return orderId;
    }

    public void setOrderId(Long orderId) {
        this.orderId = orderId;
    }

    public String getOrderNumber() {
        return orderNumber;
    }

    public void setOrderNumber(String orderNumber) {
        this.orderNumber = orderNumber;
    }

    public String getCustomerEmail() {
        return customerEmail;
    }

    public void setCustomerEmail(String customerEmail) {
        this.customerEmail = customerEmail;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public void setAmount(BigDecimal amount) {
        this.amount = amount;
    }

    public String getCurrency() {
        return currency;
    }

    public void setCurrency(String currency) {
        this.currency = currency;
    }

    public List<InvoiceLine> getItems() {
        return items;
    }

    public void setItems(List<InvoiceLine> items) {
        this.items = items;
    }

    public Map<String, Object> asMetadata(Long invoiceId) {
        return Map.of(
                "invoiceId", invoiceId,
                "orderId", orderId,
                "orderNumber", orderNumber
        );
    }

    public static class InvoiceLine {
        private String productId;
        private String productName;
        private int quantity;
        private BigDecimal unitPrice;
        private BigDecimal lineTotal;

        public InvoiceLine() {
        }

        public InvoiceLine(String productId, String productName, int quantity, BigDecimal unitPrice, BigDecimal lineTotal) {
            this.productId = productId;
            this.productName = productName;
            this.quantity = quantity;
            this.unitPrice = unitPrice;
            this.lineTotal = lineTotal;
        }

        public String getProductId() {
            return productId;
        }

        public void setProductId(String productId) {
            this.productId = productId;
        }

        public String getProductName() {
            return productName;
        }

        public void setProductName(String productName) {
            this.productName = productName;
        }

        public int getQuantity() {
            return quantity;
        }

        public void setQuantity(int quantity) {
            this.quantity = quantity;
        }

        public BigDecimal getUnitPrice() {
            return unitPrice;
        }

        public void setUnitPrice(BigDecimal unitPrice) {
            this.unitPrice = unitPrice;
        }

        public BigDecimal getLineTotal() {
            return lineTotal;
        }

        public void setLineTotal(BigDecimal lineTotal) {
            this.lineTotal = lineTotal;
        }
    }
}
