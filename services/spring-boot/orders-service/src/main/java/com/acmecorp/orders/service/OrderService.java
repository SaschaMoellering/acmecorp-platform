package com.acmecorp.orders.service;

import com.acmecorp.orders.client.AnalyticsClient;
import com.acmecorp.orders.client.BillingClient;
import com.acmecorp.orders.client.CatalogClient;
import com.acmecorp.orders.domain.OrderIdempotency;
import com.acmecorp.orders.domain.Order;
import com.acmecorp.orders.domain.OrderItem;
import com.acmecorp.orders.domain.OrderStatus;
import com.acmecorp.orders.domain.OrderStatusHistory;
import com.acmecorp.orders.messaging.NotificationPublisher;
import com.acmecorp.orders.repository.OrderIdempotencyRepository;
import com.acmecorp.orders.repository.OrderRepository;
import com.acmecorp.orders.repository.OrderStatusHistoryRepository;
import com.acmecorp.orders.web.OrderRequest;
import com.acmecorp.orders.web.OrderResponse;
import com.acmecorp.orders.web.OrderStatusHistoryResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Profile;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.Year;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

import static org.springframework.http.HttpStatus.BAD_REQUEST;
import static org.springframework.http.HttpStatus.NOT_FOUND;

@Service
@Profile("!buildpack")
public class OrderService {

    private static final Logger log = LoggerFactory.getLogger(OrderService.class);

    private final OrderRepository orderRepository;
    private final OrderIdempotencyRepository idempotencyRepository;
    private final OrderStatusHistoryRepository historyRepository;
    private final CatalogClient catalogClient;
    private final BillingClient billingClient;
    private final AnalyticsClient analyticsClient;
    private final NotificationPublisher notificationPublisher;

    public OrderService(OrderRepository orderRepository,
                        OrderIdempotencyRepository idempotencyRepository,
                        OrderStatusHistoryRepository historyRepository,
                        CatalogClient catalogClient,
                        BillingClient billingClient,
                        AnalyticsClient analyticsClient,
                        NotificationPublisher notificationPublisher) {
        this.orderRepository = orderRepository;
        this.idempotencyRepository = idempotencyRepository;
        this.historyRepository = historyRepository;
        this.catalogClient = catalogClient;
        this.billingClient = billingClient;
        this.analyticsClient = analyticsClient;
        this.notificationPublisher = notificationPublisher;
    }

    @Transactional
    public Order createOrder(OrderRequest request, String idempotencyKey) {
        if (request.items() == null || request.items().isEmpty()) {
            throw new ResponseStatusException(BAD_REQUEST, "Order must contain at least one item");
        }

        String requestHash = requestHash(request);
        if (idempotencyKey != null && !idempotencyKey.isBlank()) {
            var existing = idempotencyRepository.findByIdempotencyKey(idempotencyKey);
            if (existing.isPresent()) {
                OrderIdempotency record = existing.get();
                if (!record.getRequestHash().equals(requestHash)) {
                    throw new ResponseStatusException(
                            org.springframework.http.HttpStatus.CONFLICT,
                            "Idempotency-Key reuse with different request"
                    );
                }
                return getOrder(record.getOrder().getId());
            }
        }

        Order order = new Order();
        order.setOrderNumber(generateOrderNumber());
        order.setCustomerEmail(request.customerEmail());
        order.setStatus(OrderStatus.NEW);
        order.setCreatedAt(Instant.now());
        order.setUpdatedAt(order.getCreatedAt());

        applyItems(order, request.items());

        Order saved = orderRepository.save(order);
        if (idempotencyKey != null && !idempotencyKey.isBlank()) {
            OrderIdempotency record = new OrderIdempotency();
            record.setIdempotencyKey(idempotencyKey);
            record.setRequestHash(requestHash);
            record.setOrder(saved);
            record.setCreatedAt(Instant.now());
            idempotencyRepository.save(record);
        }
        recordStatusChange(saved, null, saved.getStatus(), "created");
        analyticsClient.track("orders.created", Map.of("orderId", saved.getId(), "orderNumber", saved.getOrderNumber()));
        return saved;
    }

    @Transactional
    public Order createOrder(OrderRequest request) {
        return createOrder(request, null);
    }

    @Transactional(readOnly = true)
    public Order getOrder(Long id) {
        return orderRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(NOT_FOUND, "Order not found"));
    }

    @Transactional(readOnly = true)
    public Page<Order> listOrders(String customerEmail, OrderStatus status, int page, int size) {
        Specification<Order> spec = Specification.where(null);
        if (customerEmail != null && !customerEmail.isBlank()) {
            spec = spec.and((root, query, cb) -> cb.like(cb.lower(root.get("customerEmail")), "%" + customerEmail.toLowerCase(Locale.ROOT) + "%"));
        }
        if (status != null) {
            spec = spec.and((root, query, cb) -> cb.equal(root.get("status"), status));
        }
        Page<Order> ordersPage = orderRepository.findAll(spec, PageRequest.of(page, size));
        preloadItems(ordersPage.getContent());
        return ordersPage;
    }

    @Transactional(readOnly = true)
    public List<Order> latestOrders() {
        List<Order> orders = orderRepository.findTop10ByOrderByCreatedAtDesc();
        preloadItems(orders);
        return orders;
    }

    @Transactional(readOnly = true)
    public List<OrderResponse> listOrdersNPlusOneDemo(int limit) {
        var pageRequest = PageRequest.of(0, Math.max(1, limit));
        return orderRepository.findAll(pageRequest)
                .getContent()
                .stream()
                .map(OrderResponse::from)
                .toList();
    }

    @Transactional
    public Order confirm(Long id) {
        log.info("Confirming order id={}", id);
        try {
            Order order = getOrder(id);
            if (order.getStatus() != OrderStatus.NEW) {
                throw new ResponseStatusException(BAD_REQUEST, "Only NEW orders can be confirmed");
            }
            OrderStatus oldStatus = order.getStatus();
            order.setStatus(OrderStatus.CONFIRMED);
            order.setUpdatedAt(Instant.now());
            Order saved = orderRepository.save(order);
            recordStatusChange(saved, oldStatus, saved.getStatus(), "confirmed");

            billingClient.createInvoice(saved);
            analyticsClient.track("orders.confirmed", Map.of("orderId", saved.getId(), "orderNumber", saved.getOrderNumber()));
            notificationPublisher.sendOrderConfirmation(saved.getCustomerEmail(), saved.getOrderNumber());
            return saved;
        } catch (RuntimeException ex) {
            log.error("Failed to confirm order id={}", id, ex);
            throw ex;
        }
    }

    @Transactional
    public Order cancel(Long id) {
        Order order = getOrder(id);
        if (order.getStatus() == OrderStatus.CANCELLED) {
            return order;
        }
        if (order.getStatus() != OrderStatus.NEW) {
            throw new ResponseStatusException(BAD_REQUEST, "Only NEW orders can be cancelled");
        }
        OrderStatus oldStatus = order.getStatus();
        order.setStatus(OrderStatus.CANCELLED);
        order.setUpdatedAt(Instant.now());
        Order saved = orderRepository.save(order);
        recordStatusChange(saved, oldStatus, saved.getStatus(), "cancelled");
        analyticsClient.track("orders.cancelled", Map.of("orderId", saved.getId(), "orderNumber", saved.getOrderNumber()));
        return saved;
    }

    @Transactional(readOnly = true)
    public List<OrderResponse> toResponses(List<Order> orders) {
        return orders.stream()
                .sorted(Comparator.comparing(Order::getCreatedAt).reversed())
                .map(OrderResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public OrderResponse toResponse(Order order) {
        return OrderResponse.from(order);
    }

    @Transactional
    public Order updateOrder(Long id, OrderRequest request) {
        Order order = getOrder(id);
        OrderStatus oldStatus = order.getStatus();

        if (request.customerEmail() != null) {
            order.setCustomerEmail(request.customerEmail());
        }
        if (request.status() != null) {
            order.setStatus(request.status());
        }

        if (request.items() != null && !request.items().isEmpty()) {
            applyItems(order, request.items());
        }

        order.setUpdatedAt(Instant.now());
        if (order.getCreatedAt() == null) {
            order.setCreatedAt(order.getUpdatedAt());
        }

        Order saved = orderRepository.save(order);
        if (request.status() != null && oldStatus != saved.getStatus()) {
            recordStatusChange(saved, oldStatus, saved.getStatus(), "updated");
        }
        analyticsClient.track("orders.updated", Map.of("orderId", saved.getId(), "orderNumber", saved.getOrderNumber()));
        return saved;
    }

    @Transactional
    public void deleteOrder(Long id) {
        Order order = getOrder(id);
        orderRepository.delete(order);
        analyticsClient.track("orders.deleted", Map.of("orderId", order.getId(), "orderNumber", order.getOrderNumber()));
    }

    @Transactional(readOnly = true)
    public List<OrderStatusHistoryResponse> history(Long orderId) {
        getOrder(orderId);
        return historyRepository.findByOrderIdOrderByChangedAtAsc(orderId)
                .stream()
                .map(OrderStatusHistoryResponse::from)
                .toList();
    }

    @Transactional
    public List<OrderResponse> seedDemoData() {
        List<SeedOrderSpec> seeds = defaultSeedSpecs();
        List<String> seedOrderNumbers = seeds.stream()
                .map(SeedOrderSpec::orderNumber)
                .collect(Collectors.toList());

        List<Order> existing = orderRepository.findByOrderNumberIn(seedOrderNumbers);
        if (!existing.isEmpty()) {
            List<Long> ids = existing.stream().map(Order::getId).filter(Objects::nonNull).collect(Collectors.toList());
            if (!ids.isEmpty()) {
                historyRepository.deleteByOrderIdIn(ids);
                idempotencyRepository.deleteByOrderIdIn(ids);
            }
            orderRepository.deleteAll(existing);
        }

        return seeds.stream()
                .map(this::createSeedOrder)
                .map(OrderResponse::from)
                .toList();
    }

    private void applyItems(Order order, List<OrderRequest.Item> items) {
        var existingByProduct = order.getItems().stream()
                .collect(java.util.stream.Collectors.toMap(OrderItem::getProductId, oi -> oi));

        order.getItems().clear();

        BigDecimal total = BigDecimal.ZERO;
        String currency = order.getCurrency();

        for (OrderRequest.Item itemRequest : items) {
            if (itemRequest.quantity() <= 0) {
                throw new ResponseStatusException(BAD_REQUEST, "Quantity must be greater than zero");
            }

            OrderItem resolved = existingByProduct.get(itemRequest.productId());
            String resolvedCurrency = currency;
            if (resolved == null) {
                BigDecimal unitPrice = BigDecimal.TEN;
                String productName = itemRequest.productId();
                String productCurrency = resolvedCurrency != null ? resolvedCurrency : "USD";
                try {
                    var product = catalogClient.fetchProduct(itemRequest.productId());
                    if (!product.active()) {
                        throw new ResponseStatusException(BAD_REQUEST, "Product is not active: " + product.sku());
                    }
                    unitPrice = product.price();
                    productName = product.name();
                    productCurrency = product.currency();
                } catch (Exception ignored) {
                }

                resolvedCurrency = resolvedCurrency != null ? resolvedCurrency : productCurrency;
                if (resolvedCurrency != null && !resolvedCurrency.equalsIgnoreCase(productCurrency)) {
                    throw new ResponseStatusException(BAD_REQUEST, "Mixed currencies not supported");
                }
                resolved = new OrderItem();
                resolved.setProductId(itemRequest.productId());
                resolved.setProductName(productName);
                resolved.setUnitPrice(unitPrice);
            } else {
                resolvedCurrency = resolvedCurrency != null ? resolvedCurrency : order.getCurrency();
            }

            resolved.setQuantity(itemRequest.quantity());
            resolved.setLineTotal(resolved.getUnitPrice().multiply(BigDecimal.valueOf(itemRequest.quantity())));
            order.addItem(resolved);
            total = total.add(resolved.getLineTotal());
            currency = resolvedCurrency;
        }

        String resolvedCurrency = currency != null ? currency : "USD";
        order.setCurrency(resolvedCurrency);
        order.setTotalAmount(total);
    }

    private Order createSeedOrder(SeedOrderSpec spec) {
        Order order = new Order();
        order.setOrderNumber(spec.orderNumber());
        order.setCustomerEmail(spec.customerEmail());
        order.setStatus(OrderStatus.NEW);
        order.setCreatedAt(spec.createdAt());
        order.setUpdatedAt(spec.createdAt());

        OrderItem item = new OrderItem();
        item.setProductId(spec.productId());
        item.setProductName(spec.productName());
        item.setUnitPrice(spec.unitPrice());
        item.setQuantity(spec.quantity());
        item.setLineTotal(spec.unitPrice().multiply(BigDecimal.valueOf(spec.quantity())));
        order.addItem(item);

        order.setCurrency("USD");
        order.setTotalAmount(item.getLineTotal());
        Order saved = orderRepository.save(order);
        recordStatusChangeAt(saved, null, saved.getStatus(), "seeded", spec.createdAt());
        return saved;
    }

    private List<SeedOrderSpec> defaultSeedSpecs() {
        Instant base = Instant.parse("2024-01-01T00:00:00Z");
        return List.of(
                new SeedOrderSpec(
                        "ORD-SEED-00001",
                        "seed+1@acme.test",
                        "11111111-1111-1111-1111-111111111111",
                        "Acme Streamer Pro",
                        new BigDecimal("49.00"),
                        1,
                        base
                ),
                new SeedOrderSpec(
                        "ORD-SEED-00002",
                        "seed+2@acme.test",
                        "22222222-2222-2222-2222-222222222222",
                        "Alerting Add-on",
                        new BigDecimal("19.00"),
                        2,
                        base.plusSeconds(60)
                ),
                new SeedOrderSpec(
                        "ORD-SEED-00003",
                        "seed+3@acme.test",
                        "33333333-3333-3333-3333-333333333333",
                        "Secure Storage 1TB",
                        new BigDecimal("29.00"),
                        1,
                        base.plusSeconds(120)
                )
        );
    }

    private void preloadItems(List<Order> orders) {
        if (orders == null || orders.isEmpty()) {
            return;
        }
        Set<Long> ids = orders.stream()
                .map(Order::getId)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());
        if (ids.isEmpty()) {
            return;
        }
        orderRepository.findAllWithItemsByIds(ids);
    }

    private synchronized String generateOrderNumber() {
        String prefix = "ORD-" + Year.now().getValue() + "-";
        return orderRepository.findTopByOrderNumberStartingWithOrderByOrderNumberDesc(prefix)
                .map(order -> {
                    String numPart = order.getOrderNumber().substring(prefix.length());
                    int next = Integer.parseInt(numPart) + 1;
                    return prefix + String.format("%05d", next);
                })
                .orElse(prefix + "00001");
    }

    private String requestHash(OrderRequest request) {
        StringBuilder builder = new StringBuilder();
        builder.append(Objects.toString(request.customerEmail(), ""));
        builder.append('|');
        builder.append(request.status() != null ? request.status().name() : "");
        builder.append('|');
        if (request.items() != null) {
            request.items().stream()
                    .sorted(Comparator.comparing(OrderRequest.Item::productId)
                            .thenComparingInt(OrderRequest.Item::quantity))
                    .forEach(item -> builder.append(item.productId()).append(':').append(item.quantity()).append(';'));
        }
        return sha256(builder.toString());
    }

    private String sha256(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder(hash.length * 2);
            for (byte b : hash) {
                hex.append(String.format("%02x", b));
            }
            return hex.toString();
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to compute request hash", ex);
        }
    }

    private void recordStatusChange(Order order, OrderStatus oldStatus, OrderStatus newStatus, String reason) {
        OrderStatusHistory history = new OrderStatusHistory();
        history.setOrder(order);
        history.setOldStatus(oldStatus);
        history.setNewStatus(newStatus);
        history.setReason(reason);
        history.setChangedAt(Instant.now());
        historyRepository.save(history);
    }

    private void recordStatusChangeAt(Order order, OrderStatus oldStatus, OrderStatus newStatus, String reason, Instant changedAt) {
        OrderStatusHistory history = new OrderStatusHistory();
        history.setOrder(order);
        history.setOldStatus(oldStatus);
        history.setNewStatus(newStatus);
        history.setReason(reason);
        history.setChangedAt(changedAt);
        historyRepository.save(history);
    }

    private static final class SeedOrderSpec {
        private final String orderNumber;
        private final String customerEmail;
        private final String productId;
        private final String productName;
        private final BigDecimal unitPrice;
        private final int quantity;
        private final Instant createdAt;

        private SeedOrderSpec(String orderNumber,
                              String customerEmail,
                              String productId,
                              String productName,
                              BigDecimal unitPrice,
                              int quantity,
                              Instant createdAt) {
            this.orderNumber = orderNumber;
            this.customerEmail = customerEmail;
            this.productId = productId;
            this.productName = productName;
            this.unitPrice = unitPrice;
            this.quantity = quantity;
            this.createdAt = createdAt;
        }

        private String orderNumber() {
            return orderNumber;
        }

        private String customerEmail() {
            return customerEmail;
        }

        private String productId() {
            return productId;
        }

        private String productName() {
            return productName;
        }

        private BigDecimal unitPrice() {
            return unitPrice;
        }

        private int quantity() {
            return quantity;
        }

        private Instant createdAt() {
            return createdAt;
        }
    }
}
