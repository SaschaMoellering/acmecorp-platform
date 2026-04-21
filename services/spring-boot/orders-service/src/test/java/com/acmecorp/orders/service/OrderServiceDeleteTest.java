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
import com.acmecorp.orders.web.OrderRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE)
@ActiveProfiles("test")
class OrderServiceDeleteTest {

    @Autowired
    private OrderService orderService;

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private OrderStatusHistoryRepository historyRepository;

    @Autowired
    private OrderIdempotencyRepository idempotencyRepository;

    @MockBean
    private CatalogClient catalogClient;

    @MockBean
    private BillingClient billingClient;

    @MockBean
    private AnalyticsClient analyticsClient;

    @MockBean
    private NotificationPublisher notificationPublisher;

    @BeforeEach
    void setUp() {
        historyRepository.deleteAll();
        idempotencyRepository.deleteAll();
        orderRepository.deleteAll();
    }

    @Test
    void deleteOrderShouldRemoveDependentHistoryAndIdempotencyRecords() {
        String idempotencyKey = "delete-test-key-1";
        OrderRequest request = new OrderRequest(
                "delete-me@acme.test",
                List.of(new OrderRequest.Item("SKU-DELETE-1", 1)),
                OrderStatus.NEW
        );

        Order created = orderService.createOrder(request, idempotencyKey);
        Long orderId = created.getId();

        assertThat(historyRepository.findByOrderIdOrderByChangedAtAsc(orderId)).isNotEmpty();
        assertThat(idempotencyRepository.findByIdempotencyKey(idempotencyKey)).isPresent();

        orderService.deleteOrder(orderId);

        assertThat(orderRepository.findById(orderId)).isEmpty();
        assertThat(historyRepository.findByOrderIdOrderByChangedAtAsc(orderId)).isEmpty();
        assertThat(idempotencyRepository.findByIdempotencyKey(idempotencyKey)).isEmpty();
    }

    @Test
    void deleteOrderShouldReturnNotFoundForUnknownOrder() {
        assertThatThrownBy(() -> orderService.deleteOrder(999_999L))
                .isInstanceOf(ResponseStatusException.class)
                .extracting(ex -> ((ResponseStatusException) ex).getStatusCode().value())
                .isEqualTo(404);
    }
}
