package com.acmecorp.orders.api;

import com.acmecorp.orders.domain.OrderStatus;
import com.acmecorp.orders.service.OrderService;
import com.acmecorp.orders.web.OrderRequest;
import com.acmecorp.orders.web.OrderResponse;
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
    public ResponseEntity<OrderResponse> createOrder(@Valid @RequestBody OrderRequest request) {
        var order = orderService.createOrder(request);
        return ResponseEntity.ok(OrderResponse.from(order));
    }

    @GetMapping("/{id}")
    public OrderResponse getOrder(@PathVariable Long id) {
        return orderService.toResponse(orderService.getOrder(id));
    }

    @GetMapping
    public Page<OrderResponse> listOrders(@RequestParam(required = false) String customerEmail,
                                          @RequestParam(required = false) OrderStatus status,
                                          @RequestParam(defaultValue = "0") int page,
                                          @RequestParam(defaultValue = "20") int size) {
        var ordersPage = orderService.listOrders(customerEmail, status, page, size);
        var responses = ordersPage.getContent().stream().map(OrderResponse::from).toList();
        return new PageImpl<>(responses, PageRequest.of(page, size), ordersPage.getTotalElements());
    }

    @PostMapping("/{id}/confirm")
    public OrderResponse confirm(@PathVariable Long id) {
        return OrderResponse.from(orderService.confirm(id));
    }

    @PostMapping("/{id}/cancel")
    public OrderResponse cancel(@PathVariable Long id) {
        return OrderResponse.from(orderService.cancel(id));
    }

    @GetMapping("/latest")
    public List<OrderResponse> latest() {
        return orderService.toResponses(orderService.latestOrders());
    }

    @GetMapping("/vt")
    public Page<OrderResponse> listOrdersWithVirtualThreads(@RequestParam(required = false) String customerEmail,
                                                            @RequestParam(required = false) OrderStatus status,
                                                            @RequestParam(defaultValue = "0") int page,
                                                            @RequestParam(defaultValue = "20") int size) throws ExecutionException, InterruptedException {
        try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
            var task = executor.submit(() -> orderService.listOrders(customerEmail, status, page, size));
            var ordersPage = task.get();
            var responses = ordersPage.getContent().stream().map(OrderResponse::from).toList();
            return new PageImpl<>(responses, PageRequest.of(page, size), ordersPage.getTotalElements());
        }
    }
}
