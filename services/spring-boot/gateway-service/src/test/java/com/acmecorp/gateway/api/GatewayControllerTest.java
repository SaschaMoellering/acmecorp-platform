package com.acmecorp.gateway.api;

import com.acmecorp.gateway.service.GatewayService;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.reactive.WebFluxTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.web.reactive.server.WebTestClient;

import java.util.List;
import java.util.Map;

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
        Mockito.when(gatewayService.analyticsCounters()).thenReturn(Map.of("orders.created", 5L));

        webClient.get()
                .uri("/api/gateway/analytics/counters")
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$.\"orders.created\"").isEqualTo(5);
    }

    @Test
    void systemStatusShouldAggregate() {
        Mockito.when(gatewayService.systemStatus())
                .thenReturn(List.of(new GatewayService.SystemStatus("orders-service", "OK")));

        webClient.get()
                .uri("/api/gateway/system/status")
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$[0].service").isEqualTo("orders-service");
    }
}
