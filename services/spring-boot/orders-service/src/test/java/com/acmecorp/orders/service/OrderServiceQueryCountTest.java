package com.acmecorp.orders.service;

import com.acmecorp.orders.client.AnalyticsClient;
import com.acmecorp.orders.client.BillingClient;
import com.acmecorp.orders.client.CatalogClient;
import com.acmecorp.orders.domain.Order;
import com.acmecorp.orders.domain.OrderItem;
import com.acmecorp.orders.domain.OrderStatus;
import com.acmecorp.orders.messaging.NotificationPublisher;
import com.acmecorp.orders.repository.OrderRepository;
import javax.persistence.EntityManagerFactory;
import org.hibernate.SessionFactory;
import org.hibernate.stat.Statistics;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.ActiveProfiles;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE)
@ActiveProfiles("test")
class OrderServiceQueryCountTest {

    @Autowired
    private OrderService orderService;

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private EntityManagerFactory emf;

    @MockBean
    private CatalogClient catalogClient;

    @MockBean
    private BillingClient billingClient;

    @MockBean
    private AnalyticsClient analyticsClient;

    @MockBean
    private NotificationPublisher notificationPublisher;

    private Statistics statistics;

    @BeforeEach
    void setUp() {
        var sessionFactory = emf.unwrap(SessionFactory.class);
        statistics = sessionFactory.getStatistics();
        statistics.setStatisticsEnabled(true);
        orderRepository.deleteAll();
    }

    @Test
    void listOrdersPrefetchesItemsToAvoidNPlusOne() {
        seedOrders(10, 5);
        statistics.clear();

        orderService.listOrders(null, null, 0, 20);

        long queryCount = statistics.getPrepareStatementCount();
        assertThat(queryCount)
                .withFailMessage("Expected <=3 queries but statistics reported %d, indicates N+1", queryCount)
                .isLessThanOrEqualTo(3);
    }

    private void seedOrders(int orderCount, int itemsPerOrder) {
        List<Order> seeds = new ArrayList<>();
        Instant now = Instant.now();
        for (int i = 0; i < orderCount; i++) {
            Order order = new Order();
            order.setOrderNumber(String.format("ORD-SEED-%05d", i));
            order.setCustomerEmail("seed+" + i + "@example.com");
            order.setStatus(OrderStatus.NEW);
            order.setCreatedAt(now.plusSeconds(i));
            order.setUpdatedAt(order.getCreatedAt());

            BigDecimal total = BigDecimal.ZERO;
            for (int j = 1; j <= itemsPerOrder; j++) {
                OrderItem item = new OrderItem();
                item.setProductId("SKU-" + i + "-" + j);
                item.setProductName("Product " + j);
                item.setUnitPrice(BigDecimal.valueOf(10 + j));
                item.setQuantity(j);
                item.setLineTotal(item.getUnitPrice().multiply(BigDecimal.valueOf(j)));
                order.addItem(item);
                total = total.add(item.getLineTotal());
            }
            order.setCurrency("USD");
            order.setTotalAmount(total);
            seeds.add(order);
        }
        orderRepository.saveAll(seeds);
    }
}
