package com.acmecorp.gateway.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

import java.util.List;
import java.util.Map;

@Service
public class GatewayService {

    private static final Logger log = LoggerFactory.getLogger(GatewayService.class);

    private final WebClient webClient;
    private final String ordersBaseUrl;
    private final String catalogBaseUrl;
    private final String billingBaseUrl;

    public GatewayService(WebClient.Builder builder,
                          @Value("${acmecorp.services.orders.base-url}") String ordersBaseUrl,
                          @Value("${acmecorp.services.catalog.base-url}") String catalogBaseUrl,
                          @Value("${acmecorp.services.billing.base-url}") String billingBaseUrl) {
        this.webClient = builder.build();
        this.ordersBaseUrl = ordersBaseUrl;
        this.catalogBaseUrl = catalogBaseUrl;
        this.billingBaseUrl = billingBaseUrl;
    }

    public List<OrderSummary> latestOrders() {
        return webClient.get()
                .uri(ordersBaseUrl + "/api/orders/latest")
                .retrieve()
                .bodyToMono(new ParameterizedTypeReference<List<OrderSummary>>() {})
                .blockOptional()
                .orElse(List.of());
    }

    public OrderWithInvoice orderDetails(Long id) {
        OrderSummary order = webClient.get()
                .uri(ordersBaseUrl + "/api/orders/{id}", id)
                .retrieve()
                .bodyToMono(OrderSummary.class)
                .block();

        InvoiceSummary invoice = null;
        try {
            invoice = webClient.get()
                    .uri(uriBuilder -> uriBuilder
                            .path(billingBaseUrl + "/api/billing/invoices")
                            .queryParam("orderId", order.id())
                            .queryParam("size", 1)
                            .build())
                    .retrieve()
                    .bodyToMono(InvoicePage.class)
                    .map(page -> page.content().isEmpty() ? null : page.content().getFirst())
                    .block();
        } catch (Exception ex) {
            log.warn("Invoice lookup failed for order {}", id, ex);
        }
        return new OrderWithInvoice(order, invoice);
    }

    public List<ProductSummary> catalog(String category, String search) {
        return webClient.get()
                .uri(uriBuilder -> {
                    var builder = uriBuilder.path(catalogBaseUrl + "/api/catalog");
                    if (category != null && !category.isBlank()) {
                        builder.queryParam("category", category);
                    }
                    if (search != null && !search.isBlank()) {
                        builder.queryParam("search", search);
                    }
                    return builder.build();
                })
                .retrieve()
                .bodyToMono(new ParameterizedTypeReference<List<ProductSummary>>() {})
                .blockOptional()
                .orElse(List.of());
    }

    public Mono<String> proxyCatalogRaw() {
        return webClient.get()
                .uri(catalogBaseUrl + "/api/catalog")
                .retrieve()
                .bodyToMono(String.class);
    }

    public Mono<String> proxyOrdersStatus() {
        return webClient.get()
                .uri(ordersBaseUrl + "/api/orders/status")
                .retrieve()
                .bodyToMono(String.class);
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record OrderSummary(Long id,
                               String orderNumber,
                               String customerEmail,
                               String status,
                               java.math.BigDecimal totalAmount,
                               String currency,
                               java.time.Instant createdAt,
                               java.time.Instant updatedAt,
                               List<OrderItemSummary> items) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record OrderItemSummary(Long id,
                                   String productId,
                                   String productName,
                                   java.math.BigDecimal unitPrice,
                                   int quantity,
                                   java.math.BigDecimal lineTotal) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record InvoiceSummary(Long id,
                                 String invoiceNumber,
                                 Long orderId,
                                 String orderNumber,
                                 String customerEmail,
                                 String status,
                                 String currency,
                                 java.math.BigDecimal amount,
                                 java.time.Instant createdAt,
                                 java.time.Instant updatedAt) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record InvoicePage(List<InvoiceSummary> content) {
    }

    public record OrderWithInvoice(OrderSummary order, InvoiceSummary invoice) {
    }

    public record ProductSummary(String id, String sku, String name, String description, String category, String currency, String price, boolean active) {
    }
}
