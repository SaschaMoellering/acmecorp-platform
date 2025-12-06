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

        mockMvc.perform(get("/api/orders/latest").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].orderNumber").value("ORD-2025-00001"));
    }
}
