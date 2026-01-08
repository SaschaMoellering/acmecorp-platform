package com.acmecorp.analytics.api;

import com.acmecorp.analytics.service.AnalyticsService;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(AnalyticsController.class)
class AnalyticsControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private AnalyticsService analyticsService;

    @Test
    void statusEndpointShouldReturnOk() throws Exception {
        mockMvc.perform(get("/api/analytics/status"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.service").value("analytics-service"));
    }

    @Test
    void countersEndpointShouldReturnData() throws Exception {
        Mockito.when(analyticsService.allCounters()).thenReturn(Map.of("orders.created", 3L));

        mockMvc.perform(get("/api/analytics/counters"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$['orders.created']").value(3));
    }

    @Test
    void counterEndpointShouldReturnSingleCounter() throws Exception {
        Mockito.when(analyticsService.getCounter("orders.created")).thenReturn(7L);

        mockMvc.perform(get("/api/analytics/counters/orders.created"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.event").value("orders.created"))
                .andExpect(jsonPath("$.count").value(7));
    }

    @Test
    void trackEndpointAcceptsEvent() throws Exception {
        mockMvc.perform(post("/api/analytics/track")
                        .contentType("application/json")
                        .content("{\"event\":\"orders.created\"}"))
                .andExpect(status().isAccepted());
    }
}
