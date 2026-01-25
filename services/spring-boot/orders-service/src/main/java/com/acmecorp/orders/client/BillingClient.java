package com.acmecorp.orders.client;

import com.acmecorp.orders.domain.Order;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.util.List;

@Component
public class BillingClient {

    private final RestTemplate restTemplate;

    public BillingClient(RestTemplateBuilder builder,
                         @Value("${acmecorp.services.billing}") String billingBaseUrl) {
        this.restTemplate = builder.rootUri(billingBaseUrl).build();
    }

    public InvoiceResponse createInvoice(Order order) {
        var lines = order.getItems().stream()
                .map(item -> new InvoiceLine(item.getProductId(), item.getProductName(), item.getQuantity(), item.getUnitPrice(), item.getLineTotal()))
                .collect(java.util.stream.Collectors.toList());
        var request = new InvoiceRequest(
                order.getId(),
                order.getOrderNumber(),
                order.getCustomerEmail(),
                order.getTotalAmount(),
                order.getCurrency(),
                lines
        );
        try {
            return restTemplate.postForObject("/api/billing/invoices", request, InvoiceResponse.class);
        } catch (Exception ex) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Failed to create invoice for order " + order.getOrderNumber());
        }
    }

    public static class InvoiceRequest {
        private final Long orderId;
        private final String orderNumber;
        private final String customerEmail;
        private final BigDecimal amount;
        private final String currency;
        private final List<InvoiceLine> items;

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

        public List<InvoiceLine> getItems() {
            return items;
        }
    }

    public static class InvoiceLine {
        private final String productId;
        private final String productName;
        private final int quantity;
        private final BigDecimal unitPrice;
        private final BigDecimal lineTotal;

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

        public String getProductName() {
            return productName;
        }

        public int getQuantity() {
            return quantity;
        }

        public BigDecimal getUnitPrice() {
            return unitPrice;
        }

        public BigDecimal getLineTotal() {
            return lineTotal;
        }
    }

    public static class InvoiceResponse {
        private Long id;
        private String invoiceNumber;
        private String status;

        public InvoiceResponse() {
        }

        public InvoiceResponse(Long id, String invoiceNumber, String status) {
            this.id = id;
            this.invoiceNumber = invoiceNumber;
            this.status = status;
        }

        public Long getId() {
            return id;
        }

        public String getInvoiceNumber() {
            return invoiceNumber;
        }

        public String getStatus() {
            return status;
        }
    }
}
