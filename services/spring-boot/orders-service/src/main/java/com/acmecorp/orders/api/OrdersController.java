package com.acmecorp.orders.api;

import com.acmecorp.orders.domain.OrderStatus;
import com.acmecorp.orders.service.OrderService;
import com.acmecorp.orders.web.OrderRequest;
import com.acmecorp.orders.web.OrderResponse;
import com.acmecorp.orders.web.OrderStatusHistoryResponse;
import com.acmecorp.orders.web.PageResponse;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Executors;

@RestController
@RequestMapping("/api/orders")
public class OrdersController {

    private final OrderService orderService;

    public OrdersController(OrderService orderService) {
        this.orderService = orderService;
    }

    @GetMapping("/status")
    public Map<String, Object> status() {
        return Map.of(
                "service", "orders-service",
                "status", "OK"
        );
    }

    @PostMapping
    public ResponseEntity<OrderResponse> createOrder(@Valid @RequestBody OrderRequest request,
                                                     @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey) {
        var order = orderService.createOrder(request, idempotencyKey);
        return ResponseEntity.ok(OrderResponse.from(order));
    }

    @PutMapping("/{id}")
    public ResponseEntity<OrderResponse> updateOrder(@PathVariable("id") Long id,
                                                     @RequestBody OrderRequest request) {
        var order = orderService.updateOrder(id, request);
        return ResponseEntity.ok(OrderResponse.from(order));
    }

    @GetMapping("/{id}")
    public OrderResponse getOrder(@PathVariable("id") Long id) {
        return orderService.toResponse(orderService.getOrder(id));
    }

    @GetMapping("/{id}/history")
    public List<OrderStatusHistoryResponse> history(@PathVariable("id") Long id) {
        return orderService.history(id);
    }

    @GetMapping
    public PageResponse<OrderResponse> listOrders(@RequestParam(name = "customerEmail", required = false) String customerEmail,
                                                  @RequestParam(name = "status", required = false) OrderStatus status,
                                                  @RequestParam(name = "page", defaultValue = "0") int page,
                                                  @RequestParam(name = "size", defaultValue = "20") int size) {
        var ordersPage = orderService.listOrders(customerEmail, status, page, size);
        var responses = ordersPage.getContent().stream().map(OrderResponse::from).toList();
        return PageResponse.from(new PageImpl<>(responses, PageRequest.of(page, size), ordersPage.getTotalElements()));
    }

    @PostMapping("/{id}/confirm")
    public OrderResponse confirm(@PathVariable("id") Long id) {
        return OrderResponse.from(orderService.confirm(id));
    }

    @PostMapping("/{id}/cancel")
    public OrderResponse cancel(@PathVariable("id") Long id) {
        return OrderResponse.from(orderService.cancel(id));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable("id") Long id) {
        orderService.deleteOrder(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/latest")
    public List<OrderResponse> latest() {
        return orderService.toResponses(orderService.latestOrders());
    }

    @GetMapping("/demo/nplus1")
    public List<OrderResponse> nPlusOneDemo(@RequestParam(name = "limit", defaultValue = "20") int limit) {
        return orderService.listOrdersNPlusOneDemo(limit);
    }

    @PostMapping("/seed")
    public Map<String, Object> seed() {
        var seeded = orderService.seedDemoData();
        int count = seeded == null ? 0 : seeded.size();
        return Map.of(
                "seeded", true,
                "count", count
        );
    }

    @GetMapping("/vt")
    public Page<OrderResponse> listOrdersWithVirtualThreads(@RequestParam(name = "customerEmail", required = false) String customerEmail,
                                                            @RequestParam(name = "status", required = false) OrderStatus status,
                                                            @RequestParam(name = "page", defaultValue = "0") int page,
                                                            @RequestParam(name = "size", defaultValue = "20") int size) throws ExecutionException, InterruptedException {
        try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
            var task = executor.submit(() -> orderService.listOrders(customerEmail, status, page, size));
            var ordersPage = task.get();
            var responses = ordersPage.getContent().stream().map(OrderResponse::from).toList();
            return new PageImpl<>(responses, PageRequest.of(page, size), ordersPage.getTotalElements());
        }
    }
}
