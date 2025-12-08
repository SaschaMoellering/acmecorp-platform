package com.acmecorp.integration;

import org.awaitility.Awaitility;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class BillingNotificationIntegrationTest extends AbstractIntegrationTest {

    @Test
    void confirmingOrderShouldProduceInvoice() {
        var productId = UUID.fromString(fetchCatalogItems().getFirst().get("id").toString());
        long orderId = createOrder("billing@example.com", productId, 1).getLong("id");

        confirmOrder(orderId);

        List<Map<String, Object>> invoices = Awaitility.await()
                .atMost(Duration.ofSeconds(10))
                .pollInterval(Duration.ofSeconds(1))
                .until(() -> findInvoicesForOrder(orderId),
                        list -> list != null && !list.isEmpty());

        assertThat(((Number) invoices.getFirst().get("orderId")).longValue()).isEqualTo(orderId);
    }
}
