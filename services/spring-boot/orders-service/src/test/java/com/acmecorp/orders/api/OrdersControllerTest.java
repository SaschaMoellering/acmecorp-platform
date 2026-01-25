package com.acmecorp.orders.api;

import com.acmecorp.orders.domain.Order;
import com.acmecorp.orders.domain.OrderStatus;
import com.acmecorp.orders.service.OrderService;
import com.acmecorp.orders.web.OrderRequest;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(OrdersController.class)
class OrdersControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private OrderService orderService;

    @Test
    void statusEndpointShouldReturnOk() throws Exception {
        mockMvc.perform(get("/api/orders/status"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.service").value("orders-service"));
    }

    @Test
    void latestOrdersShouldReturnList() throws Exception {
        Order order = new Order();
        order.setStatus(OrderStatus.NEW);
        order.setOrderNumber("ORD-2025-00001");
        order.setTotalAmount(new BigDecimal("10.00"));
        order.setCurrency("USD");
        order.setCreatedAt(Instant.now());
        order.setUpdatedAt(Instant.now());
        Mockito.when(orderService.latestOrders()).thenReturn(List.of(order));
        Mockito.when(orderService.toResponses(Mockito.anyList())).thenCallRealMethod();

        mockMvc.perform(get("/api/orders/latest").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].orderNumber").value("ORD-2025-00001"));
    }

    @Test
    void getOrderShouldReturn404WhenMissing() throws Exception {
        Mockito.when(orderService.getOrder(99L)).thenThrow(new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.NOT_FOUND, "Order not found"));

        mockMvc.perform(get("/api/orders/99"))
                .andExpect(status().isNotFound());
    }

    @Test
    void createOrderShouldReturnCreatedOrder() throws Exception {
        Order order = new Order();
        order.setOrderNumber("ORD-2025-00055");
        order.setStatus(OrderStatus.NEW);
        order.setCustomerEmail("demo@acme.test");
        order.setTotalAmount(new BigDecimal("15.00"));
        order.setCurrency("USD");
        order.setCreatedAt(Instant.now());
        order.setUpdatedAt(order.getCreatedAt());
        Mockito.when(orderService.createOrder(Mockito.any(), Mockito.nullable(String.class))).thenReturn(order);

        mockMvc.perform(post("/api/orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "customerEmail": "demo@acme.test",
                                  "items": [
                                    {"productId":"SKU-1","quantity":1}
                                  ]
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.orderNumber").value("ORD-2025-00055"))
                .andExpect(jsonPath("$.status").value("NEW"))
                .andExpect(jsonPath("$.items").isEmpty());
    }

    @Test
    void updateOrderShouldReturnUpdatedOrder() throws Exception {
        Order order = new Order();
        order.setOrderNumber("ORD-2025-00060");
        order.setCustomerEmail("updated@acme.test");
        order.setStatus(OrderStatus.CONFIRMED);
        order.setTotalAmount(new BigDecimal("25.00"));
        order.setCurrency("USD");
        order.setCreatedAt(Instant.now());
        order.setUpdatedAt(order.getCreatedAt());
        Mockito.when(orderService.updateOrder(Mockito.eq(5L), Mockito.any(OrderRequest.class))).thenReturn(order);

        mockMvc.perform(put("/api/orders/5")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "customerEmail": "updated@acme.test",
                                  "items": [{"productId":"SKU-1","quantity":2}],
                                  "status": "CONFIRMED"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.customerEmail").value("updated@acme.test"))
                .andExpect(jsonPath("$.status").value("CONFIRMED"));
    }

    @Test
    void deleteOrderShouldReturnNoContent() throws Exception {
        mockMvc.perform(delete("/api/orders/3"))
                .andExpect(status().isNoContent());

        Mockito.verify(orderService).deleteOrder(Mockito.eq(3L));
    }

    @Test
    void confirmOrderShouldReturnUpdatedStatus() throws Exception {
        Order order = new Order();
        order.setOrderNumber("ORD-2025-00077");
        order.setStatus(OrderStatus.CONFIRMED);
        order.setTotalAmount(new BigDecimal("42.00"));
        order.setCurrency("USD");
        order.setCreatedAt(Instant.now());
        order.setUpdatedAt(order.getCreatedAt());
        Mockito.when(orderService.confirm(7L)).thenReturn(order);

        mockMvc.perform(post("/api/orders/7/confirm"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.orderNumber").value("ORD-2025-00077"))
                .andExpect(jsonPath("$.status").value("CONFIRMED"));
    }

    @Test
    void confirmOrderShouldReturnBadRequestWhenNotNew() throws Exception {
        Mockito.when(orderService.confirm(8L)).thenThrow(new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.BAD_REQUEST, "Only NEW orders can be confirmed"));

        mockMvc.perform(post("/api/orders/8/confirm"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void cancelOrderShouldReturnCancelled() throws Exception {
        Order order = new Order();
        order.setOrderNumber("ORD-2025-00088");
        order.setStatus(OrderStatus.CANCELLED);
        order.setTotalAmount(new BigDecimal("5.00"));
        order.setCurrency("USD");
        order.setCreatedAt(Instant.now());
        order.setUpdatedAt(order.getCreatedAt());
        Mockito.when(orderService.cancel(9L)).thenReturn(order);

        mockMvc.perform(post("/api/orders/9/cancel"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED"));
    }

    @Test
    void createOrderShouldFailValidationWhenItemsMissing() throws Exception {
        mockMvc.perform(post("/api/orders")
                        .contentType(MediaType.APPLICATION_JSON)
                .content("""
                                {
                                  "customerEmail": "demo@acme.test",
                                  "items": []
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void seedOrdersShouldReturnCount() throws Exception {
        var seed1 = new com.acmecorp.orders.web.OrderResponse(
                1L, "ORD-SEED-00001", "seed+1@acme.test", OrderStatus.NEW,
                new BigDecimal("49.00"), "USD", Instant.now(), Instant.now(), List.of()
        );
        var seed2 = new com.acmecorp.orders.web.OrderResponse(
                2L, "ORD-SEED-00002", "seed+2@acme.test", OrderStatus.NEW,
                new BigDecimal("38.00"), "USD", Instant.now(), Instant.now(), List.of()
        );
        var seed3 = new com.acmecorp.orders.web.OrderResponse(
                3L, "ORD-SEED-00003", "seed+3@acme.test", OrderStatus.NEW,
                new BigDecimal("29.00"), "USD", Instant.now(), Instant.now(), List.of()
        );
        Mockito.when(orderService.seedDemoData()).thenReturn(List.of(seed1, seed2, seed3));

        mockMvc.perform(post("/api/orders/seed"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seeded").value(true))
                .andExpect(jsonPath("$.count").value(3));

        Mockito.verify(orderService).seedDemoData();
    }

    @Test
    void listOrdersShouldReturnPagedResponse() throws Exception {
        Order order = new Order();
        order.setOrderNumber("ORD-2025-00042");
        order.setStatus(OrderStatus.CONFIRMED);
        order.setTotalAmount(new BigDecimal("50.00"));
        order.setCurrency("USD");
        order.setCreatedAt(Instant.now());
        order.setUpdatedAt(Instant.now());
        Mockito.when(orderService.listOrders(null, null, 0, 20)).thenReturn(new org.springframework.data.domain.PageImpl<>(List.of(order)));
        Mockito.when(orderService.toResponse(order)).thenCallRealMethod();

        mockMvc.perform(get("/api/orders"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].orderNumber").value("ORD-2025-00042"))
                .andExpect(jsonPath("$.content[0].status").value("CONFIRMED"));
    }
}
