package com.acmecorp.gateway.api;

import com.acmecorp.gateway.service.GatewayService;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.reactive.WebFluxTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.reactive.server.EntityExchangeResult;
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
        var response = webClient.get()
                .uri("/api/gateway/status")
                .exchange()
                .expectStatus().isOk();

        String body = expectBody(response, "statusEndpointShouldReturnOk GET /api/gateway/status");
        assertJsonEquals(body, "$.service", "gateway-service", "statusEndpointShouldReturnOk");
    }

    @Test
    void analyticsCountersShouldProxy() {
        Mockito.when(gatewayService.analyticsCounters()).thenReturn(Mono.just(Map.of("orders.created", 5L)));

        var response = webClient.get()
                .uri("/api/gateway/analytics/counters")
                .exchange()
                .expectStatus().isOk();

        String body = expectBody(response, "analyticsCountersShouldProxy GET /api/gateway/analytics/counters");
        assertJsonEquals(body, "$['orders.created']", 5, "analyticsCountersShouldProxy");
    }

    @Test
    void systemStatusShouldAggregate() {
        var status = new GatewayService.SystemStatus();
        status.service = "orders-service";
        status.status = "OK";
        status.details = Map.of("dummy", "value");

        Mockito.when(gatewayService.systemStatus())
                .thenReturn(Mono.just(List.of(status)));

        var response = webClient.get()
                .uri("/api/gateway/system/status")
                .exchange()
                .expectStatus().isOk();

        String body = expectBody(response, "systemStatusShouldAggregate GET /api/gateway/system/status");
        assertJsonEquals(body, "$[0].service", "orders-service", "systemStatusShouldAggregate");
    }

    @Test
    void latestOrdersShouldReturnSummaries() {
        var order = new GatewayService.OrderSummary();
        order.put("id", 1L);
        order.put("orderNumber", "ORD-1");
        order.put("customerEmail", "user@acme.test");
        order.put("status", "NEW");

        Mockito.when(gatewayService.latestOrders()).thenReturn(Mono.just(List.of(order)));

        var response = webClient.get()
                .uri("/api/gateway/orders/latest")
                .exchange()
                .expectStatus().isOk();

        String body = expectBody(response, "latestOrdersShouldReturnSummaries GET /api/gateway/orders/latest");
        assertJsonEquals(body, "$[0].orderNumber", "ORD-1", "latestOrdersShouldReturnSummaries");
        assertJsonEquals(body, "$[0].status", "NEW", "latestOrdersShouldReturnSummaries");
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

        Mockito.when(gatewayService.orderDetails(2L, false)).thenReturn(Mono.just(orderWithInvoice));

        var response = webClient.get()
                .uri("/api/gateway/orders/2")
                .exchange()
                .expectStatus().isOk();

        String body = expectBody(response, "orderDetailsShouldReturnOrderAndInvoices GET /api/gateway/orders/2");
        assertJsonEquals(body, "$.order.orderNumber", "ORD-2", "orderDetailsShouldReturnOrderAndInvoices");
        assertJsonEquals(body, "$.invoices[0].invoiceNumber", "INV-2", "orderDetailsShouldReturnOrderAndInvoices");
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

        var response = webClient.get()
                .uri(uriBuilder -> uriBuilder.path("/api/gateway/catalog")
                        .queryParam("category", "electronics")
                        .queryParam("search", "phone").build())
                .exchange()
                .expectStatus().isOk();

        String body = expectBody(response, "catalogShouldReturnProducts GET /api/gateway/catalog");
        assertJsonEquals(body, "$[0].sku", "SKU-1", "catalogShouldReturnProducts");

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

        var response = webClient.get()
                .uri("/api/gateway/catalog/1")
                .exchange()
                .expectStatus().isOk();

        String body = expectBody(response, "getProductShouldProxySingleItem GET /api/gateway/catalog/1");
        assertJsonEquals(body, "$.id", "1", "getProductShouldProxySingleItem");
        assertJsonEquals(body, "$.sku", "SKU-1", "getProductShouldProxySingleItem");
    }

    @Test
    void proxyOrdersStatusShouldReturnRawBody() {
        Mockito.when(gatewayService.proxyOrdersStatus()).thenReturn(Mono.just("{\"status\":\"OK\"}"));

        var response = webClient.get()
                .uri("/api/gateway/orders/status")
                .exchange()
                .expectStatus().isOk();

        String body = expectBody(response, "proxyOrdersStatusShouldReturnRawBody GET /api/gateway/orders/status");
        assertJsonEquals(body, "$.status", "OK", "proxyOrdersStatusShouldReturnRawBody");
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

        var response = webClient.get()
                .uri("/api/gateway/orders")
                .exchange()
                .expectStatus().isOk();

        String body = expectBody(response, "listOrdersShouldReturnPage GET /api/gateway/orders");
        assertJsonEquals(body, "$.content[0].orderNumber", "ORD-5", "listOrdersShouldReturnPage");
    }

    @Test
    void seedEndpointShouldTriggerServices() {
        var seed = new GatewayService.SeedResult();
        seed.ordersSeeded = 10;
        seed.catalogSeeded = 5;

        Mockito.when(gatewayService.seedData()).thenReturn(Mono.just(seed));

        var response = webClient.post()
                .uri("/api/gateway/seed")
                .exchange()
                .expectStatus().isOk();

        String body = expectBody(response, "seedEndpointShouldTriggerServices POST /api/gateway/seed");
        assertJsonEquals(body, "$.catalogSeeded", 5, "seedEndpointShouldTriggerServices");
        assertJsonEquals(body, "$.ordersSeeded", 10, "seedEndpointShouldTriggerServices");
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

        Mockito.when(gatewayService.createOrder(any(GatewayService.OrderRequest.class), Mockito.nullable(String.class)))
                .thenReturn(Mono.just(summary));
        Mockito.when(gatewayService.updateOrder(eq(15L), any(GatewayService.OrderRequest.class))).thenReturn(Mono.just(summary));
        Mockito.when(gatewayService.deleteOrder(15L)).thenReturn(Mono.just(Map.of("deleted", true, "orderId", 15L)));

        var requestBody = Map.of(
                "customerEmail", "demo@acme.test",
                "items", List.of(),
                "status", "NEW"
        );

        var createResponse = webClient.post()
                .uri("/api/gateway/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(requestBody)
                .exchange()
                .expectStatus().isOk();

        String createBody = expectBody(createResponse, "orderCrudEndpointsShouldProxy POST /api/gateway/orders");
        assertJsonEquals(createBody, "$.orderNumber", "ORD-15", "orderCrudEndpointsShouldProxy");

        var updateResponse = webClient.put()
                .uri("/api/gateway/orders/15")
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(requestBody)
                .exchange()
                .expectStatus().isOk();

        String updateBody = expectBody(updateResponse, "orderCrudEndpointsShouldProxy PUT /api/gateway/orders/15");
        assertJsonNotEmpty(updateBody, "orderCrudEndpointsShouldProxy PUT /api/gateway/orders/15");

        var deleteResponse = webClient.delete()
                .uri("/api/gateway/orders/15")
                .exchange()
                .expectStatus().isOk();

        String deleteBody = expectBody(deleteResponse, "orderCrudEndpointsShouldProxy DELETE /api/gateway/orders/15");
        assertJsonEquals(deleteBody, "$.deleted", true, "orderCrudEndpointsShouldProxy");
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
        Mockito.when(gatewayService.deleteProduct("2")).thenReturn(Mono.just(Map.of("deleted", true, "productId", "2")));

        var requestBody = Map.of(
                "sku", "SKU-2",
                "name", "New",
                "description", "Desc",
                "price", BigDecimal.ONE,
                "currency", "USD",
                "category", "cat",
                "active", true
        );

        var createResponse = webClient.post()
                .uri("/api/gateway/catalog")
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(requestBody)
                .exchange()
                .expectStatus().isOk();

        String createBody = expectBody(createResponse, "catalogCrudEndpointsShouldProxy POST /api/gateway/catalog");
        assertJsonEquals(createBody, "$.sku", "SKU-2", "catalogCrudEndpointsShouldProxy");

        var updateResponse = webClient.put()
                .uri("/api/gateway/catalog/2")
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(requestBody)
                .exchange()
                .expectStatus().isOk();

        String updateBody = expectBody(updateResponse, "catalogCrudEndpointsShouldProxy PUT /api/gateway/catalog/2");
        assertJsonNotEmpty(updateBody, "catalogCrudEndpointsShouldProxy PUT /api/gateway/catalog/2");

        var deleteResponse = webClient.delete()
                .uri("/api/gateway/catalog/2")
                .exchange()
                .expectStatus().isOk();

        String deleteBody = expectBody(deleteResponse, "catalogCrudEndpointsShouldProxy DELETE /api/gateway/catalog/2");
        assertJsonEquals(deleteBody, "$.deleted", true, "catalogCrudEndpointsShouldProxy");
    }

    @Test
    void analyticsCountersShouldPropagateErrors() {
        Mockito.when(gatewayService.analyticsCounters()).thenReturn(Mono.error(new RuntimeException("downstream failure")));

        webClient.get()
                .uri("/api/gateway/analytics/counters")
                .exchange()
                .expectStatus().isEqualTo(502);
    }

    private String expectBody(WebTestClient.ResponseSpec spec, String context) {
        EntityExchangeResult<String> result = spec.expectBody(String.class).returnResult();
        String body = result.getResponseBody();
        return assertJsonNotEmpty(body, context + " status=" + result.getStatus() + " body=" + body);
    }

    private static String assertJsonNotEmpty(String body, String context) {
        if (body == null || body.isBlank()) {
            Assertions.fail("Empty response body: " + context);
        }
        return body;
    }

    private static void assertJsonEquals(String body, String path, Object expected, String context) {
        Object actual = readJson(body, path, context);
        Assertions.assertEquals(expected, actual, context + " jsonPath=" + path + " body=" + body);
    }

    private static Object readJson(String body, String path, String context) {
        try {
            return JsonPath.read(body, path);
        } catch (Exception ex) {
            Assertions.fail("Missing JSON path " + path + " for " + context + " body=" + body, ex);
            return null;
        }
    }
}
