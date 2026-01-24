package com.acmecorp.orders.client;

import com.acmecorp.orders.domain.Order;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.util.List;

@Component
public class BillingClient {

    private final RestClient restClient;

    public BillingClient(RestClient.Builder builder,
                         @Value("${acmecorp.services.billing}") String billingBaseUrl) {
        this.restClient = builder.baseUrl(billingBaseUrl).build();
    }

    public InvoiceResponse createInvoice(Order order) {
        var lines = order.getItems().stream()
                .map(item -> new InvoiceLine(item.getProductId(), item.getProductName(), item.getQuantity(), item.getUnitPrice(), item.getLineTotal()))
                .toList();
        var request = new InvoiceRequest(
                order.getId(),
                order.getOrderNumber(),
                order.getCustomerEmail(),
                order.getTotalAmount(),
                order.getCurrency(),
                lines
        );
        try {
            return restClient.post()
                    .uri("/api/billing/invoices")
                    .body(request)
                    .retrieve()
                    .body(InvoiceResponse.class);
        } catch (Exception ex) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Failed to create invoice for order " + order.getOrderNumber());
        }
    }

    public record InvoiceRequest(Long orderId,
                                 String orderNumber,
                                 String customerEmail,
                                 BigDecimal amount,
                                 String currency,
                                 List<InvoiceLine> items) {
    }

    public record InvoiceLine(String productId, String productName, int quantity, BigDecimal unitPrice, BigDecimal lineTotal) {
    }

    public record InvoiceResponse(Long id, String invoiceNumber, String status) {
    }
}
