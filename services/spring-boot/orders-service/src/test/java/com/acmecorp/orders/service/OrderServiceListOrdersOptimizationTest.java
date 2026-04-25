package com.acmecorp.orders.service;

import com.acmecorp.orders.client.AnalyticsClient;
import com.acmecorp.orders.client.BillingClient;
import com.acmecorp.orders.client.CatalogClient;
import com.acmecorp.orders.domain.Order;
import com.acmecorp.orders.domain.OrderStatus;
import com.acmecorp.orders.messaging.NotificationPublisher;
import com.acmecorp.orders.repository.OrderIdempotencyRepository;
import com.acmecorp.orders.repository.OrderRepository;
import com.acmecorp.orders.repository.OrderStatusHistoryRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;

import java.time.Instant;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class OrderServiceListOrdersOptimizationTest {

    @Mock
    private OrderRepository orderRepository;

    @Mock
    private OrderIdempotencyRepository idempotencyRepository;

    @Mock
    private OrderStatusHistoryRepository historyRepository;

    @Mock
    private CatalogClient catalogClient;

    @Mock
    private BillingClient billingClient;

    @Mock
    private AnalyticsClient analyticsClient;

    @Mock
    private NotificationPublisher notificationPublisher;

    @InjectMocks
    private OrderService orderService;

    @Test
    void unfilteredListUsesOptimizedRepositoryPath() {
        when(orderRepository.findAllByOrderByCreatedAtDescIdDesc(any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(order("ORD-1"))));

        orderService.listOrders(null, null, 0, 20);

        verify(orderRepository).findAllByOrderByCreatedAtDescIdDesc(any(Pageable.class));
        verify(orderRepository, never()).findAll(any(Specification.class), any(Pageable.class));
    }

    @Test
    void filteredListUsesSpecificationPath() {
        when(orderRepository.findAll(any(Specification.class), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(order("ORD-2"))));

        orderService.listOrders("customer@acme.test", OrderStatus.NEW, 0, 20);

        verify(orderRepository).findAll(any(Specification.class), any(Pageable.class));
        verify(orderRepository, never()).findAllByOrderByCreatedAtDescIdDesc(any(Pageable.class));
    }

    private static Order order(String orderNumber) {
        Order order = new Order();
        order.setOrderNumber(orderNumber);
        order.setCustomerEmail("customer@acme.test");
        order.setStatus(OrderStatus.NEW);
        order.setCreatedAt(Instant.now());
        order.setUpdatedAt(order.getCreatedAt());
        return order;
    }
}
