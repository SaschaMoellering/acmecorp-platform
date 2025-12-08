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
import java.util.Optional;

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

        BigDecimal total = BigDecimal.ZERO;
        String currency = null;

        for (OrderRequest.Item itemRequest : request.items()) {
            if (itemRequest.quantity() <= 0) {
                throw new ResponseStatusException(BAD_REQUEST, "Quantity must be greater than zero");
            }
            var product = catalogClient.fetchProduct(itemRequest.productId());
            if (!product.active()) {
                throw new ResponseStatusException(BAD_REQUEST, "Product is not active: " + product.sku());
            }
            if (currency == null) {
                currency = product.currency();
            } else if (!currency.equalsIgnoreCase(product.currency())) {
                throw new ResponseStatusException(BAD_REQUEST, "Mixed currencies not supported");
            }
            OrderItem item = new OrderItem();
            item.setProductId(product.id());
            item.setProductName(product.name());
            item.setUnitPrice(product.price());
            item.setQuantity(itemRequest.quantity());
            item.setLineTotal(product.price().multiply(BigDecimal.valueOf(itemRequest.quantity())));
            order.addItem(item);
            total = total.add(item.getLineTotal());
        }

        order.setCurrency(Optional.ofNullable(currency).orElse("USD"));
        order.setTotalAmount(total);

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
        Specification<Order> spec = Specification.where(null);
        if (customerEmail != null && !customerEmail.isBlank()) {
            spec = spec.and((root, query, cb) -> cb.like(cb.lower(root.get("customerEmail")), "%" + customerEmail.toLowerCase(Locale.ROOT) + "%"));
        }
        if (status != null) {
            spec = spec.and((root, query, cb) -> cb.equal(root.get("status"), status));
        }
        return orderRepository.findAll(spec, PageRequest.of(page, size));
    }

    @Transactional(readOnly = true)
    public List<Order> latestOrders() {
        return orderRepository.findTop10ByOrderByCreatedAtDesc();
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
}
