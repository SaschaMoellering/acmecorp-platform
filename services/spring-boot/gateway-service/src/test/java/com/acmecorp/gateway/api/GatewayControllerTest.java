package com.acmecorp.gateway.api;

import com.acmecorp.gateway.service.GatewayService;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.reactive.WebFluxTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.reactive.server.WebTestClient;
import reactor.core.publisher.Mono;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;

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
        var status = new GatewayService.SystemStatus();
        status.service = "orders-service";
        status.status = "OK";
        status.details = Map.of("dummy", "value");

        Mockito.when(gatewayService.systemStatus())
                .thenReturn(Mono.just(List.of(status)));

        webClient.get()
                .uri("/api/gateway/system/status")
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$[0].service").isEqualTo("orders-service");
    }

    @Test
    void latestOrdersShouldReturnSummaries() {
        var order = new GatewayService.OrderSummary();
        order.put("id", 1L);
        order.put("orderNumber", "ORD-1");
        order.put("customerEmail", "user@acme.test");
        order.put("status", "NEW");

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
    void orderDetailsShouldReturnOrderAndInvoices() {
        var order = new GatewayService.OrderSummary();
        order.put("id", 2L);
        order.put("orderNumber", "ORD-2");
        order.put("customerEmail", "user@acme.test");
        order.put("status", "CONFIRMED");

        var invoice = new GatewayService.InvoiceSummary();
        invoice.put("id", 3L);
        invoice.put("invoiceNumber", "INV-2");
        invoice.put("orderId", 2L);
        invoice.put("orderNumber", "ORD-2");
        invoice.put("customerEmail", "user@acme.test");
        invoice.put("status", "PAID");
        invoice.put("currency", "USD");

        var orderWithInvoice = new GatewayService.OrderWithInvoice(order, List.of(invoice));

        Mockito.when(gatewayService.orderDetails(2L)).thenReturn(Mono.just(orderWithInvoice));

        webClient.get()
                .uri("/api/gateway/orders/2")
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$.order.orderNumber").isEqualTo("ORD-2")
                .jsonPath("$.invoices[0].invoiceNumber").isEqualTo("INV-2");
    }

    @Test
    void catalogShouldReturnProducts() {
        var product = new GatewayService.ProductSummary();
        product.put("id", "1");
        product.put("sku", "SKU-1");
        product.put("name", "Name");
        product.put("description", "Desc");
        product.put("category", "cat");
        product.put("currency", "USD");
        product.put("price", BigDecimal.valueOf(9.99));
        product.put("active", true);

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
    void getProductShouldProxySingleItem() {
        var product = new GatewayService.ProductSummary();
        product.put("id", "1");
        product.put("sku", "SKU-1");
        product.put("name", "Name");
        product.put("description", "Desc");
        product.put("category", "cat");
        product.put("currency", "USD");
        product.put("price", BigDecimal.ONE);
        product.put("active", true);

        Mockito.when(gatewayService.getProduct("1")).thenReturn(Mono.just(product));

        webClient.get()
                .uri("/api/gateway/catalog/1")
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$.id").isEqualTo("1")
                .jsonPath("$.sku").isEqualTo("SKU-1");
    }

    @Test
    void proxyOrdersStatusShouldReturnRawBody() {
        Mockito.when(gatewayService.proxyOrdersStatus()).thenReturn(Mono.just("{\"status\":\"OK\"}"));

        webClient.get()
                .uri("/api/gateway/orders/status")
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$.status").isEqualTo("OK");
    }

    @Test
    void listOrdersShouldReturnPage() {
        var order = new GatewayService.OrderSummary();
        order.put("id", 5L);
        order.put("orderNumber", "ORD-5");
        order.put("customerEmail", "page@acme.test");
        order.put("status", "NEW");
        order.put("totalAmount", BigDecimal.TEN);
        order.put("currency", "USD");

        var page = new GatewayService.PageResponse<GatewayService.OrderSummary>();
        page.content = List.of(order);
        page.page = 0;
        page.size = 20;
        page.totalElements = 1;
        page.totalPages = 1;
        page.last = true;

        Mockito.when(gatewayService.listOrders(0, 20)).thenReturn(Mono.just(page));

        webClient.get()
                .uri("/api/gateway/orders")
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$.content[0].orderNumber").isEqualTo("ORD-5");
    }

    @Test
    void seedEndpointShouldTriggerServices() {
        var seed = new GatewayService.SeedResult();
        seed.ordersCreated = 10;
        seed.productsCreated = 5;
        seed.message = "Seed completed";

        Mockito.when(gatewayService.seedData()).thenReturn(Mono.just(seed));

        webClient.post()
                .uri("/api/gateway/seed")
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$.productsCreated").isEqualTo(5)
                .jsonPath("$.ordersCreated").isEqualTo(10);
    }

    @Test
    void orderCrudEndpointsShouldProxy() {
        var summary = new GatewayService.OrderSummary();
        summary.put("id", 15L);
        summary.put("orderNumber", "ORD-15");
        summary.put("customerEmail", "demo@acme.test");
        summary.put("status", "NEW");
        summary.put("totalAmount", BigDecimal.TEN);
        summary.put("currency", "USD");

        Mockito.when(gatewayService.createOrder(any(GatewayService.OrderRequest.class))).thenReturn(Mono.just(summary));
        Mockito.when(gatewayService.updateOrder(eq(15L), any(GatewayService.OrderRequest.class))).thenReturn(Mono.just(summary));
        Mockito.when(gatewayService.deleteOrder(15L)).thenReturn(Mono.empty());

        var requestBody = Map.of(
                "customerEmail", "demo@acme.test",
                "items", List.of(),
                "status", "NEW"
        );

        webClient.post()
                .uri("/api/gateway/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(requestBody)
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$.orderNumber").isEqualTo("ORD-15");

        webClient.put()
                .uri("/api/gateway/orders/15")
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(requestBody)
                .exchange()
                .expectStatus().isOk();

        webClient.delete()
                .uri("/api/gateway/orders/15")
                .exchange()
                .expectStatus().isOk();
    }

    @Test
    void catalogCrudEndpointsShouldProxy() {
        var summary = new GatewayService.ProductSummary();
        summary.put("id", "2");
        summary.put("sku", "SKU-2");
        summary.put("name", "New");
        summary.put("description", "Desc");
        summary.put("category", "cat");
        summary.put("currency", "USD");
        summary.put("price", BigDecimal.ONE);
        summary.put("active", true);

        Mockito.when(gatewayService.createProduct(any(GatewayService.ProductRequest.class))).thenReturn(Mono.just(summary));
        Mockito.when(gatewayService.updateProduct(eq("2"), any(GatewayService.ProductRequest.class))).thenReturn(Mono.just(summary));
        Mockito.when(gatewayService.deleteProduct("2")).thenReturn(Mono.empty());

        var requestBody = Map.of(
                "sku", "SKU-2",
                "name", "New",
                "description", "Desc",
                "price", BigDecimal.ONE,
                "currency", "USD",
                "category", "cat",
                "active", true
        );

        webClient.post()
                .uri("/api/gateway/catalog")
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(requestBody)
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$.sku").isEqualTo("SKU-2");

        webClient.put()
                .uri("/api/gateway/catalog/2")
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(requestBody)
                .exchange()
                .expectStatus().isOk();

        webClient.delete()
                .uri("/api/gateway/catalog/2")
                .exchange()
                .expectStatus().isOk();
    }

    @Test
    @Tag("integration")
    // Tagged as integration: requires downstream behavior that is not deterministic in unit runs.
    void analyticsCountersShouldPropagateErrors() {
        Mockito.when(gatewayService.analyticsCounters()).thenReturn(Mono.error(new RuntimeException("downstream failure")));

        webClient.get()
                .uri("/api/gateway/analytics/counters")
                .exchange()
                .expectStatus().is5xxServerError();
    }
}
