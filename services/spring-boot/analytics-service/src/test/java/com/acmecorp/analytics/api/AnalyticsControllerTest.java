package com.acmecorp.analytics.api;

import com.acmecorp.analytics.service.AnalyticsService;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
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

    @MockBean
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
    void trackEndpointAcceptsEvent() throws Exception {
        mockMvc.perform(post("/api/analytics/track")
                        .contentType("application/json")
                        .content("{\"event\":\"orders.created\"}"))
                .andExpect(status().isAccepted());
    }
}
