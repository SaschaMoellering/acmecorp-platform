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
import java.util.stream.Collectors;

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
                .collect(Collectors.toList());
        var request = new InvoiceRequest(
                order.getId(),
                order.getOrderNumber(),
                order.getCustomerEmail(),
                order.getTotalAmount(),
                order.getCurrency(),
                lines
        );
        try {
            return restTemplate.postForObject(
                    "/api/billing/invoices",
                    request,
                    InvoiceResponse.class
            );
        } catch (Exception ex) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Failed to create invoice for order " + order.getOrderNumber());
        }
    }

    public static class InvoiceRequest {

        private Long orderId;
        private String orderNumber;
        private String customerEmail;
        private BigDecimal amount;
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

        public void setId(Long id) {
            this.id = id;
        }

        public String getInvoiceNumber() {
            return invoiceNumber;
        }

        public void setInvoiceNumber(String invoiceNumber) {
            this.invoiceNumber = invoiceNumber;
        }

        public String getStatus() {
            return status;
        }

        public void setStatus(String status) {
            this.status = status;
        }
    }
}
