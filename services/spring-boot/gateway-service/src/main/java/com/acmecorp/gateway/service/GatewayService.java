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
    private final String notificationBaseUrl;
    private final String analyticsBaseUrl;

    public GatewayService(WebClient.Builder builder,
                          @Value("${acmecorp.services.orders.base-url}") String ordersBaseUrl,
                          @Value("${acmecorp.services.catalog.base-url}") String catalogBaseUrl,
                          @Value("${acmecorp.services.billing.base-url}") String billingBaseUrl,
                          @Value("${acmecorp.services.notification.base-url}") String notificationBaseUrl,
                          @Value("${acmecorp.services.analytics.base-url}") String analyticsBaseUrl) {
        this.webClient = builder.build();
        this.ordersBaseUrl = ordersBaseUrl;
        this.catalogBaseUrl = catalogBaseUrl;
        this.billingBaseUrl = billingBaseUrl;
        this.notificationBaseUrl = notificationBaseUrl;
        this.analyticsBaseUrl = analyticsBaseUrl;
    }

    public Mono<List<OrderSummary>> latestOrders() {
        return webClient.get()
                .uri(ordersBaseUrl + "/api/orders/latest")
                .retrieve()
                .bodyToMono(new ParameterizedTypeReference<List<OrderSummary>>() {})
                .defaultIfEmpty(List.of())
                .onErrorResume(ex -> {
                    log.warn("Latest orders unavailable", ex);
                    return Mono.just(List.of());
                });
    }

    public Mono<OrderWithInvoice> orderDetails(Long id) {
        Mono<OrderSummary> orderMono = webClient.get()
                .uri(ordersBaseUrl + "/api/orders/{id}", id)
                .retrieve()
                .bodyToMono(OrderSummary.class)
                .cache();

        Mono<InvoiceSummary> invoiceMono = orderMono.flatMap(order -> webClient.get()
                        .uri(uriBuilder -> uriBuilder
                                .path(billingBaseUrl + "/api/billing/invoices")
                                .queryParam("orderId", order.id())
                                .queryParam("size", 1)
                                .build())
                        .retrieve()
                        .bodyToMono(InvoicePage.class)
                        .map(page -> page.content().isEmpty() ? null : page.content().getFirst()))
                .onErrorResume(ex -> {
                    log.warn("Invoice lookup failed for order {}", id, ex);
                    return Mono.empty();
                });

        return orderMono.zipWith(invoiceMono.defaultIfEmpty(null), OrderWithInvoice::new);
    }

    public Mono<List<ProductSummary>> catalog(String category, String search) {
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
                .defaultIfEmpty(List.of())
                .onErrorResume(ex -> {
                    log.warn("Catalog lookup failed", ex);
                    return Mono.just(List.of());
                });
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

    public Mono<Map<String, Long>> analyticsCounters() {
        return webClient.get()
                .uri(analyticsBaseUrl + "/api/analytics/counters")
                .retrieve()
                .bodyToMono(new ParameterizedTypeReference<Map<String, Long>>() {})
                .defaultIfEmpty(Map.of())
                .onErrorResume(ex -> {
                    log.warn("Analytics counters unavailable", ex);
                    return Mono.just(Map.of());
                });
    }

    public Mono<List<SystemStatus>> systemStatus() {
        return Mono.zip(
                        fetchStatus("orders-service", ordersBaseUrl + "/api/orders/status"),
                        fetchStatus("billing-service", billingBaseUrl + "/api/billing/status"),
                        fetchStatus("notification-service", notificationBaseUrl + "/api/notification/status"),
                        fetchStatus("analytics-service", analyticsBaseUrl + "/api/analytics/status"),
                        fetchStatus("catalog-service", catalogBaseUrl + "/api/catalog/status"),
                        Mono.just(new SystemStatus("gateway-service", "OK"))
                )
                .map(tuple -> List.of(
                        tuple.getT1(),
                        tuple.getT2(),
                        tuple.getT3(),
                        tuple.getT4(),
                        tuple.getT5(),
                        tuple.getT6()
                ));
    }

    private Mono<SystemStatus> fetchStatus(String service, String url) {
        return webClient.get()
                .uri(url)
                .retrieve()
                .bodyToMono(new ParameterizedTypeReference<Map<String, Object>>() {})
                .map(body -> body != null && body.get("status") != null ? body.get("status").toString() : "UNKNOWN")
                .defaultIfEmpty("UNKNOWN")
                .map(status -> new SystemStatus(service, status))
                .onErrorResume(ex -> {
                    log.warn("Status check failed for {}", service, ex);
                    return Mono.just(new SystemStatus(service, "DOWN"));
                });
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

    public record SystemStatus(String service, String status) {
    }
}
