package com.acmecorp.gateway.service;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.util.UriComponentsBuilder;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.util.ArrayList;
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

    // -------------------------------------------------------------------------
    // Orders
    // -------------------------------------------------------------------------

    public Mono<PageResponse<OrderSummary>> listOrders(int page, int size) {
        String url = UriComponentsBuilder
                .fromUriString(ordersBaseUrl + "/api/orders")
                .queryParam("page", page)
                .queryParam("size", size)
                .toUriString();

        log.debug("Listing orders via Orders Service: {}", url);

        return webClient.get()
                .uri(url)
                .retrieve()
                .bodyToMono(new ParameterizedTypeReference<PageResponse<OrderSummary>>() {});
    }

    public Mono<OrderSummary> createOrder(OrderRequest request) {
        String url = ordersBaseUrl + "/api/orders";

        log.debug("Creating order via Orders Service: {}", url);

        return webClient.post()
                .uri(url)
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(request)
                .retrieve()
                .bodyToMono(OrderSummary.class);
    }

    public Mono<OrderSummary> updateOrder(Long id, OrderRequest request) {
        String url = ordersBaseUrl + "/api/orders/{id}";

        log.debug("Updating order {} via Orders Service: {}", id, url);

        Map<String, Object> body = normalizeOrderUpdatePayload(request);

        return webClient.put()
                .uri(url, id)
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(body)
                .retrieve()
                .bodyToMono(OrderSummary.class);
    }

    public Mono<Void> deleteOrder(Long id) {
        String url = ordersBaseUrl + "/api/orders/{id}";

        log.debug("Deleting order {} via Orders Service: {}", id, url);

        return webClient.delete()
                .uri(url, id)
                .retrieve()
                .bodyToMono(Void.class);
    }

    public Mono<OrderSummary> confirmOrder(Long id) {
        String url = ordersBaseUrl + "/api/orders/{id}/confirm";

        log.debug("Confirming order {} via Orders Service: {}", id, url);

        return webClient.post()
                .uri(url, id)
                .retrieve()
                .bodyToMono(OrderSummary.class);
    }

    public Mono<OrderSummary> cancelOrder(Long id) {
        String url = ordersBaseUrl + "/api/orders/{id}/cancel";

        log.debug("Cancelling order {} via Orders Service: {}", id, url);

        return webClient.post()
                .uri(url, id)
                .retrieve()
                .bodyToMono(OrderSummary.class);
    }

    public Mono<String> proxyOrdersStatus() {
        // Typically Spring Boot actuator
        String url = ordersBaseUrl + "/actuator/health";

        log.debug("Proxying Orders Service status: {}", url);

        return webClient.get()
                .uri(url)
                .retrieve()
                .bodyToMono(String.class);
    }

    public Mono<List<OrderSummary>> latestOrders() {
        String url = ordersBaseUrl + "/api/orders/latest";

        log.debug("Fetching latest orders via Orders Service: {}", url);

        return webClient.get()
                .uri(url)
                .retrieve()
                .bodyToMono(new ParameterizedTypeReference<List<OrderSummary>>() {});
    }

    public Mono<OrderWithInvoice> orderDetails(Long id) {
        // Order details from Orders Service
        String orderUrl = ordersBaseUrl + "/api/orders/{id}";
        // Invoices for that order from Billing Service (assumed endpoint)
        String invoiceUrl = billingBaseUrl + "/api/billing/invoices?orderId={orderId}";

        log.debug("Fetching order details for {} via Orders Service: {}", id, orderUrl);
        log.debug("Fetching invoices for order {} via Billing Service: {}", id, invoiceUrl);

        Mono<OrderSummary> orderMono = webClient.get()
                .uri(orderUrl, id)
                .retrieve()
                .bodyToMono(OrderSummary.class);

        Mono<List<InvoiceSummary>> invoicesMono = webClient.get()
                .uri(invoiceUrl, id)
                .retrieve()
                .bodyToMono(new ParameterizedTypeReference<PageResponse<InvoiceSummary>>() {})
                .map(page -> {
                    List<InvoiceSummary> content = page != null ? page.content() : null;
                    return content != null ? content : new ArrayList<InvoiceSummary>();
                })
                .onErrorReturn(new ArrayList<InvoiceSummary>());

        return Mono.zip(orderMono, invoicesMono)
                .map(tuple -> new OrderWithInvoice(tuple.getT1(), tuple.getT2()));
    }

    // -------------------------------------------------------------------------
    // Catalog
    // -------------------------------------------------------------------------

    public Mono<List<ProductSummary>> catalog(String category, String search) {
        UriComponentsBuilder builder = UriComponentsBuilder
                .fromUriString(catalogBaseUrl + "/api/catalog");

        if (category != null && !category.isBlank()) {
            builder.queryParam("category", category);
        }
        if (search != null && !search.isBlank()) {
            builder.queryParam("search", search);
        }

        String url = builder.toUriString();
        log.debug("Listing catalog via Catalog Service: {}", url);

        return webClient.get()
                .uri(url)
                .retrieve()
                .bodyToMono(new ParameterizedTypeReference<List<ProductSummary>>() {});
    }

    public Mono<ProductSummary> getProduct(String id) {
        String url = catalogBaseUrl + "/api/catalog/{id}";

        log.debug("Getting product {} via Catalog Service: {}", id, url);

        return webClient.get()
                .uri(url, id)
                .retrieve()
                .bodyToMono(ProductSummary.class);
    }

    public Mono<String> proxyCatalogRaw() {
        String url = catalogBaseUrl + "/api/catalog";

        log.debug("Proxying raw catalog response from Catalog Service: {}", url);

        return webClient.get()
                .uri(url)
                .retrieve()
                .bodyToMono(String.class);
    }

    public Mono<ProductSummary> createProduct(ProductRequest request) {
        String url = catalogBaseUrl + "/api/catalog";

        log.debug("Creating product via Catalog Service: {}", url);

        return webClient.post()
                .uri(url)
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(request)
                .retrieve()
                .bodyToMono(ProductSummary.class);
    }

    public Mono<ProductSummary> updateProduct(String id, ProductRequest request) {
        String url = catalogBaseUrl + "/api/catalog/{id}";

        log.debug("Updating product {} via Catalog Service: {}", id, url);

        return webClient.put()
                .uri(url, id)
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(request)
                .retrieve()
                .bodyToMono(ProductSummary.class);
    }

    public Mono<Void> deleteProduct(String id) {
        String url = catalogBaseUrl + "/api/catalog/{id}";

        log.debug("Deleting product {} via Catalog Service: {}", id, url);

        return webClient.delete()
                .uri(url, id)
                .retrieve()
                .bodyToMono(Void.class);
    }

    // -------------------------------------------------------------------------
    // Analytics
    // -------------------------------------------------------------------------

    public Mono<Map<String, Long>> analyticsCounters() {
        String url = analyticsBaseUrl + "/api/analytics/counters";

        log.debug("Fetching analytics counters via Analytics Service: {}", url);

        return webClient.get()
                .uri(url)
                .retrieve()
                .bodyToMono(new ParameterizedTypeReference<Map<String, Long>>() {});
    }

    // -------------------------------------------------------------------------
    // System status aggregation
    // -------------------------------------------------------------------------

    public Mono<List<SystemStatus>> systemStatus() {
        List<ServiceDescriptor> services = List.of(
                // Spring Boot services: actuator health
                new ServiceDescriptor("orders",       ordersBaseUrl,       "/actuator/health"),
                new ServiceDescriptor("billing",      billingBaseUrl,      "/actuator/health"),
                new ServiceDescriptor("notification", notificationBaseUrl, "/actuator/health"),
                new ServiceDescriptor("analytics",    analyticsBaseUrl,    "/actuator/health"),

                // Quarkus catalog service: /q/health
                new ServiceDescriptor("catalog",      catalogBaseUrl,      "/q/health")
        );

        return Flux.fromIterable(services)
                .flatMap(this::fetchSystemStatus)
                .collectList();
    }

    private Mono<SystemStatus> fetchSystemStatus(ServiceDescriptor descriptor) {
        String url = descriptor.baseUrl() + descriptor.healthPath();

        log.debug("Fetching system status for {}: {}", descriptor.name(), url);

        return webClient.get()
                .uri(url)
                .retrieve()
                .bodyToMono(new ParameterizedTypeReference<Map<String, Object>>() {})
                .map(health -> {
                    Object status = health.getOrDefault("status", "UNKNOWN");
                    return new SystemStatus(descriptor.name(), String.valueOf(status), health);
                })
                .onErrorResume(ex -> {
                    log.warn("Failed to fetch health for {}: {}", descriptor.name(), ex.getMessage());
                    return Mono.just(new SystemStatus(
                            descriptor.name(),
                            "DOWN",
                            Map.of("error", ex.getMessage())
                    ));
                });
    }

    // -------------------------------------------------------------------------
    // Seed data
    // -------------------------------------------------------------------------

    public Mono<SeedResult> seedData() {
        String ordersSeedUrl = ordersBaseUrl + "/api/orders/seed";
        String catalogSeedUrl = catalogBaseUrl + "/api/catalog/seed";

        log.debug("Seeding orders via Orders Service: {}", ordersSeedUrl);
        log.debug("Seeding catalog via Catalog Service: {}", catalogSeedUrl);

        Mono<Integer> ordersSeed = webClient.post()
                .uri(ordersSeedUrl)
                .retrieve()
                .bodyToMono(OrdersSeedResponse.class)
                .map(resp -> resp != null ? resp.count() : 0)
                .onErrorResume(ex -> {
                    log.warn("Failed to seed orders: {}", ex.getMessage());
                    return Mono.just(0);
                });

        Mono<Integer> catalogSeed = webClient.post()
                .uri(catalogSeedUrl)
                .retrieve()
                .bodyToMono(new ParameterizedTypeReference<List<ProductSummary>>() {})
                .map(list -> list != null ? list.size() : 0)
                .onErrorResume(ex -> {
                    log.warn("Failed to seed catalog: {}", ex.getMessage());
                    return Mono.just(0);
                });

        return Mono.zip(ordersSeed, catalogSeed)
                .map(tuple -> new SeedResult(tuple.getT1(), tuple.getT2(), "Seed completed"));
    }

    // -------------------------------------------------------------------------
    // DTOs
    // -------------------------------------------------------------------------

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record PageResponse<T>(
            List<T> content,
            int page,
            int size,
            long totalElements,
            int totalPages,
            // FIX: use Boolean (wrapper) instead of primitive boolean so that null is allowed
            // (Orders Service may return "last": null or omit it)
            Boolean last
    ) {
    }

    /**
     * Generic order representation; we treat orders as a flexible JSON object.
     */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class OrderSummary extends java.util.HashMap<String, Object> {
    }

    /**
     * Flexible order request body (proxy to Orders Service).
     */
    public static class OrderRequest extends java.util.HashMap<String, Object> {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class InvoiceSummary extends java.util.HashMap<String, Object> {
    }

    public record OrderWithInvoice(OrderSummary order, List<InvoiceSummary> invoices) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class ProductSummary extends java.util.HashMap<String, Object> {
    }

    public static class ProductRequest extends java.util.HashMap<String, Object> {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record OrdersSeedResponse(int count, boolean seeded) {
    }

    public record SystemStatus(String service, String status, Map<String, Object> details) {
    }

    public record SeedResult(int ordersCreated, int productsCreated, String message) {
    }

    private record ServiceDescriptor(String name, String baseUrl, String healthPath) {
    }

    private Map<String, Object> normalizeOrderUpdatePayload(OrderRequest request) {
        Map<String, Object> body = new java.util.HashMap<>();

        Object customerEmail = request.get("customerEmail");
        Object status = request.get("status");
        Object productId = request.get("productId");
        Object quantity = request.get("quantity");
        Object items = request.get("items");

        if (customerEmail != null) {
            body.put("customerEmail", customerEmail);
        }
        if (status != null) {
            body.put("status", status);
        }

        if (items instanceof List<?> itemList && !itemList.isEmpty()) {
            body.put("items", itemList);
        } else if (productId != null && quantity != null) {
            Map<String, Object> item = new java.util.HashMap<>();
            item.put("productId", productId);
            item.put("quantity", quantity);
            body.put("items", List.of(item));
        }

        return body;
    }
}
