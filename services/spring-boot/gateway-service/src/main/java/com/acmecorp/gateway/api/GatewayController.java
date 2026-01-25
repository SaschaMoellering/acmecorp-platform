package com.acmecorp.gateway.api;

import com.acmecorp.gateway.service.GatewayService;
import com.acmecorp.gateway.service.GatewayService.OrderRequest;
import com.acmecorp.gateway.service.GatewayService.OrderSummary;
import com.acmecorp.gateway.service.GatewayService.OrderWithInvoice;
import com.acmecorp.gateway.service.GatewayService.PageResponse;
import com.acmecorp.gateway.service.GatewayService.ProductRequest;
import com.acmecorp.gateway.service.GatewayService.ProductSummary;
import com.acmecorp.gateway.service.GatewayService.SeedResult;
import com.acmecorp.gateway.service.GatewayService.SystemStatus;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import reactor.core.publisher.Mono;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping(path = "/api/gateway", produces = MediaType.APPLICATION_JSON_VALUE)
public class GatewayController {

    private final GatewayService gatewayService;

    public GatewayController(GatewayService gatewayService) {
        this.gatewayService = gatewayService;
    }

    // -------------------------------------------------------------------------
    // Orders
    // -------------------------------------------------------------------------

    @GetMapping("/orders")
    public Mono<PageResponse<OrderSummary>> listOrders(
            @RequestParam(name = "page", defaultValue = "0") int page,
            @RequestParam(name = "size", defaultValue = "20") int size) {
        return gatewayService.listOrders(page, size);
    }

    @PostMapping(path = "/orders", consumes = MediaType.APPLICATION_JSON_VALUE)
    @Operation(
            summary = "Create an order",
            description = "Creates a new order. If Idempotency-Key is provided, repeated requests with the same key and payload return the same order."
    )
    @ApiResponses({
            @ApiResponse(
                    responseCode = "200",
                    description = "Order created or replayed",
                    content = @Content(
                            mediaType = MediaType.APPLICATION_JSON_VALUE,
                            schema = @Schema(implementation = OrderSummary.class),
                            examples = @ExampleObject(value = """
                                    {
                                      "id": 42,
                                      "orderNumber": "ORD-2025-00001",
                                      "customerEmail": "customer@example.com",
                                      "status": "NEW",
                                      "totalAmount": 29.00,
                                      "currency": "USD",
                                      "createdAt": "2025-01-01T12:00:00Z",
                                      "updatedAt": "2025-01-01T12:00:00Z",
                                      "items": [
                                        {"productId":"11111111-1111-1111-1111-111111111111","quantity":1}
                                      ]
                                    }
                                    """)
                    )
            ),
            @ApiResponse(
                    responseCode = "400",
                    description = "Validation error",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE, schema = @Schema(implementation = com.acmecorp.gateway.api.error.ApiErrorResponse.class))
            ),
            @ApiResponse(
                    responseCode = "404",
                    description = "Resource not found",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE, schema = @Schema(implementation = com.acmecorp.gateway.api.error.ApiErrorResponse.class))
            ),
            @ApiResponse(
                    responseCode = "409",
                    description = "Idempotency key conflict",
                    content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE, schema = @Schema(implementation = com.acmecorp.gateway.api.error.ApiErrorResponse.class))
            )
    })
    public Mono<OrderSummary> createOrder(
            @io.swagger.v3.oas.annotations.parameters.RequestBody(
                    required = true,
                    content = @Content(
                            mediaType = MediaType.APPLICATION_JSON_VALUE,
                            schema = @Schema(implementation = OrderRequest.class),
                            examples = @ExampleObject(value = """
                                    {
                                      "customerEmail": "customer@example.com",
                                      "items": [
                                        {"productId":"11111111-1111-1111-1111-111111111111","quantity":1}
                                      ]
                                    }
                                    """)
                    )
            ) @RequestBody OrderRequest request,
            @Parameter(
                    description = "Optional idempotency key to safely retry order creation",
                    required = false,
                    example = "0f1f7a3d-8c6d-4c9b-9a3d-2d6f4f8e6b11"
            )
            @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey) {
        return gatewayService.createOrder(request, idempotencyKey);
    }

    @PutMapping(path = "/orders/{id}", consumes = MediaType.APPLICATION_JSON_VALUE)
    public Mono<OrderSummary> updateOrder(@PathVariable("id") Long id,
                                          @RequestBody OrderRequest request) {
        return gatewayService.updateOrder(id, request);
    }

    @DeleteMapping("/orders/{id}")
    public Mono<Map<String, Object>> deleteOrder(@PathVariable("id") Long id) {
        return gatewayService.deleteOrder(id);
    }

    @PostMapping("/orders/{id}/confirm")
    public Mono<OrderSummary> confirmOrder(@PathVariable("id") Long id) {
        return gatewayService.confirmOrder(id);
    }

    @PostMapping("/orders/{id}/cancel")
    public Mono<OrderSummary> cancelOrder(@PathVariable("id") Long id) {
        return gatewayService.cancelOrder(id);
    }

    @GetMapping("/orders/status")
    public Mono<String> proxyOrdersStatus() {
        return gatewayService.proxyOrdersStatus();
    }

    @GetMapping("/orders/latest")
    public Mono<List<OrderSummary>> latestOrders() {
        return gatewayService.latestOrders();
    }

    @GetMapping("/orders/{id}")
    public Mono<OrderWithInvoice> orderDetails(@PathVariable("id") Long id,
                                               @RequestParam(name = "includeHistory", defaultValue = "false") boolean includeHistory) {
        return gatewayService.orderDetails(id, includeHistory);
    }

    @GetMapping("/orders/{id}/history")
    public Mono<List<Map<String, Object>>> orderHistory(@PathVariable("id") Long id) {
        return gatewayService.orderHistory(id);
    }

    // -------------------------------------------------------------------------
    // Catalog
    // -------------------------------------------------------------------------

    @GetMapping("/catalog")
    public Mono<List<ProductSummary>> catalog(
            @RequestParam(name = "category", required = false) String category,
            @RequestParam(name = "search", required = false) String search) {
        return gatewayService.catalog(category, search);
    }

    @GetMapping("/catalog/{id}")
    public Mono<ProductSummary> getProduct(@PathVariable("id") String id) {
        return gatewayService.getProduct(id);
    }

    @GetMapping("/catalog/raw")
    public Mono<String> proxyCatalog() {
        return gatewayService.proxyCatalogRaw();
    }

    @PostMapping(path = "/catalog", consumes = MediaType.APPLICATION_JSON_VALUE)
    public Mono<ProductSummary> createProduct(@RequestBody ProductRequest request) {
        return gatewayService.createProduct(request);
    }

    @PutMapping(path = "/catalog/{id}", consumes = MediaType.APPLICATION_JSON_VALUE)
    public Mono<ProductSummary> updateProduct(@PathVariable("id") String id,
                                              @RequestBody ProductRequest request) {
        return gatewayService.updateProduct(id, request);
    }

    @DeleteMapping("/catalog/{id}")
    public Mono<Map<String, Object>> deleteProduct(@PathVariable("id") String id) {
        return gatewayService.deleteProduct(id);
    }

    // -------------------------------------------------------------------------
    // Analytics / system
    // -------------------------------------------------------------------------

    @GetMapping("/analytics/counters")
    public Mono<Map<String, Long>> analyticsCounters() {
        return gatewayService.analyticsCounters()
                .onErrorMap(ex -> new org.springframework.web.server.ResponseStatusException(
                        HttpStatus.BAD_GATEWAY,
                        "Downstream analytics failure",
                        ex
                ));
    }

    @GetMapping("/system/status")
    public Mono<List<SystemStatus>> systemStatus() {
        return gatewayService.systemStatus();
    }

    @PostMapping("/seed")
    public Mono<SeedResult> seed() {
        return gatewayService.seedData();
    }

    @PostMapping("/tools/seed")
    public Mono<SeedResult> toolsSeed() {
        return gatewayService.seedData();
    }

    // Simple health/status endpoint (non-reactive is fine here)
    @GetMapping("/status")
    public Map<String, Object> status() {
        return Map.of(
                "service", "gateway-service",
                "status", "OK"
        );
    }
}
