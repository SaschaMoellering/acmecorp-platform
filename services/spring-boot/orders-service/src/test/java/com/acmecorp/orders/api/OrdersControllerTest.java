package com.acmecorp.orders.api;

import com.acmecorp.orders.domain.Order;
import com.acmecorp.orders.domain.OrderStatus;
import com.acmecorp.orders.service.OrderService;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(OrdersController.class)
class OrdersControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
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
        Mockito.when(orderService.createOrder(Mockito.any())).thenReturn(order);

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
