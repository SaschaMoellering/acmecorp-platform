package com.acmecorp.orders.service;

import com.acmecorp.orders.client.AnalyticsClient;
import com.acmecorp.orders.client.BillingClient;
import com.acmecorp.orders.client.CatalogClient;
import com.acmecorp.orders.domain.Order;
import com.acmecorp.orders.domain.OrderItem;
import com.acmecorp.orders.domain.OrderStatus;
import com.acmecorp.orders.messaging.NotificationPublisher;
import com.acmecorp.orders.repository.OrderRepository;
import com.acmecorp.orders.web.OrderRequest;
import com.acmecorp.orders.web.OrderResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.Year;
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
public class OrderService {

    private final OrderRepository orderRepository;
    private final CatalogClient catalogClient;
    private final BillingClient billingClient;
    private final AnalyticsClient analyticsClient;
    private final NotificationPublisher notificationPublisher;

    public OrderService(OrderRepository orderRepository,
                        CatalogClient catalogClient,
                        BillingClient billingClient,
                        AnalyticsClient analyticsClient,
                        NotificationPublisher notificationPublisher) {
        this.orderRepository = orderRepository;
        this.catalogClient = catalogClient;
        this.billingClient = billingClient;
        this.analyticsClient = analyticsClient;
        this.notificationPublisher = notificationPublisher;
    }

    @Transactional
    public Order createOrder(OrderRequest request) {
        if (request.items() == null || request.items().isEmpty()) {
            throw new ResponseStatusException(BAD_REQUEST, "Order must contain at least one item");
        }

        Order order = new Order();
        order.setOrderNumber(generateOrderNumber());
        order.setCustomerEmail(request.customerEmail());
        order.setStatus(OrderStatus.NEW);
        order.setCreatedAt(Instant.now());
        order.setUpdatedAt(order.getCreatedAt());

        applyItems(order, request.items());

        Order saved = orderRepository.save(order);
        analyticsClient.track("orders.created", Map.of("orderId", saved.getId(), "orderNumber", saved.getOrderNumber()));
        return saved;
    }

    @Transactional(readOnly = true)
    public Order getOrder(Long id) {
        return orderRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(NOT_FOUND, "Order not found"));
    }

    @Transactional(readOnly = true)
    public Page<Order> listOrders(String customerEmail, OrderStatus status, int page, int size) {
        Specification<Order> spec = (root, query, cb) -> cb.conjunction();
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
        Order order = getOrder(id);
        if (order.getStatus() != OrderStatus.NEW) {
            throw new ResponseStatusException(BAD_REQUEST, "Only NEW orders can be confirmed");
        }
        order.setStatus(OrderStatus.CONFIRMED);
        order.setUpdatedAt(Instant.now());
        Order saved = orderRepository.save(order);

        billingClient.createInvoice(saved);
        analyticsClient.track("orders.confirmed", Map.of("orderId", saved.getId(), "orderNumber", saved.getOrderNumber()));
        notificationPublisher.sendOrderConfirmation(saved.getCustomerEmail(), saved.getOrderNumber());
        return saved;
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
        order.setStatus(OrderStatus.CANCELLED);
        order.setUpdatedAt(Instant.now());
        Order saved = orderRepository.save(order);
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
        analyticsClient.track("orders.updated", Map.of("orderId", saved.getId(), "orderNumber", saved.getOrderNumber()));
        return saved;
    }

    @Transactional
    public void deleteOrder(Long id) {
        Order order = getOrder(id);
        orderRepository.delete(order);
        analyticsClient.track("orders.deleted", Map.of("orderId", order.getId(), "orderNumber", order.getOrderNumber()));
    }

    @Transactional
    public List<OrderResponse> seedDemoData(List<OrderRequest> requests) {
        orderRepository.deleteAll();

        List<OrderRequest> seeds = (requests == null || requests.isEmpty()) ? defaultSeeds() : requests;
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

    private Order createSeedOrder(OrderRequest request) {
        Order order = new Order();
        order.setOrderNumber(generateOrderNumber());
        order.setCustomerEmail(request.customerEmail());
        order.setStatus(Optional.ofNullable(request.status()).orElse(OrderStatus.NEW));
        order.setCreatedAt(Instant.now());
        order.setUpdatedAt(order.getCreatedAt());

        BigDecimal total = BigDecimal.ZERO;
        for (OrderRequest.Item itemRequest : request.items()) {
            OrderItem item = new OrderItem();
            item.setProductId(itemRequest.productId());
            item.setProductName(itemRequest.productId());
            item.setUnitPrice(BigDecimal.TEN);
            item.setQuantity(itemRequest.quantity());
            item.setLineTotal(BigDecimal.TEN.multiply(BigDecimal.valueOf(itemRequest.quantity())));
            order.addItem(item);
            total = total.add(item.getLineTotal());
        }

        order.setCurrency("USD");
        order.setTotalAmount(total);
        return orderRepository.save(order);
    }

    private List<OrderRequest> defaultSeeds() {
        return List.of(
                new OrderRequest("seed+1@acme.test", List.of(new OrderRequest.Item("SKU-1", 1)), OrderStatus.NEW),
                new OrderRequest("seed+2@acme.test", List.of(new OrderRequest.Item("SKU-2", 2)), OrderStatus.CONFIRMED),
                new OrderRequest("seed+3@acme.test", List.of(new OrderRequest.Item("SKU-3", 1)), OrderStatus.CANCELLED)
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
}
