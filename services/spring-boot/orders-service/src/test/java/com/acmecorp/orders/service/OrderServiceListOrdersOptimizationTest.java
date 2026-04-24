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
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
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
    void listOrdersWithoutFiltersUsesOptimizedRepositoryPath() {
        Order order = order("plain@acme.test", OrderStatus.NEW);
        when(orderRepository.findAllByOrderByCreatedAtDescIdDesc(any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(order)));

        var page = orderService.listOrders(null, null, 0, 20);

        assertThat(page.getContent()).containsExactly(order);
        verify(orderRepository).findAllByOrderByCreatedAtDescIdDesc(any(Pageable.class));
        verify(orderRepository, never()).findAll(any(Specification.class), any(Pageable.class));
    }

    @Test
    void listOrdersWithFiltersStillUsesSpecificationPath() {
        Order order = order("filtered@acme.test", OrderStatus.CONFIRMED);
        when(orderRepository.findAll(any(Specification.class), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(order)));

        var page = orderService.listOrders("filtered", OrderStatus.CONFIRMED, 0, 20);

        assertThat(page.getContent()).containsExactly(order);
        verify(orderRepository, never()).findAllByOrderByCreatedAtDescIdDesc(any(Pageable.class));

        @SuppressWarnings("unchecked")
        ArgumentCaptor<Specification<Order>> specCaptor = ArgumentCaptor.forClass(Specification.class);
        verify(orderRepository).findAll(specCaptor.capture(), any(Pageable.class));
        assertThat(specCaptor.getValue()).isNotNull();
    }

    private static Order order(String customerEmail, OrderStatus status) {
        Order order = new Order();
        order.setOrderNumber("ORD-TEST-00001");
        order.setCustomerEmail(customerEmail);
        order.setStatus(status);
        order.setTotalAmount(BigDecimal.TEN);
        order.setCurrency("USD");
        order.setCreatedAt(Instant.now());
        order.setUpdatedAt(order.getCreatedAt());
        return order;
    }
}
