package com.acmecorp.gateway.api;

import com.acmecorp.gateway.service.GatewayService;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.reactive.WebFluxTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.web.reactive.server.WebTestClient;
import reactor.core.publisher.Mono;

import java.util.List;
import java.util.Map;

@WebFluxTest(GatewayController.class)
class GatewayControllerTest {

    @Autowired
    private WebTestClient webClient;

    @MockBean
    private GatewayService gatewayService;

    @Test
    void statusEndpointShouldReturnOk() {
        webClient.get()
                .uri("/api/gateway/status")
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$.service").isEqualTo("gateway-service");
    }

    @Test
    void analyticsCountersShouldProxy() {
        Mockito.when(gatewayService.analyticsCounters()).thenReturn(Mono.just(Map.of("orders.created", 5L)));

        webClient.get()
                .uri("/api/gateway/analytics/counters")
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$['orders.created']").isEqualTo(5);
    }

    @Test
    void systemStatusShouldAggregate() {
        Mockito.when(gatewayService.systemStatus())
                .thenReturn(Mono.just(List.of(new GatewayService.SystemStatus("orders-service", "OK"))));

        webClient.get()
                .uri("/api/gateway/system/status")
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$[0].service").isEqualTo("orders-service");
    }

    @Test
    void latestOrdersShouldReturnSummaries() {
        var order = new GatewayService.OrderSummary(1L, "ORD-1", "user@acme.test", "NEW", null, "USD", null, null, List.of());
        Mockito.when(gatewayService.latestOrders()).thenReturn(Mono.just(List.of(order)));

        webClient.get()
                .uri("/api/gateway/orders/latest")
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$[0].orderNumber").isEqualTo("ORD-1")
                .jsonPath("$[0].status").isEqualTo("NEW");
    }

    @Test
    void orderDetailsShouldReturnOrderAndInvoice() {
        var order = new GatewayService.OrderSummary(2L, "ORD-2", "user@acme.test", "CONFIRMED", null, "USD", null, null, List.of());
        var invoice = new GatewayService.InvoiceSummary(3L, "INV-2", 2L, "ORD-2", "user@acme.test", "PAID", "USD", null, null, null);
        Mockito.when(gatewayService.orderDetails(2L)).thenReturn(Mono.just(new GatewayService.OrderWithInvoice(order, invoice)));

        webClient.get()
                .uri("/api/gateway/orders/2")
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$.order.orderNumber").isEqualTo("ORD-2")
                .jsonPath("$.invoice.invoiceNumber").isEqualTo("INV-2");
    }

    @Test
    void catalogShouldReturnProducts() {
        var product = new GatewayService.ProductSummary("1", "SKU-1", "Name", "Desc", "cat", "USD", "9.99", true);
        Mockito.when(gatewayService.catalog("electronics", "phone")).thenReturn(Mono.just(List.of(product)));

        webClient.get()
                .uri(uriBuilder -> uriBuilder.path("/api/gateway/catalog")
                        .queryParam("category", "electronics")
                        .queryParam("search", "phone").build())
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$[0].sku").isEqualTo("SKU-1");

        Mockito.verify(gatewayService).catalog("electronics", "phone");
    }

    @Test
    void proxyOrdersStatusShouldReturnRawBody() {
        Mockito.when(gatewayService.proxyOrdersStatus()).thenReturn(Mono.just("{\"status\":\"OK\"}"));

        webClient.get()
                .uri("/api/gateway/orders")
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$.status").isEqualTo("OK");
    }

    @Test
    void analyticsCountersShouldPropagateErrors() {
        Mockito.when(gatewayService.analyticsCounters()).thenReturn(Mono.error(new RuntimeException("downstream failure")));

        webClient.get()
                .uri("/api/gateway/analytics/counters")
                .exchange()
                .expectStatus().is5xxServerError();
    }
}
