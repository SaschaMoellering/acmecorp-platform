package com.acmecorp.orders.service;

import com.acmecorp.orders.client.AnalyticsClient;
import com.acmecorp.orders.client.BillingClient;
import com.acmecorp.orders.client.CatalogClient;
import com.acmecorp.orders.messaging.NotificationPublisher;
import com.acmecorp.orders.repository.OrderIdempotencyRepository;
import com.acmecorp.orders.repository.OrderRepository;
import com.acmecorp.orders.repository.OrderStatusHistoryRepository;
import com.acmecorp.orders.web.OrderResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE)
@ActiveProfiles("test")
class OrderServiceSeedDataTest {

    @Autowired
    private OrderService orderService;

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private OrderStatusHistoryRepository historyRepository;

    @Autowired
    private OrderIdempotencyRepository idempotencyRepository;

    @MockitoBean
    private CatalogClient catalogClient;

    @MockitoBean
    private BillingClient billingClient;

    @MockitoBean
    private AnalyticsClient analyticsClient;

    @MockitoBean
    private NotificationPublisher notificationPublisher;

    @BeforeEach
    void setUp() {
        historyRepository.deleteAll();
        idempotencyRepository.deleteAll();
        orderRepository.deleteAll();
    }

    @Test
    void seedDemoDataShouldCreateOrdersWithFiveToThirtyItemsAndAccurateTotals() {
        List<OrderResponse> seeded = orderService.seedDemoData(20);

        assertThat(seeded).hasSize(20);
        assertThat(seeded)
                .allSatisfy(order -> assertThat(order.items().size()).isBetween(5, 30))
                .allSatisfy(order -> {
                    BigDecimal computedTotal = order.items().stream()
                            .map(OrderResponse.OrderItemResponse::lineTotal)
                            .reduce(BigDecimal.ZERO, BigDecimal::add);
                    assertThat(order.totalAmount()).isEqualByComparingTo(computedTotal);
                });
    }

    @Test
    void seedDemoDataShouldBeIdempotentAcrossRepeatedCalls() {
        orderService.seedDemoData(20);
        List<OrderResponse> reseeded = orderService.seedDemoData(20);

        assertThat(orderRepository.count()).isEqualTo(20);
        assertThat(reseeded).hasSize(20);
        assertThat(reseeded)
                .allSatisfy(order -> assertThat(order.items().size()).isBetween(5, 30));

        int minItems = reseeded.stream().mapToInt(order -> order.items().size()).min().orElseThrow();
        int maxItems = reseeded.stream().mapToInt(order -> order.items().size()).max().orElseThrow();
        assertThat(minItems).isGreaterThanOrEqualTo(5);
        assertThat(maxItems).isLessThanOrEqualTo(30);
    }

    @Test
    void seedDemoDataShouldRejectNonPositiveOrderCount() {
        assertThatThrownBy(() -> orderService.seedDemoData(0))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("orderCount must be greater than 0");
    }
}
